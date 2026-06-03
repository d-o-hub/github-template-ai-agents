"""
Provider implementations for the Web Doc Resolver.
"""

import threading
import time

from scripts.providers.docling import resolve_with_docling, resolve_with_ocr
from scripts.providers.duckduckgo import resolve_with_duckduckgo
from scripts.providers.exa import resolve_with_exa, resolve_with_exa_mcp
from scripts.providers.firecrawl import resolve_with_firecrawl
from scripts.providers.jina import resolve_with_jina
from scripts.providers.mistral import resolve_with_mistral_browser, resolve_with_mistral_websearch
from scripts.providers.serper import resolve_with_serper
from scripts.providers.tavily import resolve_with_tavily

# Rate limiting functions
_rate_limits: dict[str, float] = {}
_rate_limits_lock = threading.Lock()


def _is_rate_limited(provider: str) -> bool:
    with _rate_limits_lock:
        if provider in _rate_limits:
            if time.time() < _rate_limits[provider]:
                return True
            del _rate_limits[provider]
    return False


def _set_rate_limit(provider: str, cooldown: int = 60):
    with _rate_limits_lock:
        _rate_limits[provider] = time.time() + cooldown


def _clear_rate_limits() -> None:
    with _rate_limits_lock:
        _rate_limits.clear()


# Exported names for both internal use and tests
is_rate_limited = _is_rate_limited
set_rate_limit = _set_rate_limit

__all__ = [
    "resolve_with_jina",
    "resolve_with_exa",
    "resolve_with_exa_mcp",
    "resolve_with_tavily",
    "resolve_with_serper",
    "resolve_with_duckduckgo",
    "resolve_with_firecrawl",
    "resolve_with_mistral_browser",
    "resolve_with_mistral_websearch",
    "resolve_with_docling",
    "resolve_with_ocr",
    "_is_rate_limited",
    "_set_rate_limit",
    "_clear_rate_limits",
    "_rate_limits",
    "is_rate_limited",
    "set_rate_limit",
]
