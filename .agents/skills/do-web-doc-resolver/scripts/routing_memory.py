"""
Per-domain routing memory for the Web Doc Resolver.
"""

import json
import logging
import math
import os
import threading
import time
from collections import defaultdict
from pathlib import Path
from typing import Any, cast

from scripts._routing_utils import DEFAULT_PROVIDER_STATS, compute_p75_latency

logger = logging.getLogger(__name__)
SCORE_BASE = 0.5
RECENCY_DECAY_DAYS = 7.0
SCORE_SCALE = 1000.0

# Minimum seconds between disk writes; bounds I/O while retaining durability.
SAVE_INTERVAL_SECONDS = 5.0


class RoutingMemory:
    def __init__(self, path: str | os.PathLike[str] | None = None) -> None:
        # domain -> provider -> stats
        self.domain_stats: dict[str, dict[str, dict[str, Any]]] = defaultdict(
            lambda: defaultdict(lambda: dict(DEFAULT_PROVIDER_STATS))
        )
        self._lock = threading.RLock()
        self._path = Path(path) if path is not None else None
        self._dirty = False
        self._last_save = 0.0
        if self._path is not None:
            self._load_from_disk()

    # --- Persistence -------------------------------------------------------

    def _load_from_disk(self) -> None:
        if self._path is None or not self._path.exists():
            return
        try:
            with self._path.open("r", encoding="utf-8") as fh:
                raw = json.load(fh)
            for domain, providers in raw.items():
                for provider, stats in providers.items():
                    # Sanitize each entry against the default shape so corrupt or
                    # partial files degrade gracefully instead of crashing rank().
                    merged = dict(DEFAULT_PROVIDER_STATS)
                    if isinstance(stats, dict):
                        merged.update(
                            {k: v for k, v in stats.items() if k in merged and v is not None}
                        )
                    self.domain_stats[str(domain)][str(provider)] = merged
            logger.debug("Loaded routing memory from %s", self._path)
        except (OSError, ValueError, TypeError) as e:
            logger.warning("Failed to load routing memory from %s: %s", self._path, e)

    def _save_to_disk_unlocked(self) -> None:
        if self._path is None:
            return
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            data = {d: dict(ps) for d, ps in self.domain_stats.items()}
            tmp = self._path.with_suffix(self._path.suffix + ".tmp")
            with tmp.open("w", encoding="utf-8") as fh:
                json.dump(data, fh, sort_keys=True)
            tmp.replace(self._path)
            self._dirty = False
            self._last_save = time.time()
        except OSError as e:
            logger.warning("Failed to save routing memory to %s: %s", self._path, e)

    def save(self) -> None:
        """Flush routing memory to disk (no-op when no path is configured)."""
        with self._lock:
            self._save_to_disk_unlocked()

    def record(
        self, domain: str, provider: str, success: bool, latency_ms: int, quality_score: float
    ) -> None:
        with self._lock:
            stats = self.domain_stats[domain][provider]
            s = cast(int, stats.get("success", 0))
            f = cast(int, stats.get("failure", 0))
            total = s + f

            avg_lat = cast(float, stats.get("avg_latency_ms", 0.0))
            avg_qual = cast(float, stats.get("avg_quality", 0.0))

            stats["avg_latency_ms"] = ((avg_lat * total) + float(latency_ms)) / (total + 1)
            stats["avg_quality"] = ((avg_qual * total) + float(quality_score)) / (total + 1)
            stats["last_attempted"] = time.time()
            if success:
                stats["success"] = s + 1
            else:
                stats["failure"] = f + 1

            # Throttled auto-persist so a running CLI retains learned preferences.
            if self._path is not None and (
                self._dirty is False or time.time() - self._last_save >= SAVE_INTERVAL_SECONDS
            ):
                self._dirty = True
                self._save_to_disk_unlocked()

    def get_domain_stats(self, provider: str, domain: str) -> dict[str, Any] | None:
        with self._lock:
            domain_dict = self.domain_stats.get(domain)
            if not domain_dict:
                return None
            stats = domain_dict.get(provider)
            if not stats:
                return None

            s = cast(int, stats.get("success", 0))
            f = cast(int, stats.get("failure", 0))
            attempts = s + f
            if attempts == 0:
                return None

            success_rate = float(s) / max(attempts, 1)
            days_since_last = 0.0
            last = cast(float | None, stats.get("last_attempted"))
            if last:
                days_since_last = (time.time() - last) / 86400.0

            return {
                "attempts": attempts,
                "success_rate": success_rate,
                "avg_latency_ms": stats.get("avg_latency_ms", 0.0),
                "avg_quality": stats.get("avg_quality", 0.5),
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
            domain_dict = self.domain_stats.get(domain)
            if not domain_dict:
                return default
            stats = domain_dict.get(provider)
            if not stats:
                return default
            return compute_p75_latency(cast(float, stats["avg_latency_ms"]), default)

    def clear(self) -> None:
        with self._lock:
            self.domain_stats.clear()
            self._dirty = False
