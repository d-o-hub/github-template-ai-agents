"""
Per-domain routing memory for the Web Doc Resolver.
"""

import logging
import math
import threading
import time
from collections import defaultdict

from scripts._routing_utils import DEFAULT_PROVIDER_STATS, compute_p75_latency

logger = logging.getLogger(__name__)
SCORE_BASE = 0.5
RECENCY_DECAY_DAYS = 7.0
SCORE_SCALE = 1000.0


class RoutingMemory:
    def __init__(self):
        # domain -> provider -> stats
        self.domain_stats = defaultdict(lambda: defaultdict(lambda: dict(DEFAULT_PROVIDER_STATS)))
        self._lock = threading.RLock()

    def record(
        self, domain: str, provider: str, success: bool, latency_ms: int, quality_score: float
    ) -> None:
        with self._lock:
            stats = self.domain_stats[domain][provider]
            total = stats["success"] + stats["failure"]
            stats["avg_latency_ms"] = ((stats["avg_latency_ms"] * total) + latency_ms) / (total + 1)
            stats["avg_quality"] = ((stats["avg_quality"] * total) + quality_score) / (total + 1)
            stats["last_attempted"] = time.time()
            if success:
                stats["success"] += 1
            else:
                stats["failure"] += 1

    def get_domain_stats(self, provider: str, domain: str) -> dict | None:
        with self._lock:
            if domain not in self.domain_stats or provider not in self.domain_stats[domain]:
                return None

            stats = self.domain_stats[domain][provider]
            attempts = stats["success"] + stats["failure"]
            if attempts == 0:
                return None

            success_rate = stats["success"] / attempts
            days_since_last = 0.0
            if stats["last_attempted"]:
                days_since_last = (time.time() - stats["last_attempted"]) / 86400.0

            return {
                "attempts": attempts,
                "success_rate": success_rate,
                "avg_latency_ms": stats["avg_latency_ms"],
                "avg_quality": stats["avg_quality"],
                "days_since_last": days_since_last,
            }

    def rank_providers(self, domain: str, providers: list[str]) -> list[str]:
        with self._lock:
            scores = {}
            for p in providers:
                stats = self.get_domain_stats(p, domain)
                if not stats or stats["attempts"] == 0:
                    scores[p] = SCORE_BASE
                    continue

                quality_factor = SCORE_BASE + SCORE_BASE * stats.get("avg_quality", SCORE_BASE)
                recency = math.exp(-stats["days_since_last"] / RECENCY_DECAY_DAYS)
                score = (
                    (stats["success_rate"] * quality_factor * recency)
                    * SCORE_SCALE
                    / max(stats["avg_latency_ms"], 1.0)
                )
                scores[p] = score

                logger.debug(
                    "Provider score: domain=%s, provider=%s, score=%.4f, success_rate=%.2f, quality=%.2f, recency=%.2f, latency=%.1fms",
                    domain,
                    p,
                    score,
                    stats["success_rate"],
                    stats.get("avg_quality", 0.5),
                    recency,
                    stats["avg_latency_ms"],
                )

            return sorted(providers, key=lambda p: scores[p], reverse=True)

    def rank(self, domain: str, providers: list[str]) -> list[str]:
        """Backward compatibility for rank method."""
        return self.rank_providers(domain, providers)

    def get_p75_latency(self, domain: str, provider: str, default: int = 3000) -> int:
        with self._lock:
            stats = self.domain_stats.get(domain, {}).get(provider)
            if not stats:
                return default
            return compute_p75_latency(stats["avg_latency_ms"], default)

    def clear(self) -> None:
        with self._lock:
            self.domain_stats.clear()
