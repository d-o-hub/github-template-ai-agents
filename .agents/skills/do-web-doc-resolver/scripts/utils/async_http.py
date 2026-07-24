"""
Async HTTP utilities for the Web Doc Resolver.
Uses httpx.AsyncClient for non-blocking HTTP requests.
"""

import asyncio
import ipaddress
import logging
import socket
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

_global_client: httpx.AsyncClient | None = None
_client_lock = asyncio.Lock()


async def get_async_client() -> httpx.AsyncClient:
    """Get or create the global async HTTP client."""
    global _global_client
    if _global_client is None or _global_client.is_closed:
        _global_client = httpx.AsyncClient(
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
            verify=True,
        )
    return _global_client


async def close_async_client() -> None:
    """Close the global async HTTP client."""
    global _global_client
    if _global_client is not None and not _global_client.is_closed:
        await _global_client.aclose()
        _global_client = None


@lru_cache(maxsize=1024)
def _getaddrinfo_bucketed(host: str, port: int | str | None, bucket: int) -> list[tuple]:
    """Internal helper for cached getaddrinfo using time-bucketing."""
    return socket.getaddrinfo(host, port)


def _getaddrinfo_cached(host: str, port: int | str | None = None) -> list[tuple]:
    """Cached version of socket.getaddrinfo with TTL."""
    bucket = int(time.time() // DNS_CACHE_TTL)
    return _getaddrinfo_bucketed(host, port, bucket)


def _normalize_host(hostname: str) -> str:
    """Normalise encoded IP representations to dotted-decimal."""
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


async def async_safe_request(
    method: str,
    url: str,
    *,
    max_redirects: int = 5,
    **kwargs,
) -> httpx.Response:
    """Perform an async HTTP request while validating each redirect hop for SSRF."""
    client = await get_async_client()
    current_url = url
    history: list[httpx.Response] = []

    for _ in range(max_redirects + 1):
        if not is_safe_url(current_url):
            raise httpx.RequestError(f"SSRF blocked: {current_url}")

        response = await client.request(method, current_url, **kwargs)

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


async def async_validate_url(
    url: str, timeout: int = 10, check_ssrf: bool = True
) -> ValidationResult:
    """Validate a URL asynchronously."""
    if not url or not url.strip():
        return ValidationResult(is_valid=False, error="Empty URL")
    from scripts.utils.urls import is_url

    if not is_url(url):
        return ValidationResult(is_valid=False, error="Invalid URL format")
    try:
        if check_ssrf:
            response = await async_safe_request("HEAD", url, timeout=timeout)
        else:
            client = await get_async_client()
            response = await client.head(url, follow_redirects=True, timeout=timeout)
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


async def _async_validate_single_link(
    link: str, timeout: int, client: httpx.AsyncClient
) -> str | None:
    """Validate a single link asynchronously."""
    try:
        response = await async_safe_request("HEAD", link, timeout=timeout)
        if response.status_code < 400:
            return link
    except Exception:
        logger.debug("Link validation failed: %s", link, exc_info=True)
        return None
    return None


async def async_validate_links(links: list[str], timeout: int = 5) -> list[str]:
    """Validate a list of links in parallel, preserving input order."""
    if not links:
        return []

    client = await get_async_client()
    tasks = [_async_validate_single_link(link, timeout, client) for link in links]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    return [
        link
        for link, result in zip(links, results, strict=False)
        if result and not isinstance(result, Exception)
    ]
