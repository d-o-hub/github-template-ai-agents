"""
Utility package for the Web Doc Resolver.
"""

import logging
import os
import typing
from typing import Any

from scripts.utils.cache import (
    _cache_key,
    _get_cache,
    _get_from_cache,
    _save_to_cache,
    get_cache,
    get_ttl,
)
from scripts.utils.fetch import (
    fetch_llms_txt,
    fetch_url_content,
)
from scripts.utils.html import (
    EnhancedHTMLParser,
    compact_content,
    extract_text_from_html,
)
from scripts.utils.http import (
    _safe_request,
    close_session,
    create_session_with_retry,
    get_session,
    is_safe_url,
    validate_links,
    validate_url,
)
from scripts.utils.urls import (
    is_url,
    normalize_query,
    normalize_url,
    score_result,
)

logger = logging.getLogger(__name__)

_CONFIG_DATA: dict[str, Any] | None = None


def get_config_data() -> dict[str, Any]:
    """Load configuration from config.toml if available."""
    global _CONFIG_DATA
    if _CONFIG_DATA is not None:
        return _CONFIG_DATA

    _CONFIG_DATA = {}
    config_path = os.getenv("DO_WDR_CONFIG") or "config.toml"
    if os.path.exists(config_path):
        try:
            try:
                import tomllib
            except ImportError:
                import tomli as tomllib  # type: ignore

            with open(config_path, "rb") as f:
                _CONFIG_DATA = typing.cast(dict[str, Any], tomllib.load(f))
        except Exception as e:
            logger.debug(f"Failed to load config.toml: {e}")

    return _CONFIG_DATA


def _detect_error_type(error: Exception):
    from scripts.models import ErrorType

    error_msg = str(error).lower()
    if any(code in error_msg for code in ["429", "rate limit", "too many requests", "rate_limit"]):
        return ErrorType.RATE_LIMIT
    if any(
        code in error_msg
        for code in [
            "401",
            "403",
            "unauthorized",
            "forbidden",
            "invalid api key",
            "invalid_key",
            "authentication",
        ]
    ):
        return ErrorType.AUTH_ERROR
    if any(
        code in error_msg
        for code in [
            "402",
            "payment",
            "credit",
            "quota",
            "insufficient",
            "exhausted",
            "limit exceeded",
        ]
    ):
        return ErrorType.QUOTA_EXHAUSTED
    if any(code in error_msg for code in ["timeout", "timed out"]):
        return ErrorType.TIMEOUT
    if any(code in error_msg for code in ["connection", "network"]):
        return ErrorType.NETWORK_ERROR
    if any(code in error_msg for code in ["not found", "404"]):
        return ErrorType.NOT_FOUND
    if any(code in error_msg for code in ["ssrf", "blocked", "private ip", "localhost"]):
        return ErrorType.SSRF_BLOCKED
    if any(code in error_msg for code in ["too large", "content size", "exceeds"]):
        return ErrorType.CONTENT_TOO_LARGE
    return ErrorType.UNKNOWN


__all__ = [
    # Config
    "get_config_data",
    # HTTP utilities
    "create_session_with_retry",
    "get_session",
    "close_session",
    "_safe_request",
    "is_safe_url",
    "validate_url",
    "validate_links",
    # HTML utilities
    "EnhancedHTMLParser",
    "extract_text_from_html",
    "compact_content",
    # Cache utilities
    "_cache_key",
    "_get_cache",
    "_get_from_cache",
    "_save_to_cache",
    "get_cache",
    "get_ttl",
    # URL utilities
    "is_url",
    "normalize_url",
    "normalize_query",
    "score_result",
    # Error utilities
    "_detect_error_type",
    # Fetch utilities
    "fetch_url_content",
    "fetch_llms_txt",
]
