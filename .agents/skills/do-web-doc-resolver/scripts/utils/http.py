"""
HTTP utilities for the Web Doc Resolver.
Uses httpx.Client for sync operations.
"""

import asyncio
import ipaddress
import logging
import socket
import threading
import time
from functools import lru_cache
from urllib.parse import urljoin, urlparse

import httpx

from scripts.constants import (
    BLOCKED_HOSTNAMES,
    BLOCKED_NETWORKS,
    BLOCKED_SCHEMES,
    DNS_CACHE_TTL,
    USER_AGENT,
)
from scripts.models import ValidationResult

logger = logging.getLogger(__name__)

_global_client: httpx.Client | None = None
_client_lock = threading.Lock()


def create_client_with_retry() -> httpx.Client:
    """Create an httpx.Client with retry configuration."""
    return httpx.Client(
        http2=True,
        timeout=httpx.Timeout(30.0),
        follow_redirects=False,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.5",
        },
        limits=httpx.Limits(
            max_connections=100,
            max_keepalive_connections=20,
            keepalive_expiry=30,
        ),
        transport=httpx.HTTPTransport(retries=3),
        verify=True,
    )


def get_session() -> httpx.Client:
    """Get or create the global sync HTTP client (backward compatible name)."""
    global _global_client
    with _client_lock:
        if _global_client is None or _global_client.is_closed:
            _global_client = create_client_with_retry()
    return _global_client


def close_session() -> None:
    """Close the global sync HTTP client."""
    global _global_client
    with _client_lock:
        if _global_client is not None and not _global_client.is_closed:
            _global_client.close()
            _global_client = None


# Keep create_session_with_retry as alias for backward compatibility
create_session_with_retry = create_client_with_retry


@lru_cache(maxsize=1024)
def _getaddrinfo_bucketed(host: str, port: int | str | None, bucket: int) -> list[tuple]:
    """Internal helper for cached getaddrinfo using time-bucketing."""
    return socket.getaddrinfo(host, port)


def _getaddrinfo_cached(host: str, port: int | str | None = None) -> list[tuple]:
    """Cached version of socket.getaddrinfo with TTL to balance performance and security."""
    bucket = int(time.time() // DNS_CACHE_TTL)
    return _getaddrinfo_bucketed(host, port, bucket)


def _normalize_host(hostname: str) -> str:
    """Normalise encoded IP representations to dotted-decimal.

    Handles decimal integer notation, hex notation, and IPv4-mapped IPv6.
    """
    h = hostname.strip().lower()
    if h.isdigit():
        try:
            return str(ipaddress.IPv4Address(int(h)))
        except (ValueError, OverflowError):
            pass
    if h.startswith("0x"):
        try:
            return str(ipaddress.IPv4Address(int(h, 16)))
        except (ValueError, OverflowError):
            pass
    if h.startswith("::ffff:"):
        return h[7:]
    return h


def is_safe_url(url: str) -> bool:
    """Check if a URL is safe to fetch (no SSRF)."""
    try:
        parsed = urlparse(url)
        if parsed.scheme.lower() in BLOCKED_SCHEMES:
            return False
        if parsed.scheme not in ("http", "https"):
            return False
        hostname = parsed.hostname
        if not hostname:
            return False
        normalized = _normalize_host(hostname)
        if normalized in (
            "localhost",
            "localhost.localdomain",
            "127.0.0.1",
            "::1",
            "::",
            "0.0.0.0",
        ):
            return False
        hostname_lower = hostname.lower().strip(".")
        if hostname_lower in BLOCKED_HOSTNAMES:
            logger.warning("SSRF blocked (hostname blocklist): %s", url)
            return False
        if any(hostname_lower.endswith("." + blocked) for blocked in BLOCKED_HOSTNAMES):
            logger.warning("SSRF blocked (hostname suffix): %s", url)
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
    client: httpx.Client | None = None,
    *,
    max_redirects: int = 5,
    **kwargs,
) -> httpx.Response:
    """Perform an HTTP request while validating each redirect hop for SSRF."""
    current_url = url
    history: list[httpx.Response] = []
    kwargs.pop("allow_redirects", None)
    active_client = client or get_session()

    for _ in range(max_redirects + 1):
        if not is_safe_url(current_url):
            raise httpx.RequestError(f"SSRF blocked: {current_url}")

        response = active_client.request(method, current_url, **kwargs)

        if response.is_redirect:
            history.append(response)
            location = response.headers.get("location")
            if not location:
                break
            next_url = location
            if not urlparse(next_url).netloc:
                next_url = urljoin(current_url, next_url)
            current_url = next_url
            continue

        response.history = history
        return response

    raise httpx.TooManyRedirects(f"Exceeded {max_redirects} redirects")


def validate_url(url: str, timeout: int = 10, check_ssrf: bool = True) -> ValidationResult:
    """Validate a URL."""
    if not url or not url.strip():
        return ValidationResult(is_valid=False, error="Empty URL")
    from scripts.utils.urls import is_url

    if not is_url(url):
        return ValidationResult(is_valid=False, error="Invalid URL format")
    try:
        client = get_session()
        if check_ssrf:
            response = _safe_request("HEAD", url, client=client, timeout=timeout)
        else:
            response = client.head(url, follow_redirects=True, timeout=timeout)
        redirect_chain = [str(h.url) for h in response.history] + [str(response.url)]
        if response.status_code >= 400:
            return ValidationResult(
                is_valid=False,
                status_code=response.status_code,
                error=f"HTTP {response.status_code}",
                final_url=str(response.url),
                redirect_chain=redirect_chain,
            )
        return ValidationResult(
            is_valid=True,
            status_code=response.status_code,
            final_url=str(response.url),
            redirect_chain=redirect_chain,
            content_type=response.headers.get("content-type", ""),
        )
    except Exception as e:
        return ValidationResult(is_valid=False, error=str(e))


def _validate_single_link(link: str, timeout: int, client: httpx.Client) -> str | None:
    """Validate a single link."""
    try:
        response = _safe_request("HEAD", link, client=client, timeout=timeout)
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

    client = get_session()

    async def _validate_all():
        tasks = [_validate_single_link_async(link, timeout, client) for link in links]
        return await asyncio.gather(*tasks)

    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = None

    if loop and loop.is_running():
        import concurrent.futures

        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            results = pool.submit(asyncio.run, _validate_all()).result()
    else:
        results = asyncio.run(_validate_all())

    return [link for link, valid in zip(links, results, strict=False) if valid]


async def _validate_single_link_async(link: str, timeout: int, client: httpx.Client) -> str | None:
    """Validate a single link asynchronously."""
    return await asyncio.to_thread(_validate_single_link, link, timeout, client)
