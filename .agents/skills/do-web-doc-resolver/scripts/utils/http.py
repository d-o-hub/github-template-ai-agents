"""
HTTP utilities for the Web Doc Resolver.
"""

import ipaddress
import logging
import socket
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
from urllib.parse import urljoin, urlparse

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from scripts.constants import (
    BLOCKED_NETWORKS,
    BLOCKED_SCHEMES,
    DNS_CACHE_TTL,
    HTTP_SCHEME,
    HTTPS_SCHEME,
    USER_AGENT,
)
from scripts.models import ValidationResult

logger = logging.getLogger(__name__)

_global_session: requests.Session | None = None
_session_lock = threading.Lock()


def create_session_with_retry() -> requests.Session:
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1.0,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["HEAD", "GET", "OPTIONS"],
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount(HTTP_SCHEME, adapter)  # HTTP adapter needed for SSRF-safe requests to HTTP-only endpoints
    session.mount(HTTPS_SCHEME, adapter)
    session.headers.update(
        {
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
        }
    )
    return session


def get_session() -> requests.Session:
    global _global_session
    with _session_lock:
        if _global_session is None:
            _global_session = create_session_with_retry()
    return _global_session


def close_session() -> None:
    global _global_session
    with _session_lock:
        if _global_session is not None:
            _global_session.close()
            _global_session = None


@lru_cache(maxsize=1024)
def _getaddrinfo_bucketed(host: str, port: int | str | None, bucket: int) -> list[tuple]:
    """Internal helper for cached getaddrinfo using time-bucketing."""
    return socket.getaddrinfo(host, port)


def _getaddrinfo_cached(host: str, port: int | str | None = None) -> list[tuple]:
    """Cached version of socket.getaddrinfo with TTL to balance performance and security."""
    bucket = int(time.time() // DNS_CACHE_TTL)
    return _getaddrinfo_bucketed(host, port, bucket)


def is_safe_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
        if parsed.scheme.lower() in BLOCKED_SCHEMES:
            return False
        if parsed.scheme not in ("http", "https"):
            return False
        hostname = parsed.hostname
        if not hostname:
            return False
        normalized = hostname.lower()
        if normalized in (
            "localhost",
            "localhost.localdomain",
            "127.0.0.1",
            "::1",
            "0.0.0.0",  # nosec B104 -- SSRF blocklist, not a bind address
        ):
            return False
        try:
            ip = ipaddress.ip_address(normalized)
            if any(ip in network for network in BLOCKED_NETWORKS):
                return False
        except ValueError:
            try:
                infos = _getaddrinfo_cached(hostname, None)
                for _family, _socktype, _proto, _canonname, sockaddr in infos:
                    ip = ipaddress.ip_address(sockaddr[0])
                    if any(ip in network for network in BLOCKED_NETWORKS):
                        return False
            except Exception:
                logger.debug("DNS resolution failed for SSRF check: %s", hostname, exc_info=True)
        if normalized.endswith(".local") or normalized.endswith(".internal"):
            return False
        return True
    except Exception:
        logger.debug("URL safety check failed: %s", url, exc_info=True)
        return False


def _safe_request(
    method: str,
    url: str,
    session: requests.Session | None = None,
    *,
    max_redirects: int = 5,
    **kwargs,
) -> requests.Response:
    """Perform an HTTP request while validating each redirect hop for SSRF."""

    current_url = url
    history: list[requests.Response] = []
    # Ensure we control redirect behavior
    kwargs.pop("allow_redirects", None)
    active_session = session or get_session()

    for _ in range(max_redirects + 1):
        if not is_safe_url(current_url):
            raise requests.RequestException(f"SSRF blocked: {current_url}")

        response = active_session.request(method, current_url, allow_redirects=False, **kwargs)
        response.history = list(history)

        if response.is_redirect:
            history.append(response)
            location = response.headers.get("Location")
            if not location:
                break
            next_url = location
            if not urlparse(next_url).netloc:
                next_url = urljoin(current_url, next_url)
            current_url = next_url
            continue

        return response

    raise requests.TooManyRedirects(f"Exceeded {max_redirects} redirects")


def validate_url(url: str, timeout: int = 10, check_ssrf: bool = True) -> ValidationResult:
    if not url or not url.strip():
        return ValidationResult(is_valid=False, error="Empty URL")
    from scripts.utils.urls import is_url

    if not is_url(url):
        return ValidationResult(is_valid=False, error="Invalid URL format")
    try:
        session = get_session()
        if check_ssrf:
            response = _safe_request("HEAD", url, session=session, timeout=timeout, verify=True)
        else:
            response = session.head(url, timeout=timeout, allow_redirects=True, verify=True)
        redirect_chain = [h.url for h in response.history] + [response.url]
        if response.status_code >= 400:
            return ValidationResult(
                is_valid=False,
                status_code=response.status_code,
                error=f"HTTP {response.status_code}",
                final_url=response.url,
                redirect_chain=redirect_chain,
            )
        return ValidationResult(
            is_valid=True,
            status_code=response.status_code,
            final_url=response.url,
            redirect_chain=redirect_chain,
            content_type=response.headers.get("Content-Type", ""),
        )
    except Exception as e:
        return ValidationResult(is_valid=False, error=str(e))


def _validate_single_link(link: str, timeout: int, session: requests.Session) -> str | None:
    try:
        response = _safe_request("HEAD", link, session=session, timeout=timeout, verify=True)
        if response.status_code < 400:
            return link
    except Exception:
        logger.debug("Link validation failed: %s", link, exc_info=True)
        return None
    return None


def validate_links(links: list[str], timeout: int = 5) -> list[str]:
    """Validate a list of links in parallel, preserving input order."""
    if not links:
        return []

    session = get_session()
    max_workers = min(10, len(links))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        results = list(
            executor.map(lambda link: _validate_single_link(link, timeout, session), links)
        )

    return [link for link in results if link]
