#!/usr/bin/env python3
"""
Web Doc Resolver - Resolve queries or URLs into compact, LLM-ready markdown.
Main orchestrator. CLI entrypoint moved to scripts/cli.py.
"""

import concurrent.futures
import logging
import os
from typing import Any

import scripts._query_resolve
import scripts._url_resolve
import scripts.cache_negative
import scripts.circuit_breaker
import scripts.providers_impl
import scripts.quality
import scripts.routing
import scripts.routing_memory
import scripts.semantic_cache
import scripts.synthesis
import scripts.utils
from scripts.models import (
    ErrorType,
    Profile,
    ProviderType,
    ResolvedResult,
    ValidationResult,
)
from scripts.providers_impl import (
    _is_rate_limited,
    _rate_limits,
    _set_rate_limit,
    resolve_with_docling,
    resolve_with_duckduckgo,
    resolve_with_exa,
    resolve_with_exa_mcp,
    resolve_with_firecrawl,
    resolve_with_jina,
    resolve_with_mistral_browser,
    resolve_with_mistral_websearch,
    resolve_with_ocr,
    resolve_with_serper,
    resolve_with_tavily,
)
from scripts.semantic_cache import get_semantic_cache
from scripts.utils import (
    _cache_key,
    _detect_error_type,
    _get_cache,
    _get_from_cache,
    _save_to_cache,
    fetch_llms_txt,
    fetch_url_content,
    get_cache,
    get_session,
    is_url,
    validate_links,
    validate_url,
)

MAX_CHARS = int(os.getenv("WEB_RESOLVER_MAX_CHARS", "8000"))
MIN_CHARS = int(os.getenv("WEB_RESOLVER_MIN_CHARS", "200"))
DEFAULT_TIMEOUT = int(os.getenv("WEB_RESOLVER_TIMEOUT", "30"))

logger = logging.getLogger(__name__)

_circuit_breakers = scripts.circuit_breaker.CircuitBreakerRegistry()
_routing_memory = scripts.routing_memory.RoutingMemory()
_cache = None
_semantic_cache = None
_executor = None


def _get_executor(max_workers: int = 10) -> concurrent.futures.ThreadPoolExecutor:
    """Get or create shared ThreadPoolExecutor."""
    global _executor
    if _executor is None:
        _executor = concurrent.futures.ThreadPoolExecutor(
            max_workers=max_workers, thread_name_prefix="resolver"
        )
    return _executor


# TODO(ADR-014): Replace monkey-patching with scripts/state.py singleton.
# These overwrites sync sub-module state but create race conditions under
# concurrent imports. Both conftest.py and the cascade depend on this wiring.
scripts._query_resolve._circuit_breakers = _circuit_breakers
scripts._query_resolve._routing_memory = _routing_memory
scripts._url_resolve._circuit_breakers = _circuit_breakers
scripts._url_resolve._routing_memory = _routing_memory

is_rate_limited = _is_rate_limited
set_rate_limit = _set_rate_limit


def _get_semantic_cache():
    """Get or initialize the semantic cache."""
    return get_semantic_cache()


def _check_semantic_cache(query_or_url: str) -> dict[str, Any] | None:
    """Check semantic cache - delegates to sub-modules."""
    result = scripts._query_resolve._check_semantic_cache(query_or_url)
    if result:
        return result
    return scripts._url_resolve._check_semantic_cache(query_or_url)


def _store_in_semantic_cache(query_or_url: str, result: dict) -> bool:
    """Store in semantic cache - delegates to sub-modules."""
    if scripts._query_resolve._store_in_semantic_cache(query_or_url, result):
        return True
    return scripts._url_resolve._store_in_semantic_cache(query_or_url, result)


__all__ = [
    "resolve",
    "resolve_url",
    "resolve_query",
    "resolve_direct",
    "resolve_with_order",
    "resolve_url_with_order",
    "resolve_query_with_order",
    "ResolvedResult",
    "ValidationResult",
    "ErrorType",
    "ProviderType",
    "is_url",
    "validate_url",
    "validate_links",
    "fetch_url_content",
    "fetch_llms_txt",
    "MAX_CHARS",
    "MIN_CHARS",
    "DEFAULT_TIMEOUT",
    "_detect_error_type",
    "_is_rate_limited",
    "_set_rate_limit",
    "get_session",
    "_get_from_cache",
    "_save_to_cache",
    "_cache_key",
    "_get_cache",
    "get_cache",
    "_rate_limits",
    "_cache",
    "_check_semantic_cache",
    "_store_in_semantic_cache",
]


resolve_url = scripts._url_resolve.resolve_url
resolve_url_stream = scripts._url_resolve.resolve_url_stream
resolve_query = scripts._query_resolve.resolve_query
resolve_query_stream = scripts._query_resolve.resolve_query_stream


def synthesize_results(query: str, results: list[ResolvedResult], api_key: str, model: str) -> str:
    return scripts.synthesis.synthesize_results(query, results, api_key, model)


def resolve(
    input_str: str,
    max_chars: int = MAX_CHARS,
    skip_providers: set[str] | None = None,
    profile: Profile | str = Profile.BALANCED,
) -> dict[str, Any]:
    if isinstance(profile, str):
        profile = Profile(profile.lower())

    if is_url(input_str):
        return resolve_url(input_str, max_chars, profile=profile)
    return resolve_query(input_str, max_chars, skip_providers, profile=profile)


def resolve_direct(
    input_str: str, provider: ProviderType, max_chars: int = MAX_CHARS
) -> dict[str, Any]:
    funcs: dict[ProviderType, Any] = {
        ProviderType.JINA: resolve_with_jina,
        ProviderType.EXA_MCP: resolve_with_exa_mcp,
        ProviderType.EXA: resolve_with_exa,
        ProviderType.TAVILY: resolve_with_tavily,
        ProviderType.DUCKDUCKGO: resolve_with_duckduckgo,
        ProviderType.FIRECRAWL: resolve_with_firecrawl,
        ProviderType.MISTRAL_BROWSER: resolve_with_mistral_browser,
        ProviderType.MISTRAL_WEBSEARCH: resolve_with_mistral_websearch,
        ProviderType.DIRECT_FETCH: fetch_url_content,
        ProviderType.LLMS_TXT: fetch_llms_txt,
        ProviderType.SERPER: resolve_with_serper,
        ProviderType.DOCLING: resolve_with_docling,
        ProviderType.OCR: resolve_with_ocr,
    }
    if provider in funcs:
        if provider == ProviderType.LLMS_TXT:
            res_str = fetch_llms_txt(input_str)
            res = ResolvedResult(source="llms.txt", url=input_str, content=res_str[:max_chars] if res_str else "") if res_str else None
        elif provider == ProviderType.DIRECT_FETCH:
            res_str = fetch_url_content(input_str)
            res = ResolvedResult(source="direct_fetch", url=input_str, content=res_str[:max_chars] if res_str else "") if res_str else None
        else:
            res = funcs[provider](input_str, max_chars)
        return res.to_dict() if res else {"source": "none", "error": "Provider failed"}
    return {"source": "none", "error": "Unknown provider"}


def resolve_with_order(
    input_str: str, providers_order: list[ProviderType], max_chars: int = MAX_CHARS
) -> dict[str, Any]:
    for pt in providers_order:
        res = resolve_direct(input_str, pt, max_chars)
        if res.get("source") != "none":
            return res
    return {"source": "none", "error": "All providers failed"}


def resolve_url_with_order(
    url: str, order: list[ProviderType], max_chars: int = MAX_CHARS
) -> dict[str, Any]:
    return resolve_with_order(url, order, max_chars)


def resolve_query_with_order(
    query: str, order: list[ProviderType], max_chars: int = MAX_CHARS
) -> dict[str, Any]:
    return resolve_with_order(query, order, max_chars)
