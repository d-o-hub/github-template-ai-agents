"""Shared mutable state for the Web Doc Resolver — eliminates monkey-patching."""

import os
from dataclasses import dataclass, field

from scripts.circuit_breaker import CircuitBreakerRegistry
from scripts.routing_memory import RoutingMemory


def _routing_memory_factory() -> RoutingMemory:
    """Build RoutingMemory, persisting to disk when DO_WDR_ROUTING_MEMORY_PATH is set.

    Defaults to in-memory so library/test usage stays side-effect free; the CLI
    sets DO_WDR_ROUTING_MEMORY_PATH before importing this module to retain
    learned provider preferences across runs (AUDIT #25).
    """
    path = os.getenv("DO_WDR_ROUTING_MEMORY_PATH")
    if not path:
        return RoutingMemory()
    return RoutingMemory(path=path)


@dataclass
class ResolverState:
    circuit_breakers: CircuitBreakerRegistry = field(default_factory=CircuitBreakerRegistry)
    routing_memory: RoutingMemory = field(default_factory=_routing_memory_factory)


_state = ResolverState()
circuit_breakers = _state.circuit_breakers
routing_memory = _state.routing_memory
