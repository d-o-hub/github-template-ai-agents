"""
Serper provider implementation.
"""

import logging
import os

import requests

from scripts.constants import DEFAULT_TIMEOUT, MAX_CHARS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache, get_session

logger = logging.getLogger(__name__)


def resolve_with_serper(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    """Search via Serper (Google Search API). Free tier: 2500 credits."""
    cached = _get_from_cache(query, "serper")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("SERPER_API_KEY")
    if not api_key:
        logger.debug("Serper skipped: no API key")
        return None
    from scripts.providers import _is_rate_limited, _set_rate_limit

    if _is_rate_limited("serper"):
        logger.debug("Serper skipped: rate limited")
        return None
    try:
        session = get_session()
        response = session.post(
            "https://google.serper.dev/search",
            headers={
                "X-API-KEY": api_key,
                "Content-Type": "application/json",
            },
            json={"q": query, "num": 5},
            timeout=DEFAULT_TIMEOUT,
        )
        if response.status_code == 429:
            logger.warning("Serper rate limited — setting 1hr cooldown")
            _set_rate_limit("serper", 3600)
            return None
        if response.status_code in (401, 403):
            logger.warning(
                "Serper auth error: HTTP %s — API key may be invalid", response.status_code
            )
            return None
        if response.status_code != 200:
            logger.warning("Serper HTTP %s for query: %s", response.status_code, query)
            return None
        data = response.json()
        organic = data.get("organic", [])
        if not organic:
            logger.warning("Serper returned no organic results for query: %s", query)
            return None
        parts = []
        for r in organic:
            title = r.get("title", "")
            link = r.get("link", "")
            snippet = r.get("snippet", "")
            if title and snippet:
                parts.append(f"## {title}\n\n{snippet}\n\n[{link}]({link})")
        if not parts:
            logger.warning("Serper returned no usable snippets for query: %s", query)
            return None
        content = "\n\n---\n\n".join(parts)
        result = ResolvedResult(source="serper", content=content[:max_chars], query=query)
        _save_to_cache(query, "serper", result.to_dict())
        return result
    except requests.RequestException as e:
        logger.warning("Serper resolution failed: %s: %s", type(e).__name__, e)
        return None
