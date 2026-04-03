"""
Per-domain routing memory for the Web Doc Resolver.
"""

from collections import defaultdict


class RoutingMemory:
    def __init__(self):
        # domain -> provider -> stats
        self.domain_stats = defaultdict(
            lambda: defaultdict(
                lambda: {
                    "success": 0,
                    "failure": 0,
                    "avg_latency_ms": 0.0,
                    "avg_quality": 0.0,
                }
            )
        )

    def record(
        self, domain: str, provider: str, success: bool, latency_ms: int, quality_score: float
    ) -> None:
        stats = self.domain_stats[domain][provider]
        total = stats["success"] + stats["failure"]
        stats["avg_latency_ms"] = ((stats["avg_latency_ms"] * total) + latency_ms) / (total + 1)
        stats["avg_quality"] = ((stats["avg_quality"] * total) + quality_score) / (total + 1)
        if success:
            stats["success"] += 1
        else:
            stats["failure"] += 1

    def rank(self, domain: str, providers: list[str]) -> list[str]:
        if domain not in self.domain_stats:
            return providers

        def provider_score(provider: str) -> tuple[float, float, float]:
            s = self.domain_stats[domain][provider]
            total = s["success"] + s["failure"]
            success_rate = (s["success"] / total) if total else 0.5
            # Rank by success rate, then quality, then (negative) latency
            return (success_rate, s["avg_quality"], -s["avg_latency_ms"])

        return sorted(providers, key=provider_score, reverse=True)

    def get_p75_latency(self, domain: str, provider: str, default: int = 2500) -> int:
        stats = self.domain_stats.get(domain, {}).get(provider)
        if not stats or stats["avg_latency_ms"] == 0:
            return default
        # Heuristic: p75 is often ~1.5x average for tail latency
        return int(stats["avg_latency_ms"] * 1.5)
