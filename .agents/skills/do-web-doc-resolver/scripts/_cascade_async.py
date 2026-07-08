"""Async cascade resolution logic for query and URL resolution."""

import asyncio
import logging
import time
from collections.abc import AsyncGenerator, Callable
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

# Early exit threshold: if quality score exceeds this, return immediately
# without trying more providers. This trades potential marginal quality
# gains for significant latency reduction.
EXCELLENT_QUALITY_THRESHOLD = 0.85


async def cascade_stream_async(
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
) -> AsyncGenerator[dict[str, Any]]:
    """Async version of cascade_stream using asyncio tasks with true parallel launch."""
    skip = skip_providers or set()
    cache = _get_cache()
    _accept = content_acceptable or (lambda q, pt: q.acceptable)

    # Pre-filter eligible providers and prepare tasks
    tasks_to_launch: list[tuple[str, ProviderType, Callable]] = []
    for p_name in eligible:
        if p_name in skip:
            continue
        pt, func = cascade_map[p_name]

        if not budget.can_try(is_paid=pt.is_paid()):
            if budget.stop_reason in ("paid_disabled", "max_paid_attempts"):
                continue
            break
        if scripts.cache_negative.should_skip_from_negative_cache(cache, target, p_name):
            continue
        if circuit_breakers.is_open(p_name):
            continue

        tasks_to_launch.append((p_name, pt, func))

    if not tasks_to_launch:
        yield {
            "source": "none",
            target_key: target,
            "content": "Failed",
            "error": f"No providers available. Stop reason: {budget.stop_reason}",
        }
        return

    # Launch all providers in parallel
    active_tasks: dict[asyncio.Task, tuple[str, ProviderType, float]] = {}
    best_free_result: dict[str, Any] | None = None

    for p_name, pt, func in tasks_to_launch:
        logger.info("Starting parallel probe: %s", p_name)
        start_time_probe = time.time()
        task = asyncio.create_task(func())
        active_tasks[task] = (p_name, pt, start_time_probe)

    try:
        while active_tasks:
            # Wait for any task to complete
            done, _ = await asyncio.wait(
                active_tasks.keys(),
                return_when=asyncio.FIRST_COMPLETED,
            )

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
                            # Paid provider succeeded - return immediately
                            semantic_cache_store(target, result_dict)
                            yield result_dict
                            return
                        else:
                            if not best_free_result or q_score.score > best_free_result.get(
                                "score", 0.0
                            ):
                                best_free_result = result_dict

                            # Early exit: excellent quality
                            if q_score.score >= EXCELLENT_QUALITY_THRESHOLD:
                                logger.info(
                                    "Early exit: excellent quality %.2f from %s",
                                    q_score.score,
                                    p_name_done,
                                )
                                metrics.quality_gate = {
                                    "passed": True,
                                    "score": q_score.score,
                                    "early_exit": True,
                                }
                                result_dict["metrics"] = asdict(metrics)
                                semantic_cache_store(target, result_dict)
                                yield result_dict
                                return

                            # Quality gate: skip paid if free result is good enough
                            if q_score.score >= budget.min_free_quality_to_skip_paid:
                                metrics.quality_gate = {"passed": True, "score": q_score.score}
                                result_dict["metrics"] = asdict(metrics)
                                semantic_cache_store(target, result_dict)
                                yield result_dict
                                return
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

    finally:
        for task in active_tasks:
            task.cancel()

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
