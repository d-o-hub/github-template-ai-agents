"""
Visual CLIP provider implementation.
"""

import logging
import os

from scripts.constants import MAX_CHARS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache, is_safe_url
from scripts.visual_resolver import VisualResolver

logger = logging.getLogger(__name__)

_visual_resolver: "VisualResolver | None" = None


def get_visual_resolver() -> VisualResolver:
    """Lazy initialization of the VisualResolver."""
    global _visual_resolver
    if _visual_resolver is None:
        _visual_resolver = VisualResolver()
    return _visual_resolver


def _is_api_available() -> bool:
    """Check if required API keys for VLM are present."""
    return bool(os.getenv("MISTRAL_API_KEY") or os.getenv("OPENROUTER_API_KEY"))


def resolve_with_visual_clip(
    url: str, max_chars: int = MAX_CHARS, query: str | None = None
) -> ResolvedResult | None:
    """
    Resolve a URL using the Visual CLIP resolver (sync).
    """
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None

    if not _is_api_available():
        logger.debug("Visual CLIP skipped: no API key")
        return None

    resolver = get_visual_resolver()
    if not resolver.is_available():
        logger.debug("Visual CLIP skipped: dependencies missing or disabled")
        return None

    cached = _get_from_cache(url, "visual_clip")
    if cached:
        return ResolvedResult(**cached)

    effective_query = query or "Extract the main content of this page."

    try:
        res = resolver.resolve(url, effective_query)
        if not res or res.content is None:
            return None

        result = ResolvedResult(
            source="visual_clip",
            content=res.content[:max_chars],
            url=url,
            query=effective_query,
            score=res.score,
            metadata=res.metadata,
        )
        _save_to_cache(url, "visual_clip", result.to_dict())
        return result
    except Exception as e:
        logger.warning("Visual CLIP resolution failed: %s", e)
        return None


async def resolve_with_visual_clip_async(
    url: str, max_chars: int = MAX_CHARS, query: str | None = None
) -> ResolvedResult | None:
    """
    Resolve a URL using the Visual CLIP resolver (async).
    """
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None

    if not _is_api_available():
        logger.debug("Visual CLIP skipped: no API key")
        return None

    resolver = get_visual_resolver()
    if not resolver.is_available():
        logger.debug("Visual CLIP skipped: dependencies missing or disabled")
        return None

    cached = _get_from_cache(url, "visual_clip")
    if cached:
        return ResolvedResult(**cached)

    effective_query = query or "Extract the main content of this page."

    try:
        res = await resolver.resolve_async(url, effective_query)
        if not res or res.content is None:
            return None

        result = ResolvedResult(
            source="visual_clip",
            content=res.content[:max_chars],
            url=url,
            query=effective_query,
            score=res.score,
            metadata=res.metadata,
        )
        _save_to_cache(url, "visual_clip", result.to_dict())
        return result
    except Exception as e:
        logger.warning("Visual CLIP resolution failed: %s", e)
        return None
