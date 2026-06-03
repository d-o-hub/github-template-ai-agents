"""Shared mutable state for the Web Doc Resolver — eliminates monkey-patching."""

import atexit
import concurrent.futures
from dataclasses import dataclass, field
from typing import Any

from scripts.circuit_breaker import CircuitBreakerRegistry
from scripts.routing_memory import RoutingMemory


@dataclass
class ResolverState:
    circuit_breakers: CircuitBreakerRegistry = field(default_factory=CircuitBreakerRegistry)
    routing_memory: RoutingMemory = field(default_factory=RoutingMemory)
    semantic_cache: Any = None
    executor: concurrent.futures.ThreadPoolExecutor | None = None


_state = ResolverState()
circuit_breakers = _state.circuit_breakers
routing_memory = _state.routing_memory

_executor: concurrent.futures.ThreadPoolExecutor | None = None


def get_state() -> ResolverState:
    return _state


def get_executor(max_workers: int = 10) -> concurrent.futures.ThreadPoolExecutor:
    global _executor
    if _executor is None:
        _executor = concurrent.futures.ThreadPoolExecutor(
            max_workers=max_workers, thread_name_prefix="resolver"
        )
        _state.executor = _executor
    return _executor


def _shutdown_executor() -> None:
    global _executor
    if _executor is not None:
        _executor.shutdown(wait=False)
        _executor = None
        _state.executor = None


atexit.register(_shutdown_executor)
