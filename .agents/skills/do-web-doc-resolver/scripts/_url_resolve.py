"""URL resolution - resolve_url and resolve_url_stream."""

import logging
from collections.abc import Generator
from dataclasses import asdict
from typing import Any

import scripts.routing
from scripts._cascade import cascade_stream
from scripts.models import Profile, ProviderType, ResolvedResult, ResolveMetrics
from scripts.providers_impl import (
    resolve_with_docling,
    resolve_with_duckduckgo,
    resolve_with_firecrawl,
    resolve_with_jina,
    resolve_with_mistral_browser,
    resolve_with_ocr,
)
from scripts.semantic_cache import get_semantic_cache
from scripts.state import circuit_breakers as _circuit_breakers
from scripts.state import routing_memory as _routing_memory
from scripts.utils import (
    compact_content,
    fetch_llms_txt,
    fetch_url_content,
)

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
    "resolve_url",
    "resolve_url_stream",
]


def resolve_url(
    url: str, max_chars: int = 8000, profile: Profile = Profile.BALANCED
) -> dict[str, Any]:
    for result in resolve_url_stream(url, max_chars, profile):
        if result.get("source") != "partial":
            return result
    return {"source": "none", "url": url, "content": "Failed"}


def resolve_url_stream(
    url: str, max_chars: int = 8000, profile: Profile = Profile.BALANCED
) -> Generator[dict[str, Any]]:
    logger.info(f"Resolving URL: {url}")

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

    if any(url.lower().endswith(ext) for ext in [".pdf", ".docx", ".pptx"]):
        res = resolve_with_docling(url, max_chars)
        if res:
            res.metrics = metrics
            yield res.to_dict()
            return
    if any(url.lower().endswith(ext) for ext in [".png", ".jpg", ".jpeg"]):
        res = resolve_with_ocr(url, max_chars)
        if res:
            res.metrics = metrics
            yield res.to_dict()
            return

    provider_names = scripts.routing.plan_provider_order(
        target=url, is_url=True, routing_memory=_routing_memory
    )
    cascade_map: dict[str, tuple[ProviderType, Any]] = {
        "llms_txt": (ProviderType.LLMS_TXT, lambda: fetch_llms_txt(url)),
        "jina": (ProviderType.JINA, lambda: resolve_with_jina(url, max_chars)),
        "firecrawl": (ProviderType.FIRECRAWL, lambda: resolve_with_firecrawl(url, max_chars)),
        "direct_fetch": (
            ProviderType.DIRECT_FETCH,
            lambda: fetch_url_content(url, max_chars=max_chars),
        ),
        "mistral_browser": (
            ProviderType.MISTRAL_BROWSER,
            lambda: resolve_with_mistral_browser(url, max_chars),
        ),
        "duckduckgo": (ProviderType.DUCKDUCKGO, lambda: resolve_with_duckduckgo(url, max_chars)),
    }

    domain = scripts.routing.extract_domain(url)
    eligible = [p for p in provider_names if p in cascade_map]

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

    yield from cascade_stream(
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
    )
