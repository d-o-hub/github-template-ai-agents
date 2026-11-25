"""
Provider decorator for the Web Doc Resolver.
"""

import functools
import logging
import os
from collections.abc import Callable

from scripts.models import ResolvedResult

logger = logging.getLogger(__name__)


def provider(
    name: str,
    env_key: str | None = None,
    rate_limit_key: str | None = None,
    check_ssrf: bool = False,
):
    """
    Decorator that centralizes common provider patterns:
    - Cache lookup
    - Rate limit check
    - API key check (optional)
    - Standardized error handling

    Args:
        name: Provider name for cache and logging
        env_key: Environment variable name for API key (optional)
        rate_limit_key: Rate limit key (defaults to name)
        check_ssrf: Whether to check SSRF for URL inputs
    """

    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs) -> ResolvedResult | None:
            # Import rate limit functions lazily to avoid circular imports
            from scripts.providers_impl import _is_rate_limited, _set_rate_limit
            from scripts.utils import _get_from_cache, _save_to_cache, is_safe_url

            # Get the input (first argument)
            input_val = args[0] if args else kwargs.get("input")

            # SSRF check if needed
            if check_ssrf and input_val and not is_safe_url(input_val):
                logger.warning("SSRF blocked: %s", input_val)
                return None

            # Cache lookup
            if input_val:
                cached = _get_from_cache(input_val, name)
                if cached:
                    return ResolvedResult(**cached)

            # API key check if needed
            if env_key:
                api_key = os.getenv(env_key)
                if not api_key:
                    logger.debug("%s skipped: no API key", name)
                    return None

            # Rate limit check
            rl_key = rate_limit_key or name
            if _is_rate_limited(rl_key):
                logger.debug("%s skipped: rate limited", name)
                return None

            # Call the actual provider function
            try:
                result: ResolvedResult | None = func(*args, **kwargs)
                if result and input_val:
                    # Save to cache
                    _save_to_cache(input_val, name, result.to_dict())
                return result
            except Exception as e:
                # Standardized error handling
                status = getattr(e, "status_code", None)
                if status == 401:
                    logger.warning(
                        "%s failed: 401 Unauthorized — API key may be invalid or expired", name
                    )
                elif status == 429:
                    logger.warning("%s failed: 429 Rate limited — setting cooldown", name)
                    _set_rate_limit(rl_key)
                elif status == 403:
                    logger.warning("%s failed: 403 Forbidden — %s", name, e)
                else:
                    logger.warning("%s resolution failed: %s: %s", name, type(e).__name__, e)
                return None

        return wrapper

    return decorator
