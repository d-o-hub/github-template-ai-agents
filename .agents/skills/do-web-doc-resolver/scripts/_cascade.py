"""Shared cascade resolution logic for query and URL resolution."""

import concurrent.futures
import logging
import time
from collections.abc import Callable, Generator
from dataclasses import asdict
from typing import Any

import scripts.cache_negative
import scripts.quality
from scripts.models import ErrorType, ProviderType, ResolvedResult, ResolveMetrics
from scripts.utils import _detect_error_type, _get_cache

logger = logging.getLogger(__name__)


def cascade_stream(
    target: str,
    cascade_map: dict[str, tuple[ProviderType, Callable]],
    eligible: list[str],
    budget: Any,
    metrics: ResolveMetrics,
    routing_memory: Any,
    circuit_breakers: Any,
    semantic_cache_store: Callable[[str, dict], bool],
    routing_key: str,
    result_builder: Callable[[Any, str, str, ResolveMetrics, float], dict[str, Any]] | None = None,
    skip_providers: set[str] | None = None,
    content_acceptable: Callable[[Any, ProviderType], bool] | None = None,
    target_key: str = "query",
) -> Generator[dict[str, Any]]:
    skip = skip_providers or set()
    cache = _get_cache()
    active_futures: dict[Any, tuple[str, ProviderType, float]] = {}
    best_free_result: dict[str, Any] | None = None
    _accept = content_acceptable or (lambda q, pt: q.acceptable)

    from scripts.state import get_executor

    executor = get_executor(max_workers=max(10, len(eligible)))
    try:
        for i, p_name in enumerate(eligible):
            if p_name in skip:
                continue
            pt, func = cascade_map[p_name]

            if pt.is_paid() and best_free_result:
                score = best_free_result.get("score", 0.0)
                if score >= budget.min_free_quality_to_skip_paid:
                    metrics.quality_gate = {"passed": True, "score": score}
                    best_free_result["metrics"] = asdict(metrics)
                    semantic_cache_store(target, best_free_result)
                    yield best_free_result
                    return

            if not budget.can_try(is_paid=pt.is_paid()):
                if budget.stop_reason in ("paid_disabled", "max_paid_attempts"):
                    continue
                break
            if scripts.cache_negative.should_skip_from_negative_cache(cache, target, p_name):
                continue
            if circuit_breakers.is_open(p_name):
                continue

            logger.info("Starting probe: %s", p_name)
            start_time_probe = time.time()
            future = executor.submit(func)
            active_futures[future] = (p_name, pt, start_time_probe)
            threshold = routing_memory.get_p75_latency(routing_key, p_name) / 1000.0

            while active_futures:
                elapsed = time.time() - start_time_probe
                if i < len(eligible) - 1 and elapsed >= threshold:
                    break

                done, _ = concurrent.futures.wait(
                    active_futures.keys(),
                    timeout=0.01,
                    return_when=concurrent.futures.FIRST_COMPLETED,
                )
                found_final = False
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
                            circuit_breakers.record_failure(p_name_done)
                        metrics.record_provider(pt_done, latency, False)
                        continue
                    if res:
                        content = res.content if isinstance(res, ResolvedResult) else str(res)
                        q_score = scripts.quality.score_content(content)
                        if _accept(q_score, pt_done):
                            circuit_breakers.record_success(p_name_done)
                            metrics.record_provider(pt_done, latency, True)
                            routing_memory.record(
                                routing_key, p_name_done, True, latency, q_score.score
                            )

                            if result_builder:
                                result_dict = result_builder(
                                    res, target, p_name_done, metrics, q_score.score
                                )
                            elif isinstance(res, ResolvedResult):
                                res.metrics, res.score = metrics, q_score.score
                                result_dict = res.to_dict()
                            else:
                                result_dict = {
                                    "source": p_name_done,
                                    "content": content,
                                    "metrics": asdict(metrics),
                                    "score": q_score.score,
                                }

                            if pt_done.is_paid():
                                semantic_cache_store(target, result_dict)
                                yield result_dict
                                found_final = True
                                break
                            else:
                                if not best_free_result or q_score.score > best_free_result.get(
                                    "score", 0.0
                                ):
                                    best_free_result = result_dict

                                if q_score.score >= budget.min_free_quality_to_skip_paid:
                                    metrics.quality_gate = {"passed": True, "score": q_score.score}
                                    result_dict["metrics"] = asdict(metrics)
                                    semantic_cache_store(target, result_dict)
                                    yield result_dict
                                    found_final = True
                                    break
                        else:
                            scripts.cache_negative.write_negative_cache(
                                cache, target, p_name_done, "thin_content"
                            )
                            routing_memory.record(
                                routing_key, p_name_done, False, latency, q_score.score
                            )
                    else:
                        circuit_breakers.record_failure(p_name_done)
                        metrics.record_provider(pt_done, latency, False)

                if found_final:
                    return
                if done:
                    break
                if not active_futures:
                    break
    finally:
        for f in active_futures:
            f.cancel()

    if best_free_result:
        best_free_result["metrics"] = asdict(metrics)
        semantic_cache_store(target, best_free_result)
        yield best_free_result
    else:
        yield {
            "source": "none",
            target_key: target,
            "content": "Failed",
            "error": f"No resolution method available. Stop reason: {budget.stop_reason}",
        }
