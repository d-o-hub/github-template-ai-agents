"""Exercise fetch/caller contracts through real httpx requests without networking."""

import asyncio
import logging
import socket
from contextlib import ExitStack

import httpx
import pytest
from diskcache import Cache

import scripts._cascade_async as cascade_async
import scripts._url_resolve_async as async_resolver
import scripts.resolve as resolver
import scripts.routing as routing
import scripts.utils as utils
from scripts.circuit_breaker import CircuitBreakerRegistry
from scripts.constants import DEFAULT_TIMEOUT
from scripts.models import Profile, ProviderType
from scripts.routing_memory import RoutingMemory
from scripts.utils import cache as cache_utils
from scripts.utils import http as http_utils
from scripts.utils.fetch import fetch_llms_txt, fetch_url_content

PUBLIC_HOST = "docs.example.com"
PUBLIC_IP = "93.184.216.34"
BASE_URL = f"https://{PUBLIC_HOST}"
DOCUMENT_URL = f"{BASE_URL}/guide"
LLMS_URL = f"{BASE_URL}/llms.txt"
PRIVATE_URL = "http://127.0.0.1/private"
REQUESTED_MAX_CHARS = 640
HTTP_OK = 200
HTTP_REDIRECT = 302
LLMS_TEXT = "# Documentation\n\n- [Guide](/guide): HTTP client usage.\n"
DOCUMENT_TEXT = "\n".join(
    [
        "# HTTP client guide",
        "Clients share connection pools while callers supply individual request timeouts.",
        "The content limit controls returned characters, not how long a request may take.",
        "TLS certificate verification belongs to the client and stays enabled for HTTPS.",
        "Requests validate the original target before connecting to a public address.",
        "Redirect locations are checked again before any subsequent request is sent.",
        "Private addresses, loopback hosts and metadata endpoints cannot be fetched.",
        "The direct fetch path handles plain text without invoking HTML extraction.",
        "The llms.txt path returns the documentation index from the root of the host.",
        "Successful responses retain the original size in their returned metadata.",
        "Async callers use a worker thread to run the same synchronous fetch helper.",
        "Transport fixtures can exercise these contracts without DNS or HTTP traffic.",
    ]
)


def text_response(request):
    assert str(request.url) in {DOCUMENT_URL, LLMS_URL}
    body = LLMS_TEXT if str(request.url) == LLMS_URL else DOCUMENT_TEXT
    return httpx.Response(HTTP_OK, text=body, headers={"Content-Type": "text/plain"})


@pytest.fixture
def mock_http_client(monkeypatch, tmp_path):
    """Install real clients with fake transports; restore globals and close resources."""

    def public_dns(host, port=None):
        assert host == PUBLIC_HOST
        return [(socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, "", (PUBLIC_IP, 0))]

    monkeypatch.setattr(http_utils, "_getaddrinfo_cached", public_dns)
    with ExitStack() as resources:
        cache = resources.enter_context(Cache(str(tmp_path / "fetch-cache")))
        monkeypatch.setattr(utils, "_get_cache", lambda: cache)
        monkeypatch.setattr(utils, "_get_from_cache", cache_utils._get_from_cache)
        monkeypatch.setattr(utils, "_save_to_cache", cache_utils._save_to_cache)
        monkeypatch.setattr(cascade_async, "_get_cache", lambda: cache)

        def install(handler=text_response):
            requests = []

            def record_request(request):
                requests.append(request)
                return handler(request)

            client = resources.enter_context(
                httpx.Client(
                    transport=httpx.MockTransport(record_request),
                    verify=True,
                    follow_redirects=False,
                    trust_env=False,
                )
            )
            monkeypatch.setattr(http_utils, "_global_client", client)
            return requests

        yield install


def assert_default_timeouts(requests):
    """Inspect httpx's request extensions rather than replacing the fetch callable."""
    assert [request.method for request in requests] == ["HEAD", "GET"]
    for request in requests:
        expected = DEFAULT_TIMEOUT // 2 if request.method == "HEAD" else DEFAULT_TIMEOUT
        assert set(request.extensions["timeout"].values()) == {expected}


def test_direct_text_fetch_uses_real_httpx_contract(mock_http_client):
    requests = mock_http_client()

    result = fetch_url_content(DOCUMENT_URL)

    assert result is not None
    assert result.source == "direct_fetch"
    assert result.url == DOCUMENT_URL
    assert result.content == DOCUMENT_TEXT
    assert result.metadata == {
        "status_code": HTTP_OK,
        "cleaned": False,
        "raw_length": len(DOCUMENT_TEXT),
    }
    assert_default_timeouts(requests)


def test_llms_txt_fetch_uses_real_httpx_contract(mock_http_client):
    requests = mock_http_client()

    assert fetch_llms_txt(DOCUMENT_URL) == LLMS_TEXT
    assert [(request.method, str(request.url)) for request in requests] == [("GET", LLMS_URL)]


def test_resolve_direct_keeps_max_chars_separate_from_timeout(mock_http_client):
    requests = mock_http_client()

    result = resolver.resolve_direct(
        DOCUMENT_URL, ProviderType.DIRECT_FETCH, max_chars=REQUESTED_MAX_CHARS
    )

    assert result["source"] == "direct_fetch"
    assert result["content"] == DOCUMENT_TEXT[:REQUESTED_MAX_CHARS]
    assert len(result["content"]) == REQUESTED_MAX_CHARS
    assert_default_timeouts(requests)


def test_async_direct_fetch_keeps_max_chars_separate_from_timeout(mock_http_client, monkeypatch):
    requests = mock_http_client()
    monkeypatch.setattr(routing, "plan_provider_order", lambda **kwargs: ["direct_fetch"])
    monkeypatch.setattr(async_resolver, "get_semantic_cache", lambda: None)
    monkeypatch.setattr(async_resolver, "_routing_memory", RoutingMemory())
    monkeypatch.setattr(async_resolver, "_circuit_breakers", CircuitBreakerRegistry())

    result = asyncio.run(
        async_resolver.resolve_url_async(
            DOCUMENT_URL, max_chars=REQUESTED_MAX_CHARS, profile=Profile.FREE
        )
    )

    assert result["source"] == "direct_fetch"
    assert result["content"] == DOCUMENT_TEXT[:REQUESTED_MAX_CHARS]
    assert len(result["content"]) == REQUESTED_MAX_CHARS
    assert_default_timeouts(requests)


def test_safe_request_rejects_private_redirect_before_transport(mock_http_client):
    requests = mock_http_client(
        lambda request: httpx.Response(HTTP_REDIRECT, headers={"Location": PRIVATE_URL})
    )

    with pytest.raises(httpx.RequestError, match="SSRF blocked"):
        http_utils._safe_request("GET", DOCUMENT_URL, client=http_utils.get_session())

    assert [(request.method, str(request.url)) for request in requests] == [("GET", DOCUMENT_URL)]


def test_direct_fetch_rejects_private_head_redirect(mock_http_client):
    requests = mock_http_client(
        lambda request: httpx.Response(HTTP_REDIRECT, headers={"Location": PRIVATE_URL})
    )

    assert fetch_url_content(DOCUMENT_URL) is None
    assert [(request.method, str(request.url)) for request in requests] == [("HEAD", DOCUMENT_URL)]


@pytest.mark.parametrize("fetcher", [fetch_url_content, fetch_llms_txt])
def test_fetch_rejects_private_get_redirect(mock_http_client, caplog, fetcher):
    def redirect_get(request):
        if request.method == "GET":
            return httpx.Response(HTTP_REDIRECT, headers={"Location": PRIVATE_URL})
        return text_response(request)

    requests = mock_http_client(redirect_get)

    with caplog.at_level(logging.DEBUG, logger="scripts.utils.fetch"):
        assert fetcher(DOCUMENT_URL) is None

    assert "SSRF blocked" in caplog.text
    expected = (
        [("HEAD", DOCUMENT_URL), ("GET", DOCUMENT_URL)]
        if fetcher is fetch_url_content
        else [("GET", LLMS_URL)]
    )
    assert [(request.method, str(request.url)) for request in requests] == expected
