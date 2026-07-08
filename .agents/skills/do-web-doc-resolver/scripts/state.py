"""Shared mutable state for the Web Doc Resolver — eliminates monkey-patching."""

from dataclasses import dataclass, field
from typing import Any

from scripts.circuit_breaker import CircuitBreakerRegistry
from scripts.routing_memory import RoutingMemory


@dataclass
class ResolverState:
    circuit_breakers: CircuitBreakerRegistry = field(default_factory=CircuitBreakerRegistry)
    routing_memory: RoutingMemory = field(default_factory=RoutingMemory)
    semantic_cache: Any = None


_state = ResolverState()
circuit_breakers = _state.circuit_breakers
routing_memory = _state.routing_memory


def get_state() -> ResolverState:
    return _state
