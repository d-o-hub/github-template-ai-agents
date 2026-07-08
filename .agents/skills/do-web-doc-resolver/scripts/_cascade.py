"""Shared cascade resolution logic for query and URL resolution."""

import asyncio
import logging
import time
from collections.abc import Callable, Generator
from dataclasses import asdict
from typing import Any

import scripts.cache_negative
import scripts.quality
from scripts.circuit_breaker import CircuitBreakerRegistry
from scripts.models import (
    ErrorType,
    ProviderType,
    ReadonlyResolverProtocol,
    ResolvedResult,
    ResolveMetrics,
)
from scripts.routing import ResolutionBudget
from scripts.routing_memory import RoutingMemory
from scripts.utils import _detect_error_type, _get_cache

logger = logging.getLogger(__name__)


def cascade_stream(
    target: str,
    cascade_map: dict[str, tuple[ProviderType, ReadonlyResolverProtocol]],
    eligible: list[str],
    budget: ResolutionBudget,
    metrics: ResolveMetrics,
    routing_memory: RoutingMemory,
    circuit_breakers: CircuitBreakerRegistry,
    semantic_cache_store: Callable[[str, dict], bool],
    routing_key: str,
    result_builder: Callable[[Any, str, str, ResolveMetrics, float], dict[str, Any]] | None = None,
    skip_providers: set[str] | None = None,
    content_acceptable: Callable[[Any, ProviderType], bool] | None = None,
    target_key: str = "query",
) -> Generator[dict[str, Any]]:
    skip = skip_providers or set()
    cache = _get_cache()
    _accept = content_acceptable or (lambda q, pt: q.acceptable)

    # Mutable state shared with inner async function
    state: dict[str, Any] = {"best_free_result": None}

    async def _run_cascade() -> dict[str, Any] | None:
        active_tasks: dict[asyncio.Task, tuple[str, ProviderType, float]] = {}

        for i, p_name in enumerate(eligible):
            if p_name in skip:
                continue
            pt, func = cascade_map[p_name]

            if pt.is_paid() and state["best_free_result"]:
                score = state["best_free_result"].get("score", 0.0)
                if score >= budget.min_free_quality_to_skip_paid:
                    metrics.quality_gate = {"passed": True, "score": score}
                    state["best_free_result"]["metrics"] = asdict(metrics)
                    semantic_cache_store(target, state["best_free_result"])
                    return dict(state["best_free_result"])

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
            task = asyncio.create_task(asyncio.to_thread(func))
            active_tasks[task] = (p_name, pt, start_time_probe)
            threshold = routing_memory.get_p75_latency(routing_key, p_name) / 1000.0

            while active_tasks:
                elapsed = time.time() - start_time_probe
                if i < len(eligible) - 1 and elapsed >= threshold:
                    break

                # Calculate timeout: use remaining time until threshold, or None if no threshold
                remaining = threshold - elapsed if i < len(eligible) - 1 else None
                done, _ = await asyncio.wait(
                    active_tasks.keys(),
                    timeout=remaining,
                    return_when=asyncio.FIRST_COMPLETED,
                )
                found_final = False
                for task_done in list(done):
                    if task_done not in active_tasks:
                        continue
                    p_name_done, pt_done, s_time = active_tasks.pop(task_done)
                    latency = int((time.time() - s_time) * 1000)
                    budget.record_attempt(is_paid=pt_done.is_paid(), latency_ms=latency)
                    try:
                        res = task_done.result()
                    except Exception as e:
                        err_type = _detect_error_type(e)
                        if err_type not in (
                            ErrorType.AUTH_ERROR,
                            ErrorType.SSRF_BLOCKED,
                            ErrorType.BOT_CHALLENGE,
                        ):
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
                                return result_dict
                            else:
                                if not state["best_free_result"] or q_score.score > state[
                                    "best_free_result"
                                ].get("score", 0.0):
                                    state["best_free_result"] = result_dict

                                if q_score.score >= budget.min_free_quality_to_skip_paid:
                                    metrics.quality_gate = {"passed": True, "score": q_score.score}
                                    result_dict["metrics"] = asdict(metrics)
                                    semantic_cache_store(target, result_dict)
                                    return dict(result_dict)
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
                    return None
                if done:
                    break
                if not active_tasks:
                    break

        if state["best_free_result"]:
            return dict(state["best_free_result"])
        return None

    # Run async cascade
    try:
        loop = asyncio.get_running_loop()
    except RuntimeError:
        loop = None

    if loop and loop.is_running():
        import concurrent.futures

        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
            result = pool.submit(asyncio.run, _run_cascade()).result()
    else:
        result = asyncio.run(_run_cascade())

    if result:
        yield result
    else:
        yield {
            "source": "none",
            target_key: target,
            "content": "Failed",
            "error": f"No resolution method available. Stop reason: {budget.stop_reason}",
        }
