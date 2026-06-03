"""
Fetch utilities for the Web Doc Resolver.
"""

import logging
from typing import cast
from urllib.parse import urlparse

from scripts.constants import DEFAULT_TIMEOUT, MAX_CHARS
from scripts.models import ResolvedResult

logger = logging.getLogger(__name__)


def fetch_url_content(
    url: str, timeout: int = DEFAULT_TIMEOUT, max_chars: int = MAX_CHARS
) -> ResolvedResult | None:
    from scripts.utils import _safe_request, extract_text_from_html, get_session, validate_url

    validation = validate_url(url, timeout=timeout // 2)
    if not validation.is_valid:
        return None
    try:
        session = get_session()
        response = _safe_request("GET", url, session=session, timeout=timeout, verify=True)
        if response.status_code >= 400:
            return None
        content = (
            extract_text_from_html(response.text, url)
            if "text/html" in response.headers.get("Content-Type", "")
            else response.text
        )
        return ResolvedResult(
            source="direct_fetch",
            content=content[:max_chars],
            url=validation.final_url or url,
            metadata={"status_code": response.status_code},
        )
    except Exception:
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
