"""
Mistral provider implementation.
"""

import logging
import os

from scripts.constants import MAX_CHARS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache, is_safe_url

logger = logging.getLogger(__name__)


def resolve_with_mistral_browser(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
    cached = _get_from_cache(url, "mistral_browser")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("MISTRAL_API_KEY")
    if not api_key:
        logger.debug("Mistral browser skipped: no API key")
        return None
    from scripts.providers import _is_rate_limited, _set_rate_limit

    if _is_rate_limited("mistral"):
        logger.debug("Mistral browser skipped: rate limited")
        return None
    try:
        from mistralai.client import Mistral

        client = Mistral(api_key=api_key)

        # Create an agent with web_search tool
        agent = client.beta.agents.create(
            model="mistral-small-latest",
            name="url-extractor",
            instructions="Extract and summarize content from web pages. Return clean markdown.",
            tools=[{"type": "web_search"}],  # type: ignore[arg-type]
        )

        try:
            # Start conversation to extract the URL
            result = client.beta.conversations.start(
                agent_id=agent.id,
                inputs=f"Extract the main content from this URL and return it as markdown: {url}",
            )

            content = ""
            for entry in result.outputs:
                if hasattr(entry, "content") and entry.content is not None:
                    # In newer mistralai, content might be a list of chunks
                    if isinstance(entry.content, str):
                        content += entry.content
                    elif isinstance(entry.content, list):
                        for chunk in entry.content:
                            if hasattr(chunk, "text") and chunk.text:
                                content += chunk.text
                            elif isinstance(chunk, str):
                                content += chunk

            if not content:
                logger.warning("Mistral browser returned empty content for URL: %s", url)
                return None

            resolved = ResolvedResult(
                source="mistral-browser", content=content[:max_chars], url=url
            )
            _save_to_cache(url, "mistral_browser", resolved.to_dict())
            return resolved
        finally:
            # Clean up the agent
            try:
                client.beta.agents.delete(agent_id=agent.id)
            except Exception as e:
                logger.warning("Mistral browser agent cleanup failed: %s", e)
    except Exception as e:
        status = getattr(e, "status_code", None)
        if status == 401:
            logger.warning(
                "Mistral browser failed: 401 Unauthorized — API key may be invalid or expired"
            )
        elif status == 429:
            logger.warning("Mistral browser failed: 429 Rate limited — setting cooldown")
            _set_rate_limit("mistral")
        elif status == 403:
            logger.warning("Mistral browser failed: 403 Forbidden — %s", e)
        else:
            logger.warning("Mistral browser failed: %s: %s", type(e).__name__, e)
        return None


def resolve_with_mistral_websearch(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "mistral_websearch")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("MISTRAL_API_KEY")
    if not api_key:
        logger.debug("Mistral websearch skipped: no API key")
        return None
    from scripts.providers import _is_rate_limited, _set_rate_limit

    if _is_rate_limited("mistral"):
        logger.debug("Mistral websearch skipped: rate limited")
        return None
    try:
        from mistralai.client import Mistral
        from mistralai.client.models import UserMessage

        client = Mistral(api_key=api_key)
        resp = client.chat.complete(
            model="mistral-small-latest",
            messages=[UserMessage(content=f"Search: {query}")],  # type: ignore[arg-type]
        )
        content = ""
        if resp.choices and resp.choices[0].message and resp.choices[0].message.content:
            msg_content = resp.choices[0].message.content
            if isinstance(msg_content, str):
                content = msg_content
            elif isinstance(msg_content, list):
                # Handle list of chunks if necessary
                for chunk in msg_content:
                    if hasattr(chunk, "text") and chunk.text:
                        content += chunk.text
                    elif isinstance(chunk, str):
                        content += chunk
        if not content:
            logger.warning("Mistral websearch returned empty content for query: %s", query)
            return None
        result = ResolvedResult(
            source="mistral-websearch", content=content[:max_chars], query=query
        )
        _save_to_cache(query, "mistral_websearch", result.to_dict())
        return result
    except Exception as e:
        status = getattr(e, "status_code", None)
        if status == 401:
            logger.warning(
                "Mistral websearch failed: 401 Unauthorized — API key may be invalid or expired"
            )
        elif status == 429:
            logger.warning("Mistral websearch failed: 429 Rate limited — setting cooldown")
            _set_rate_limit("mistral")
        elif status == 403:
            logger.warning("Mistral websearch failed: 403 Forbidden — %s", e)
        else:
            logger.warning("Mistral websearch failed: %s: %s", type(e).__name__, e)
        return None
