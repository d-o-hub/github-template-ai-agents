"""
Jina provider implementation.
"""

import logging

import requests

from scripts.constants import DEFAULT_TIMEOUT, MAX_CHARS, MIN_CHARS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache, get_session, is_safe_url

logger = logging.getLogger(__name__)


def resolve_with_jina(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
    cached = _get_from_cache(url, "jina")
    if cached:
        return ResolvedResult(**cached)
    from scripts.providers import _is_rate_limited, _set_rate_limit

    if _is_rate_limited("jina"):
        return None
    try:
        session = get_session()
        response = session.get(
            f"https://r.jina.ai/{url}",
            timeout=DEFAULT_TIMEOUT,
            headers={"Accept": "text/markdown"},
        )
        if response.status_code == 429:
            logger.warning("Jina rate limited — setting cooldown")
            _set_rate_limit("jina")
            return None
        if response.status_code in (401, 403):
            logger.warning("Jina auth error: HTTP %s for %s", response.status_code, url)
            return None
        if response.status_code != 200:
            logger.warning("Jina HTTP %s for %s", response.status_code, url)
            return None
        content = response.text.strip()
        if len(content) < MIN_CHARS:
            logger.warning(
                "Jina returned insufficient content (%s chars) for %s", len(content), url
            )
            return None
        result = ResolvedResult(source="jina", content=content[:max_chars], url=url)
        _save_to_cache(url, "jina", result.to_dict())
        return result
    except requests.RequestException as e:
        logger.warning("Jina resolution failed: %s: %s", type(e).__name__, e)
        return None
