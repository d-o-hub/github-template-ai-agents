"""
Cache utilities for the Web Doc Resolver.
"""

import hashlib
import logging
import os
import threading
from typing import Any

from scripts.constants import CACHE_DIR, TIERED_TTL

logger = logging.getLogger(__name__)

_cache = None
_cache_lock = threading.RLock()


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
    from scripts.utils import _get_cache

    with _cache_lock:
        cache = _get_cache()
    if not cache:
        return None
    with _cache_lock:
        result = cache.get(_cache_key(input_str, source))
    if result is None:
        return None
    return dict(result)


def _save_to_cache(input_str: str, source: str, result: dict[str, Any], ttl: int | None = None):
    from scripts.utils import _get_cache

    with _cache_lock:
        cache = _get_cache()
    if not cache:
        return

    if ttl is None:
        ttl = get_ttl(source)

    with _cache_lock:
        cache.set(_cache_key(input_str, source), result, expire=ttl)
