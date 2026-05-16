"""Query resolution - resolve_query and resolve_query_stream."""

import concurrent.futures
import logging
import time
from collections.abc import Generator
from typing import Any

import scripts.cache_negative
import scripts.circuit_breaker
import scripts.providers_impl
import scripts.quality
import scripts.routing
import scripts.routing_memory
import scripts.semantic_cache
import scripts.utils
from scripts.models import (
    ErrorType,
    Profile,
    ProviderType,
    ResolveMetrics,
)
from scripts.providers_impl import (
    resolve_with_duckduckgo,
    resolve_with_exa,
    resolve_with_exa_mcp,
    resolve_with_mistral_websearch,
    resolve_with_serper,
    resolve_with_tavily,
)
from scripts.semantic_cache import get_semantic_cache
from scripts.utils import (
    _detect_error_type,
    _get_cache,
)

logger = logging.getLogger(__name__)

_circuit_breakers = scripts.circuit_breaker.CircuitBreakerRegistry()
_routing_memory = scripts.routing_memory.RoutingMemory()


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
) -> Generator[dict[str, Any], None, None]:
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
        max_provider_attempts=budget_data["max_provider_attempts"],
        max_paid_attempts=budget_data["max_paid_attempts"],
        max_total_latency_ms=budget_data["max_total_latency_ms"],
        allow_paid=bool(budget_data["allow_paid"]),
    )
    provider_names = scripts.routing.plan_provider_order(
        target=query, is_url=False, skip_providers=skip, routing_memory=_routing_memory
    )
    cascade_map = {
        "exa_mcp": (ProviderType.EXA_MCP, resolve_with_exa_mcp),
        "exa": (ProviderType.EXA, resolve_with_exa),
        "tavily": (ProviderType.TAVILY, resolve_with_tavily),
        "serper": (ProviderType.SERPER, resolve_with_serper),
        "duckduckgo": (ProviderType.DUCKDUCKGO, resolve_with_duckduckgo),
        "mistral_websearch": (ProviderType.MISTRAL_WEBSEARCH, resolve_with_mistral_websearch),
    }
    cache = _get_cache()
    eligible = [p for p in provider_names if p in cascade_map]
    active_futures = {}

    from scripts import resolve as resolve_module

    executor = resolve_module._get_executor(max_workers=max(10, len(eligible)))
    try:
        for i, p_name in enumerate(eligible):
            pt, func = cascade_map[p_name]
            if not budget.can_try(is_paid=pt.is_paid()):
                if budget.stop_reason in ("paid_disabled", "max_paid_attempts"):
                    continue
                break
            if scripts.cache_negative.should_skip_from_negative_cache(cache, query, p_name):
                continue
            if _circuit_breakers.is_open(p_name):
                continue
            logger.info(f"Starting probe: {p_name}")
            start_time_probe = time.time()
            future = executor.submit(func, query, max_chars)
            active_futures[future] = (p_name, pt, start_time_probe)
            threshold = _routing_memory.get_p75_latency("query", p_name) / 1000.0
            while active_futures:
                elapsed = time.time() - start_time_probe
                if i < len(eligible) - 1 and elapsed >= threshold:
                    break

                done, _ = concurrent.futures.wait(
                    active_futures.keys(),
                    timeout=0.01,
                    return_when=concurrent.futures.FIRST_COMPLETED,
                )
                found_acceptable = False
                for f in list(done):
                    if f not in active_futures:
                        continue
                    p_name_done, pt_done, s_time = active_futures.pop(f)
                    latency = int((time.time() - s_time) * 1000)
                    budget.record_attempt(is_paid=pt_done.is_paid(), latency_ms=latency)
                    try:
                        res = f.result()
                    except Exception as e:
                        err_type = _detect_error_type(e)
                        if err_type not in (ErrorType.AUTH_ERROR, ErrorType.SSRF_BLOCKED):
                            _circuit_breakers.record_failure(p_name_done)
                        metrics.record_provider(pt_done, latency, False)
                        continue
                    if res:
                        q_score = scripts.quality.score_content(res.content)
                        if q_score.acceptable:
                            _circuit_breakers.record_success(p_name_done)
                            metrics.record_provider(pt_done, latency, True)
                            _routing_memory.record(
                                "query", p_name_done, True, latency, q_score.score
                            )

                            found_acceptable = True
                            res.metrics, res.score = metrics, q_score.score
                            result_dict = res.to_dict()
                            _store_in_semantic_cache(query, result_dict)
                            yield result_dict
                            break
                        else:
                            scripts.cache_negative.write_negative_cache(
                                cache, query, p_name_done, "thin_content", 1800
                            )
                            _routing_memory.record(
                                "query", p_name_done, False, latency, q_score.score
                            )
                    else:
                        _circuit_breakers.record_failure(p_name_done)
                        metrics.record_provider(pt_done, latency, False)

                if found_acceptable:
                    return
                if done:
                    break
                if not active_futures:
                    break
    finally:
        # We don't shut down the shared executor, but we should cancel our own futures
        for f in active_futures:
            f.cancel()

    yield {
        "source": "none",
        "query": query,
        "content": "Failed",
        "error": f"No resolution method available. Stop reason: {budget.stop_reason}",
    }
