"""Shared constants for the Web Doc Resolver — single source of truth."""

import ipaddress
import logging
import os
import typing

from scripts.models import FetchTier

logger = logging.getLogger(__name__)

if typing.TYPE_CHECKING:
    pass


def _load_config() -> dict[str, typing.Any]:
    config_path = os.getenv("DO_WDR_CONFIG") or "config.toml"
    if os.path.exists(config_path):
        try:
            try:
                import tomllib
            except ImportError:
                import tomli as tomllib  # type: ignore
            with open(config_path, "rb") as f:
                return typing.cast(dict[str, typing.Any], tomllib.load(f))
        except Exception as e:
            logger.debug("Failed to load config.toml: %s", e)
    return {}


_CONFIG = _load_config()


def _env(
    key: str, default: typing.Any, config_key: str | None = None, config_section: str | None = None
) -> typing.Any:
    val = os.getenv(key)
    if val is not None:
        return default.__class__(val)
    if config_key and _CONFIG:
        section = _CONFIG.get(config_section, {}) if config_section else _CONFIG
        if config_key in section:
            return default.__class__(section[config_key])
    return default


MAX_CHARS: int = int(_env("WEB_RESOLVER_MAX_CHARS", 8000))
MIN_CHARS: int = int(_env("WEB_RESOLVER_MIN_CHARS", 200))
DEFAULT_TIMEOUT: int = int(_env("WEB_RESOLVER_TIMEOUT", 30))
EXA_RESULTS: int = int(_env("WEB_RESOLVER_EXA_RESULTS", 5, "exa_results"))
TAVILY_RESULTS: int = int(_env("WEB_RESOLVER_TAVILY_RESULTS", 5, "tavily_results"))
DDG_RESULTS: int = int(_env("WEB_RESOLVER_DDG_RESULTS", 5, "ddg_results"))

CACHE_DIR: str = os.path.expanduser(
    os.getenv("WEB_RESOLVER_CACHE_DIR", "~/.cache/do-web-doc-resolver")
)
CACHE_TTL: int = int(_env("WEB_RESOLVER_CACHE_TTL", 3600 * 24))

TIERED_TTL: dict[str, int] = {
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

ENABLE_SEMANTIC_CACHE: bool = os.environ.get("DO_WDR_SEMANTIC_CACHE", "1") == "1"
SEMANTIC_CACHE_THRESHOLD: float = float(os.environ.get("DO_WDR_CACHE_THRESHOLD", "0.85"))
SEMANTIC_CACHE_MAX_ENTRIES: int = int(os.environ.get("DO_WDR_CACHE_MAX_ENTRIES", "10000"))

USER_AGENT: str = (
    "Mozilla/5.0 (compatible; WebDocResolver/2.0; +https://github.com/d-oit/do-web-doc-resolver)"
)

BLOCKED_NETWORKS: list = [
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("::/128"),
    ipaddress.ip_network("0.0.0.0/8"),
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"),
    ipaddress.ip_network("fe80::/10"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("100.64.0.0/10"),
    ipaddress.ip_network("192.0.0.0/24"),
    ipaddress.ip_network("198.18.0.0/15"),
    ipaddress.ip_network("198.51.100.0/24"),
    ipaddress.ip_network("203.0.113.0/24"),
    ipaddress.ip_network("240.0.0.0/4"),
    ipaddress.ip_network("255.255.255.255/32"),
    ipaddress.ip_network("::ffff:0:0/96"),
]

BLOCKED_HOSTNAMES: frozenset[str] = frozenset(
    [
        "metadata.google.internal",
        "metadata.google",
        "metadata.azure.com",
        "169.254.169.254",
        "kubernetes.default.svc",
        "kubernetes.default",
        "kubernetes",
        "host.docker.internal",
        "gateway.docker.internal",
    ]
)

BLOCKED_SCHEMES: set[str] = {"file", "javascript", "data", "vbscript"}

DNS_CACHE_TTL: int = 60

CLEAN_CONTENT: bool = os.environ.get("WDR_CLEAN_CONTENT", "1") != "0"

PROVIDER_TIERS: dict[str, FetchTier] = {
    "llms_txt": FetchTier.FREE_STATIC,
    "direct_fetch": FetchTier.FREE_DIRECT,
    "duckduckgo": FetchTier.FREE_SEARCH,
    "jina": FetchTier.PAID_LITE,
    "firecrawl": FetchTier.PAID_LITE,
    "visual_clip": FetchTier.PAID_LITE,
    "stealth": FetchTier.STEALTH,
    "mistral_browser": FetchTier.PAID_BROWSER,
}
