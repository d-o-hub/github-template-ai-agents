import logging

logger = logging.getLogger(__name__)

DEFAULT_PROVIDER_STATS = {
    "success": 0,
    "failure": 0,
    "avg_latency_ms": 0.0,
    "avg_quality": 0.0,
    "last_attempted": None,
}


def compute_p75_latency(avg_latency_ms: float, default: int = 3000) -> int:
    if avg_latency_ms == 0:
        return default
    return int(avg_latency_ms * 1.5)
