"""
DuckDuckGo provider implementation.
"""

import logging

from scripts.constants import DDG_RESULTS, MAX_CHARS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache

logger = logging.getLogger(__name__)


def resolve_with_duckduckgo(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "duckduckgo")
    if cached:
        return ResolvedResult(**cached)
    from scripts.providers_impl import _is_rate_limited

    if _is_rate_limited("duckduckgo"):
        logger.debug("DuckDuckGo skipped: rate limited")
        return None
    try:
        from ddgs import DDGS

        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=DDG_RESULTS))
        if not results:
            logger.warning("DuckDuckGo returned no results for query: %s", query)
            return None
        content = "\n\n---\n\n".join(
            [f"## {r.get('title', '')}\n\n{r.get('body', '')}" for r in results]
        )
        result = ResolvedResult(source="duckduckgo", content=content[:max_chars], query=query)
        _save_to_cache(query, "duckduckgo", result.to_dict())
        return result
    except Exception as e:
        logger.warning("DuckDuckGo resolution failed: %s: %s", type(e).__name__, e)
        return None
