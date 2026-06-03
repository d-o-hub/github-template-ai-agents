"""
Firecrawl provider implementation.
"""

import logging
import os

from scripts.constants import MAX_CHARS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache, is_safe_url

logger = logging.getLogger(__name__)


def resolve_with_firecrawl(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
    cached = _get_from_cache(url, "firecrawl")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("FIRECRAWL_API_KEY")
    if not api_key:
        logger.debug("Firecrawl skipped: no API key")
        return None
    from scripts.providers import _is_rate_limited, _set_rate_limit

    if _is_rate_limited("firecrawl"):
        logger.debug("Firecrawl skipped: rate limited")
        return None
    try:
        from firecrawl import Firecrawl

        app = Firecrawl(api_key=api_key)
        res = app.scrape(url, formats=["markdown"])
        if not res or not hasattr(res, "markdown"):
            logger.warning("Firecrawl returned no markdown for URL: %s", url)
            return None
        markdown = res.markdown
        if not markdown:
            logger.warning("Firecrawl returned empty markdown for URL: %s", url)
            return None
        result = ResolvedResult(source="firecrawl", content=markdown[:max_chars], url=url)
        _save_to_cache(url, "firecrawl", result.to_dict())
        return result
    except Exception as e:
        status = getattr(e, "status_code", None)
        if status == 401:
            logger.warning("Firecrawl failed: 401 Unauthorized — API key may be invalid or expired")
        elif status == 429:
            logger.warning("Firecrawl failed: 429 Rate limited — setting cooldown")
            _set_rate_limit("firecrawl")
        elif status == 403:
            logger.warning("Firecrawl failed: 403 Forbidden — %s", e)
        else:
            logger.warning("Firecrawl resolution failed: %s: %s", type(e).__name__, e)
        return None
