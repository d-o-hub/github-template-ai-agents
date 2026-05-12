"""URL resolution - resolve_url and resolve_url_stream."""

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
    ResolvedResult,
    ResolveMetrics,
)
from scripts.providers_impl import (
    resolve_with_docling,
    resolve_with_duckduckgo,
    resolve_with_firecrawl,
    resolve_with_jina,
    resolve_with_mistral_browser,
    resolve_with_ocr,
)
from scripts.semantic_cache import get_semantic_cache
from scripts.utils import (
    _detect_error_type,
    _get_cache,
    compact_content,
    fetch_llms_txt,
    fetch_url_content,
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
) -> Generator[dict[str, Any], None, None]:
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
        max_provider_attempts=budget_data["max_provider_attempts"],
        max_paid_attempts=budget_data["max_paid_attempts"],
        max_total_latency_ms=budget_data["max_total_latency_ms"],
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

    cache = _get_cache()
    domain = scripts.routing.extract_domain(url)
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
            if scripts.cache_negative.should_skip_from_negative_cache(cache, url, p_name):
                continue
            if _circuit_breakers.is_open(p_name):
                continue

            logger.info(f"Starting probe: {p_name}")
            start_time_probe = time.time()
            future = executor.submit(func)
            active_futures[future] = (p_name, pt, start_time_probe)
            threshold = _routing_memory.get_p75_latency(domain or "any", p_name) / 1000.0

            while active_futures:
                elapsed = time.time() - start_time_probe

                if i < len(eligible) - 1 and elapsed >= threshold:
                    logger.info(f"Hedging threshold reached for {p_name} ({threshold}s)")
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
                        res_or_content = f.result()
                    except Exception as e:
                        err_type = _detect_error_type(e)
                        if err_type not in (ErrorType.AUTH_ERROR, ErrorType.SSRF_BLOCKED):
                            _circuit_breakers.record_failure(p_name_done)
                        metrics.record_provider(pt_done, latency, False)
                        continue
                    if res_or_content:
                        if isinstance(res_or_content, ResolvedResult):
                            content = res_or_content.content
                        else:
                            content = str(res_or_content)

                        q_score = scripts.quality.score_content(content)
                        if q_score.acceptable or pt_done == ProviderType.LLMS_TXT:
                            _circuit_breakers.record_success(p_name_done)
                            metrics.record_provider(pt_done, latency, True)
                            if domain:
                                _routing_memory.record(
                                    domain, p_name_done, True, latency, q_score.score
                                )

                            found_acceptable = True
                            if pt_done == ProviderType.LLMS_TXT:
                                result_dict = {
                                    "source": "llms.txt",
                                    "url": url,
                                    "content": compact_content(content, max_chars),
                                    "metrics": metrics,
                                }
                                _store_in_semantic_cache(url, result_dict)
                                yield result_dict
                            elif isinstance(res_or_content, ResolvedResult):
                                res_or_content.metrics, res_or_content.score = (
                                    metrics,
                                    q_score.score,
                                )
                                result_dict = res_or_content.to_dict()
                                _store_in_semantic_cache(url, result_dict)
                                yield result_dict
                            break
                        else:
                            scripts.cache_negative.write_negative_cache(
                                cache, url, p_name_done, "thin_content", 1800
                            )
                            if domain:
                                _routing_memory.record(
                                    domain, p_name_done, False, latency, q_score.score
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
        "url": url,
        "content": "Failed",
        "error": f"No resolution method available. Stop reason: {budget.stop_reason}",
    }
