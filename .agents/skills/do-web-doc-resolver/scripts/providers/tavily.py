"""
Tavily provider implementation.
"""

import logging
import os

from scripts.constants import MAX_CHARS, TAVILY_RESULTS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache

logger = logging.getLogger(__name__)


def resolve_with_tavily(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "tavily")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("TAVILY_API_KEY")
    if not api_key:
        logger.debug("Tavily skipped: no API key")
        return None
    from scripts.providers import _is_rate_limited, _set_rate_limit

    if _is_rate_limited("tavily"):
        logger.debug("Tavily skipped: rate limited")
        return None
    try:
        from tavily import TavilyClient

        client = TavilyClient(api_key=api_key)
        res = client.search(query, max_results=TAVILY_RESULTS)
        if not res or not res.get("results"):
            logger.warning("Tavily returned no results for query: %s", query)
            return None
        content = "\n\n---\n\n".join([f"## {r['title']}\n\n{r['content']}" for r in res["results"]])
        result = ResolvedResult(source="tavily", content=content[:max_chars], query=query)
        _save_to_cache(query, "tavily", result.to_dict())
        return result
    except Exception as e:
        status = getattr(e, "status_code", None)
        if status == 401:
            logger.warning("Tavily failed: 401 Unauthorized — API key may be invalid or expired")
        elif status == 429:
            logger.warning("Tavily failed: 429 Rate limited — setting cooldown")
            _set_rate_limit("tavily")
        elif status == 403:
            logger.warning("Tavily failed: 403 Forbidden — %s", e)
        else:
            logger.warning("Tavily resolution failed: %s: %s", type(e).__name__, e)
        return None
