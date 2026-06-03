"""Query resolution - resolve_query and resolve_query_stream."""

import logging
from collections.abc import Generator
from typing import Any

import scripts.routing
from scripts._cascade import cascade_stream
from scripts.models import Profile, ProviderType, ResolveMetrics
from scripts.providers_impl import (
    resolve_with_duckduckgo,
    resolve_with_exa,
    resolve_with_exa_mcp,
    resolve_with_mistral_websearch,
    resolve_with_serper,
    resolve_with_tavily,
)
from scripts.semantic_cache import get_semantic_cache
from scripts.state import circuit_breakers as _circuit_breakers
from scripts.state import routing_memory as _routing_memory

logger = logging.getLogger(__name__)


def _check_semantic_cache(query_or_url: str) -> dict[str, Any] | None:
    """Check semantic cache for similar query/URL."""
    cache = get_semantic_cache()
    if cache is None:
        return None

    try:
        entry = cache.query(query_or_url)
        if entry:
            logger.info(
                f"Semantic cache hit for '{query_or_url[:50]}...' (similarity: {entry.similarity:.3f})"
            )
            result = dict(entry.result)
            result["semantic_cache_hit"] = True
            result["semantic_similarity"] = entry.similarity
            result["semantic_original_query"] = entry.query
            return result
    except Exception as e:
        logger.debug(f"Semantic cache check failed: {e}")

    return None


def _store_in_semantic_cache(query_or_url: str, result: dict[str, Any]) -> bool:
    """Store a successful result in the semantic cache."""
    cache = get_semantic_cache()
    if cache is None:
        return False

    if result.get("source") == "none" or result.get("semantic_cache_hit"):
        return False

    try:
        return cache.store(query_or_url, result)
    except Exception as e:
        logger.debug(f"Failed to store in semantic cache: {e}")
        return False


__all__ = [
    "resolve_query",
    "resolve_query_stream",
]


def resolve_query(
    query: str,
    max_chars: int = 8000,
    skip_providers: set[str] | None = None,
    profile: Profile = Profile.BALANCED,
) -> dict[str, Any]:
    for result in resolve_query_stream(query, max_chars, skip_providers, profile):
        if result.get("source") != "partial":
            return result
    return {"source": "none", "query": query, "content": "Failed"}


def resolve_query_stream(
    query: str,
    max_chars: int = 8000,
    skip_providers: set[str] | None = None,
    profile: Profile = Profile.BALANCED,
) -> Generator[dict[str, Any]]:
    skip = skip_providers or set()

    cached_result = _check_semantic_cache(query)
    if cached_result:
        cached_result["query"] = query
        yield cached_result
        return

    metrics = ResolveMetrics()
    budget_data = scripts.routing.PROFILE_BUDGETS.get(
        profile.value, scripts.routing.PROFILE_BUDGETS["balanced"]
    )
    budget = scripts.routing.ResolutionBudget(
        max_provider_attempts=int(budget_data["max_provider_attempts"]),
        max_paid_attempts=int(budget_data["max_paid_attempts"]),
        max_total_latency_ms=int(budget_data["max_total_latency_ms"]),
        min_free_quality_to_skip_paid=float(budget_data.get("min_free_quality_to_skip_paid", 0.70)),
        allow_paid=bool(budget_data["allow_paid"]),
    )
    provider_names = scripts.routing.plan_provider_order(
        target=query, is_url=False, skip_providers=skip, routing_memory=_routing_memory
    )
    cascade_map = {
        "exa_mcp": (ProviderType.EXA_MCP, lambda: resolve_with_exa_mcp(query, max_chars)),
        "exa": (ProviderType.EXA, lambda: resolve_with_exa(query, max_chars)),
        "tavily": (ProviderType.TAVILY, lambda: resolve_with_tavily(query, max_chars)),
        "serper": (ProviderType.SERPER, lambda: resolve_with_serper(query, max_chars)),
        "duckduckgo": (ProviderType.DUCKDUCKGO, lambda: resolve_with_duckduckgo(query, max_chars)),
        "mistral_websearch": (
            ProviderType.MISTRAL_WEBSEARCH,
            lambda: resolve_with_mistral_websearch(query, max_chars),
        ),
    }
    eligible = [p for p in provider_names if p in cascade_map]

    yield from cascade_stream(
        target=query,
        cascade_map=cascade_map,
        eligible=eligible,
        budget=budget,
        metrics=metrics,
        routing_memory=_routing_memory,
        circuit_breakers=_circuit_breakers,
        semantic_cache_store=_store_in_semantic_cache,
        routing_key=query,
    )
