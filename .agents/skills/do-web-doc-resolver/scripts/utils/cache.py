"""
Cache utilities for the Web Doc Resolver.
"""

import hashlib
import logging
import os
import threading
import time
from typing import Any

from scripts.constants import CACHE_DIR, TIERED_TTL

logger = logging.getLogger(__name__)

_cache = None
_cache_lock = threading.RLock()

# L1 in-memory cache: fast TTL cache sitting in front of disk cache
_l1_cache: dict[str, tuple[Any, float]] = {}
_l1_cache_lock = threading.RLock()
L1_CACHE_MAX_SIZE = 1000
L1_CACHE_DEFAULT_TTL = 300  # 5 minutes





def _l1_get(key: str) -> Any | None:
    """Get from L1 in-memory cache."""
    with _l1_cache_lock:
        entry = _l1_cache.get(key)
        if entry is None:
            return None
        value, expire_time = entry
        if time.time() > expire_time:
            del _l1_cache[key]
            return None
        return value


def _l1_set(key: str, value: Any, ttl: int = L1_CACHE_DEFAULT_TTL) -> None:
    """Set in L1 in-memory cache with TTL."""
    with _l1_cache_lock:
        # Evict oldest entries if at capacity
        if len(_l1_cache) >= L1_CACHE_MAX_SIZE:
            # Remove 10% of oldest entries
            evict_count = max(1, L1_CACHE_MAX_SIZE // 10)
            to_evict = sorted(_l1_cache.keys(), key=lambda k: _l1_cache[k][1])[:evict_count]
            for k in to_evict:
                del _l1_cache[k]
        _l1_cache[key] = (value, time.time() + ttl)


def _l1_clear() -> None:
    """Clear L1 in-memory cache."""
    with _l1_cache_lock:
        _l1_cache.clear()



def _cache_key(input_str: str, source: str) -> str:
    from scripts.utils.urls import is_url, normalize_query, normalize_url

    # Use normalized input for cache key
    if is_url(input_str):
        normalized = normalize_url(input_str)
    else:
        normalized = normalize_query(input_str)

    hash_input = f"{source}:{normalized}"
    return hashlib.sha256(hash_input.encode()).hexdigest()


def _get_cache_proxy():
    import scripts.resolve

    if hasattr(scripts.resolve, "_cache") and scripts.resolve._cache is not None:
        return scripts.resolve._cache
    return _cache


def get_cache():
    try:
        import diskcache

        os.makedirs(CACHE_DIR, exist_ok=True)
        return diskcache.Cache(CACHE_DIR)
    except Exception:
        logger.debug("Failed to initialize diskcache", exc_info=True)
        return None


def _get_cache():
    global _cache
    with _cache_lock:
        _cache = _get_cache_proxy()
        if _cache is None:
            _cache = get_cache()
    return _cache


def get_ttl(provider: str, config: dict | None = None) -> int:
    """Get the TTL for a given provider from config or defaults."""
    from scripts.utils import get_config_data

    # Normalize provider name for alias support
    provider_key = provider
    if provider in ("exa_mcp", "exa"):
        provider_key = "exa"
    elif provider in ("mistral_browser", "mistral_websearch"):
        provider_key = "mistral"

    # Use provided config or load from file
    cfg = config if config is not None else get_config_data()

    # Environment variable override takes precedence over file-based config
    env_key = f"DO_WDR_CACHE_TTL_{provider_key.upper()}"
    if env_key in os.environ:
        try:
            return int(os.environ[env_key])
        except ValueError:
            pass

    if cfg:
        # Try to get from nested config.toml style
        ttl_cfg = cfg.get("cache", {}).get("ttl", {})
        if provider_key in ttl_cfg:
            return int(ttl_cfg[provider_key])
        if "default" in ttl_cfg:
            return int(ttl_cfg["default"])

    return TIERED_TTL.get(provider_key, TIERED_TTL.get("default", 3600))


def _get_from_cache(input_str: str, source: str) -> dict[str, Any] | None:
    key = _cache_key(input_str, source)

    # Check L1 in-memory cache first (fast path)
    result = _l1_get(key)
    if result is not None:
        return dict(result)

    # Check disk cache (slow path)
    from scripts.utils import _get_cache

    with _cache_lock:
        cache = _get_cache()
    if not cache:
        return None
    with _cache_lock:
        result = cache.get(key)
    if result is None:
        return None

    # Promote to L1 cache for faster subsequent access
    _l1_set(key, result, ttl=min(get_ttl(source), L1_CACHE_DEFAULT_TTL))
    return dict(result)


def _save_to_cache(input_str: str, source: str, result: dict[str, Any], ttl: int | None = None):
    from scripts.utils import _get_cache

    if ttl is None:
        ttl = get_ttl(source)

    key = _cache_key(input_str, source)

    # Store in L1 in-memory cache
    _l1_set(key, result, ttl=min(ttl, L1_CACHE_DEFAULT_TTL))

    # Store in disk cache
    with _cache_lock:
        cache = _get_cache()
    if not cache:
        return

    with _cache_lock:
        cache.set(key, result, expire=ttl)
