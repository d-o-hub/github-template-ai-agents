"""Async URL resolution - resolve_url_async and resolve_url_stream_async."""

import logging
from collections.abc import AsyncGenerator
from dataclasses import asdict
from typing import Any

import scripts.routing
from scripts._cascade_async import cascade_stream_async
from scripts.constants import PROVIDER_TIERS
from scripts.models import FetchTier, Profile, ProviderType, ResolvedResult, ResolveMetrics
from scripts.providers.jina import resolve_with_jina_async
from scripts.providers.visual_clip import resolve_with_visual_clip_async
from scripts.providers_impl import (
    resolve_with_stealth,
)
from scripts.semantic_cache import get_semantic_cache
from scripts.state import circuit_breakers as _circuit_breakers
from scripts.state import routing_memory as _routing_memory
from scripts.utils import compact_content

logger = logging.getLogger(__name__)


async def resolve_url_async(
    url: str,
    max_chars: int = 8000,
    profile: Profile = Profile.BALANCED,
    query: str | None = None,
    skip_providers: set[str] | None = None,
) -> dict[str, Any]:
    """Async version of resolve_url."""
    async for result in resolve_url_stream_async(
        url, max_chars, profile, query=query, skip_providers=skip_providers
    ):
        if result.get("source") != "partial":
            return result
    return {"source": "none", "url": url, "content": "Failed"}


async def resolve_url_stream_async(
    url: str,
    max_chars: int = 8000,
    profile: Profile = Profile.BALANCED,
    query: str | None = None,
    skip_providers: set[str] | None = None,
) -> AsyncGenerator[dict[str, Any]]:
    """Async generator version of resolve_url_stream."""
    logger.info(f"Resolving URL async: {url}")

    cached_result = _check_semantic_cache(url)
    if cached_result:
        cached_result["url"] = url
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
        target=url, is_url=True, routing_memory=_routing_memory, skip_providers=skip_providers
    )

    # Async provider map - only async providers for now
    cascade_map: dict[str, tuple[ProviderType, Any]] = {
        "jina": (ProviderType.JINA, lambda: resolve_with_jina_async(url, max_chars)),
        "visual_clip": (
            ProviderType.VISUAL_CLIP,
            lambda: resolve_with_visual_clip_async(url, max_chars, query=query),
        ),
        "stealth": (
            ProviderType.DIRECT_FETCH,
            lambda: resolve_with_stealth(url, max_chars),
        ),
        # TODO: Add async versions of other providers
        # "firecrawl": (ProviderType.FIRECRAWL, lambda: resolve_with_firecrawl_async(url, max_chars)),
        # "direct_fetch": (ProviderType.DIRECT_FETCH, lambda: fetch_url_content_async(url, max_chars)),
        # "mistral_browser": (ProviderType.MISTRAL_BROWSER, lambda: resolve_with_mistral_browser_async(url, max_chars)),
        # "duckduckgo": (ProviderType.DUCKDUCKGO, lambda: resolve_with_duckduckgo_async(url, max_chars)),
    }

    domain = scripts.routing.extract_domain(url)

    def _sort_by_tier(provider_name: str) -> int:
        val = PROVIDER_TIERS.get(provider_name, FetchTier.PAID_BROWSER)
        return int(val)

    eligible = sorted(
        [p for p in provider_names if p in cascade_map],
        key=_sort_by_tier,
    )

    if not eligible:
        # Fall back to sync cascade for providers not yet converted
        logger.info("No async providers eligible, falling back to sync cascade")
        from scripts._url_resolve import resolve_url_stream

        for result in resolve_url_stream(
            url, max_chars, profile, query=query, skip_providers=skip_providers
        ):
            yield result
        return

    def _url_result_builder(res, target_url, p_name, met, score):
        if isinstance(res, ResolvedResult):
            res.metrics, res.score = met, score
            return res.to_dict()
        elif p_name == "llms_txt":
            return {
                "source": "llms.txt",
                "url": target_url,
                "content": compact_content(str(res), max_chars),
                "metrics": asdict(met),
                "score": score,
            }
        else:
            return {
                "source": p_name,
                "url": target_url,
                "content": str(res),
                "metrics": asdict(met),
                "score": score,
            }

    async for result in cascade_stream_async(
        target=url,
        cascade_map=cascade_map,
        eligible=eligible,
        budget=budget,
        metrics=metrics,
        routing_memory=_routing_memory,
        circuit_breakers=_circuit_breakers,
        semantic_cache_store=_store_in_semantic_cache,
        routing_key=domain or "any",
        result_builder=_url_result_builder,
        content_acceptable=lambda q, pt: q.acceptable or pt == ProviderType.LLMS_TXT,
        target_key="url",
    ):
        yield result


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
