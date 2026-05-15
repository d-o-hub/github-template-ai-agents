"""
Utility functions for the Web Doc Resolver.
"""

import hashlib
import ipaddress
import logging
import os
import re
import socket
import threading
import time
import typing
from concurrent.futures import ThreadPoolExecutor
from functools import lru_cache
from html.parser import HTMLParser
from typing import Any
from urllib.parse import urljoin, urlparse

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from scripts.models import ErrorType, ResolvedResult, ValidationResult

logger = logging.getLogger(__name__)

MAX_CHARS = int(os.getenv("WEB_RESOLVER_MAX_CHARS", "8000"))
DEFAULT_TIMEOUT = int(os.getenv("WEB_RESOLVER_TIMEOUT", "30"))
CACHE_DIR = os.path.expanduser(os.getenv("WEB_RESOLVER_CACHE_DIR", "~/.cache/do-web-doc-resolver"))
CACHE_TTL = int(os.getenv("WEB_RESOLVER_CACHE_TTL", str(3600 * 24)))

# Tiered TTL defaults
TIERED_TTL = {
    "firecrawl": 21600,
    "exa": 14400,
    "exa_mcp": 14400,
    "tavily": 14400,
    "serper": 7200,
    "jina": 7200,
    "mistral": 28800,
    "duckduckgo": 3600,
    "llms_txt": 28800,
    "synthesis": 43200,
    "default": 3600,
}

_CONFIG_DATA: dict[str, Any] | None = None


def get_config_data() -> dict[str, Any]:
    """Load configuration from config.toml if available."""
    global _CONFIG_DATA
    if _CONFIG_DATA is not None:
        return _CONFIG_DATA

    _CONFIG_DATA = {}
    config_path = os.getenv("DO_WDR_CONFIG") or "config.toml"
    if os.path.exists(config_path):
        try:
            try:
                import tomllib
            except ImportError:
                import tomli as tomllib  # type: ignore

            with open(config_path, "rb") as f:
                _CONFIG_DATA = typing.cast(dict[str, Any], tomllib.load(f))
        except Exception as e:
            logger.debug(f"Failed to load config.toml: {e}")

    return _CONFIG_DATA


# Semantic cache configuration
ENABLE_SEMANTIC_CACHE = os.environ.get("DO_WDR_SEMANTIC_CACHE", "1") == "1"
SEMANTIC_CACHE_THRESHOLD = float(os.environ.get("DO_WDR_CACHE_THRESHOLD", "0.85"))
SEMANTIC_CACHE_MAX_ENTRIES = int(os.environ.get("DO_WDR_CACHE_MAX_ENTRIES", "10000"))

USER_AGENT = (
    "Mozilla/5.0 (compatible; WebDocResolver/2.0; +https://github.com/d-oit/do-web-doc-resolver)"
)

BLOCKED_NETWORKS = [
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("fe80::/10"),
]

BLOCKED_SCHEMES: set[str] = {"file", "javascript", "data", "vbscript"}


_global_session: requests.Session | None = None
_session_lock = threading.Lock()
_cache = None
_cache_lock = threading.RLock()


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
    session.mount("http://", adapter)
    session.mount("https://", adapter)
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


_DNS_CACHE_TTL = 60  # seconds


@lru_cache(maxsize=1024)
def _getaddrinfo_bucketed(host: str, port: int | str | None, bucket: int) -> list[tuple]:
    """Internal helper for cached getaddrinfo using time-bucketing."""
    return socket.getaddrinfo(host, port)


def _getaddrinfo_cached(host: str, port: int | str | None = None) -> list[tuple]:
    """Cached version of socket.getaddrinfo with TTL to balance performance and security."""
    bucket = int(time.time() // _DNS_CACHE_TTL)
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
            "0.0.0.0",
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
                pass
        if normalized.endswith(".local") or normalized.endswith(".internal"):
            return False
        return True
    except Exception:
        return False


def is_url(input_str: str) -> bool:
    if not input_str or not input_str.strip():
        return False
    try:
        result = urlparse(input_str)
        return all([result.scheme in {"http", "https"}, result.netloc])
    except Exception:
        return False


def validate_url(url: str, timeout: int = 10, check_ssrf: bool = True) -> ValidationResult:
    if not url or not url.strip():
        return ValidationResult(is_valid=False, error="Empty URL")
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


def score_result(url: str | None, content: str) -> float:
    score = 0.5
    if url:
        try:
            domain = urlparse(url).netloc.lower()
            if any(domain.endswith(tld) for tld in [".edu", ".gov", ".org", ".rs", ".io"]):
                score += 0.2
            if any(
                site in domain
                for site in ["github.com", "stackoverflow.com", "docs.rs", "mozilla.org"]
            ):
                score += 0.2
        except Exception:
            pass
    word_count = len(content.split())
    if word_count > 500:
        score += 0.1
    elif word_count < 50:
        score -= 0.2
    return max(0.0, min(1.0, score))


def compact_content(content: str, max_chars: int) -> str:
    lines = content.splitlines()
    unique_lines = set()
    compacted = []
    for line in lines:
        trimmed = line.strip()
        if not trimmed:
            compacted.append("")
            continue
        if trimmed not in unique_lines:
            compacted.append(trimmed)
            unique_lines.add(trimmed)
    return "\n".join(compacted)[:max_chars]


def extract_text_from_html(html: str, base_url: str = "") -> str:
    class EnhancedHTMLParser(HTMLParser):
        def __init__(self) -> None:
            super().__init__(convert_charrefs=True)
            self.result: list[str] = []
            self._skip_depth = 0
            self._block_tags = {
                "p",
                "div",
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "h6",
                "li",
                "tr",
                "pre",
                "br",
                "article",
                "section",
                "header",
                "footer",
                "nav",
                "aside",
            }

        def handle_starttag(self, tag, attrs):
            tag_lower = tag.lower()
            if tag_lower in ("script", "style"):
                self._skip_depth += 1
            elif self._skip_depth == 0:
                if tag_lower in self._block_tags:
                    if self.result and self.result[-1] != "\n":
                        self.result.append("\n")
                if tag_lower == "code":
                    self.result.append("`")
                elif tag_lower == "pre":
                    self.result.append("\n```\n")

        def handle_endtag(self, tag):
            tag_lower = tag.lower()
            if tag_lower in ("script", "style") and self._skip_depth > 0:
                self._skip_depth -= 1
            elif self._skip_depth == 0:
                if tag_lower == "code":
                    self.result.append("`")
                elif tag_lower == "pre":
                    self.result.append("\n```\n")
                elif tag_lower in self._block_tags:
                    if self.result and self.result[-1] != "\n":
                        self.result.append("\n")

        def handle_data(self, data):
            if self._skip_depth == 0:
                self.result.append(data)

    stripper = EnhancedHTMLParser()
    stripper.feed(html)
    text = "".join(stripper.result)
    # Normalize word joiner and other problematic characters
    text = text.replace("\u2060", "")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def fetch_url_content(
    url: str, timeout: int = DEFAULT_TIMEOUT, max_chars: int = MAX_CHARS
) -> ResolvedResult | None:
    validation = validate_url(url, timeout=timeout // 2)
    if not validation.is_valid:
        return None
    try:
        session = get_session()
        response = _safe_request("GET", url, session=session, timeout=timeout, verify=True)
        if response.status_code >= 400:
            return None
        content = (
            extract_text_from_html(response.text, url)
            if "text/html" in response.headers.get("Content-Type", "")
            else response.text
        )
        return ResolvedResult(
            source="direct_fetch",
            content=content[:max_chars],
            url=validation.final_url or url,
            metadata={"status_code": response.status_code},
        )
    except Exception:
        return None


def fetch_llms_txt(url: str) -> str | None:
    try:
        if not is_safe_url(url):
            return None
        parsed = urlparse(url)
        base_url = f"{parsed.scheme}://{parsed.netloc}"
        llms_url = f"{base_url}/llms.txt"
        cached = _get_from_cache(base_url, "llms_txt")
        if cached is not None:
            if cached.get("found"):
                return str(cached.get("content", ""))
            return None
        session = get_session()
        response = _safe_request("GET", llms_url, session=session, timeout=10)
        if response.status_code == 200:
            content_type = response.headers.get("Content-Type", "")
            if "text" in content_type or "markdown" in content_type:
                _save_to_cache(
                    base_url,
                    "llms_txt",
                    {"found": True, "content": response.text},
                    ttl=get_ttl("llms_txt"),
                )
                return response.text
        _save_to_cache(base_url, "llms_txt", {"found": False}, ttl=get_ttl("llms_txt"))
    except Exception:
        pass
    return None


_TRACKING_PARAMS = {
    # UTM parameters
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_term",
    "utm_content",
    # Social/tracking parameters
    "fbclid",
    "gclid",
    "gclsrc",
    "dclid",
    "msclkid",
    "twclid",
    "li_fat_id",
    "mc_cid",
    "mc_eid",
    # Referral/tracking
    "ref",
    "ref_src",
    "ref_url",
    "source",
    "via",
    # Session/tracking
    "session_id",
    "sid",
    "_ga",
    "_gl",
    # Misc tracking
    "hsa_cam",
    "hsa_grp",
    "hsa_mt",
    "hsa_src",
    "hsa_ad",
    "hsa_acc",
    "hsa_net",
    "hsa_kw",
    "hsa_tgt",
    "hsa_ver",
}


def normalize_url(url: str) -> str:
    """Normalize URL by stripping tracking params, anchors, and common aliases."""
    try:
        parsed = urlparse(url)
        # Strip all known tracking params
        if parsed.query:
            from urllib.parse import parse_qs, urlencode

            params = parse_qs(parsed.query)
            filtered_params = {
                k: v
                for k, v in params.items()
                if k.lower() not in _TRACKING_PARAMS and not k.startswith("utm_")
            }
            query = urlencode(filtered_params, doseq=True)
        else:
            query = ""

        # Normalize fragment: strip if empty or just a section ref
        fragment = "" if not parsed.fragment else parsed.fragment

        # Normalize trailing slash (keep for root, strip for paths)
        path = parsed.path
        if path and path != "/" and path.endswith("/"):
            path = path.rstrip("/")

        # Normalize netloc: lowercase, strip default ports
        netloc = parsed.netloc.lower()
        if netloc.endswith(":80") and parsed.scheme == "http":
            netloc = netloc[:-3]
        elif netloc.endswith(":443") and parsed.scheme == "https":
            netloc = netloc[:-4]

        # Reconstruct
        normalized = parsed._replace(
            scheme=parsed.scheme.lower(), netloc=netloc, path=path, query=query, fragment=fragment
        ).geturl()
        return normalized.strip()
    except Exception:
        return url.lower().strip()


def normalize_query(query: str) -> str:
    """Normalize search query."""
    # Lowercase, trim whitespace, and collapse multiple spaces
    normalized = query.lower().strip()
    normalized = re.sub(r"\s+", " ", normalized)
    return normalized


def _cache_key(input_str: str, source: str) -> str:
    # Use normalized input for cache key
    if is_url(input_str):
        normalized = normalize_url(input_str)
    else:
        normalized = normalize_query(input_str)

    hash_input = f"{source}:{normalized}"
    return hashlib.sha256(hash_input.encode()).hexdigest()


def _get_cache_proxy():
    import scripts.resolve

    if hasattr(scripts.resolve, "_cache") and scripts.resolve._cache is not None:
        return scripts.resolve._cache
    return _cache


def get_cache():
    try:
        import diskcache

        os.makedirs(CACHE_DIR, exist_ok=True)
        return diskcache.Cache(CACHE_DIR)
    except Exception:
        return None


def _get_cache():
    global _cache
    with _cache_lock:
        _cache = _get_cache_proxy()
        if _cache is None:
            _cache = get_cache()
    return _cache


def get_ttl(provider: str, config: dict | None = None) -> int:
    """Get the TTL for a given provider from config or defaults."""
    # Normalize provider name for alias support
    provider_key = provider
    if provider in ("exa_mcp", "exa"):
        provider_key = "exa"
    elif provider in ("mistral_browser", "mistral_websearch"):
        provider_key = "mistral"

    # Use provided config or load from file
    cfg = config if config is not None else get_config_data()

    # Environment variable override takes precedence over file-based config
    env_key = f"DO_WDR_CACHE_TTL_{provider_key.upper()}"
    if env_key in os.environ:
        try:
            return int(os.environ[env_key])
        except ValueError:
            pass

    if cfg:
        # Try to get from nested config.toml style
        ttl_cfg = cfg.get("cache", {}).get("ttl", {})
        if provider_key in ttl_cfg:
            return int(ttl_cfg[provider_key])
        if "default" in ttl_cfg:
            return int(ttl_cfg["default"])

    return TIERED_TTL.get(provider_key, TIERED_TTL.get("default", 3600))


def _get_from_cache(input_str: str, source: str) -> dict[str, Any] | None:
    with _cache_lock:
        cache = _get_cache()
        if not cache:
            return None
        result = cache.get(_cache_key(input_str, source))
        if result is None:
            return None
        return dict(result)


def _save_to_cache(input_str: str, source: str, result: dict[str, Any], ttl: int | None = None):
    with _cache_lock:
        cache = _get_cache()
        if not cache:
            return

        if ttl is None:
            ttl = get_ttl(source)

        cache.set(_cache_key(input_str, source), result, expire=ttl)


def _detect_error_type(error: Exception) -> ErrorType:
    error_msg = str(error).lower()
    if any(code in error_msg for code in ["429", "rate limit", "too many requests", "rate_limit"]):
        return ErrorType.RATE_LIMIT
    if any(
        code in error_msg
        for code in [
            "401",
            "403",
            "unauthorized",
            "forbidden",
            "invalid api key",
            "invalid_key",
            "authentication",
        ]
    ):
        return ErrorType.AUTH_ERROR
    if any(
        code in error_msg
        for code in [
            "402",
            "payment",
            "credit",
            "quota",
            "insufficient",
            "exhausted",
            "limit exceeded",
        ]
    ):
        return ErrorType.QUOTA_EXHAUSTED
    if any(code in error_msg for code in ["timeout", "timed out"]):
        return ErrorType.TIMEOUT
    if any(code in error_msg for code in ["connection", "network"]):
        return ErrorType.NETWORK_ERROR
    if any(code in error_msg for code in ["not found", "404"]):
        return ErrorType.NOT_FOUND
    if any(code in error_msg for code in ["ssrf", "blocked", "private ip", "localhost"]):
        return ErrorType.SSRF_BLOCKED
    if any(code in error_msg for code in ["too large", "content size", "exceeds"]):
        return ErrorType.CONTENT_TOO_LARGE
    return ErrorType.UNKNOWN
