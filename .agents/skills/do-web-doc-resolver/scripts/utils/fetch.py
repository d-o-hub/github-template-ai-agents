"""
Fetch utilities for the Web Doc Resolver.
"""

import logging
from typing import cast
from urllib.parse import urlparse

from scripts.constants import CLEAN_CONTENT, DEFAULT_TIMEOUT, MAX_CHARS
from scripts.models import ResolvedResult

logger = logging.getLogger(__name__)


def fetch_url_content(
    url: str, timeout: int = DEFAULT_TIMEOUT, max_chars: int = MAX_CHARS
) -> ResolvedResult | None:
    from scripts.utils import _safe_request, get_session, validate_url

    validation = validate_url(url, timeout=timeout // 2)
    if not validation.is_valid:
        return None
    try:
        session = get_session()
        response = _safe_request("GET", url, session=session, timeout=timeout, verify=True)
        if response.status_code >= 400:
            # Check for bot challenge even on error status codes (e.g., 403 Forbidden)
            from scripts.quality import is_bot_challenge

            if is_bot_challenge(response.text):
                raise ValueError(f"Bot challenge detected (HTTP {response.status_code})")
            return None
        raw_html = response.text

        from scripts.quality import is_bot_challenge

        if is_bot_challenge(raw_html):
            raise ValueError("Bot challenge detected")

        is_html = "text/html" in response.headers.get("Content-Type", "")

        if is_html and CLEAN_CONTENT:
            from scripts.utils.content_clean import clean_content

            content = clean_content(raw_html, url=url, max_chars=max_chars)
        elif is_html:
            from scripts.utils import extract_text_from_html

            content = extract_text_from_html(raw_html, url)[:max_chars]
        else:
            content = raw_html[:max_chars]

        return ResolvedResult(
            source="direct_fetch",
            content=content,
            url=validation.final_url or url,
            metadata={
                "status_code": response.status_code,
                "cleaned": is_html and CLEAN_CONTENT,
                "raw_length": len(raw_html),
            },
        )
    except Exception as e:
        # Surface bot challenges to the cascade
        from scripts.models import ErrorType
        from scripts.utils import _detect_error_type

        if _detect_error_type(e) == ErrorType.BOT_CHALLENGE:
            raise

        logger.debug("Direct fetch failed: %s", url, exc_info=True)
        return None


def fetch_llms_txt(url: str) -> str | None:
    from scripts.utils import (
        _get_from_cache,
        _safe_request,
        _save_to_cache,
        get_session,
        get_ttl,
        is_safe_url,
    )

    try:
        if not is_safe_url(url):
            return None
        parsed = urlparse(url)
        base_url = f"{parsed.scheme}://{parsed.netloc}"
        llms_url = f"{base_url}/llms.txt"
        cached = _get_from_cache(base_url, "llms_txt")
        if cached is not None:
            if cached.get("found"):
                return str(cached.get("content", ""))
            return None
        session = get_session()
        response = _safe_request("GET", llms_url, session=session, timeout=10)
        if response.status_code == 200:
            content_type = response.headers.get("Content-Type", "")
            if "text" in content_type or "markdown" in content_type:
                _save_to_cache(
                    base_url,
                    "llms_txt",
                    {"found": True, "content": response.text},
                    ttl=get_ttl("llms_txt"),
                )
                return cast(str, response.text)
        _save_to_cache(base_url, "llms_txt", {"found": False}, ttl=get_ttl("llms_txt"))
    except Exception:
        logger.debug("llms.txt fetch failed: %s", url, exc_info=True)
    return None
