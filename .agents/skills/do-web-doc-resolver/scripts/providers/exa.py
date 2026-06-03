"""
Exa provider implementation.
"""

import json
import logging
import os

import requests

from scripts.constants import EXA_RESULTS, MAX_CHARS
from scripts.models import ResolvedResult
from scripts.utils import _get_from_cache, _save_to_cache, get_session

logger = logging.getLogger(__name__)


def resolve_with_exa_mcp(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "exa_mcp")
    if cached:
        return ResolvedResult(**cached)
    from scripts.providers import _is_rate_limited

    if _is_rate_limited("exa_mcp"):
        return None
    try:
        mcp_request = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": {"name": "web_search_exa", "arguments": {"query": query, "numResults": 8}},
        }
        session = get_session()
        response = session.post(
            "https://mcp.exa.ai/mcp",
            json=mcp_request,
            headers={"Accept": "application/json, text/event-stream"},
            timeout=25,
        )
        if response.status_code != 200:
            logger.warning("Exa MCP HTTP %s for query: %s", response.status_code, query)
            return None
        for line in response.text.split("\n"):
            if line.startswith("data: "):
                data = json.loads(line[6:])
                if data.get("result") and data["result"].get("content"):
                    content = data["result"]["content"][0].get("text", "")
                    if not content:
                        logger.warning("Exa MCP returned empty content for query: %s", query)
                        return None
                    result = ResolvedResult(
                        source="exa_mcp", content=content[:max_chars], query=query
                    )
                    _save_to_cache(query, "exa_mcp", result.to_dict())
                    return result
        logger.warning("Exa MCP returned no usable content for query: %s", query)
    except json.JSONDecodeError as e:
        logger.warning("Exa MCP JSON parse failed: %s", e)
    except requests.RequestException as e:
        logger.warning("Exa MCP resolution failed: %s: %s", type(e).__name__, e)
    return None


def resolve_with_exa(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "exa")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("EXA_API_KEY")
    if not api_key:
        logger.debug("Exa skipped: no API key")
        return None
    from scripts.providers import _is_rate_limited, _set_rate_limit

    if _is_rate_limited("exa"):
        logger.debug("Exa skipped: rate limited")
        return None
    try:
        from exa_py import Exa

        client = Exa(api_key)
        res = client.search_and_contents(
            query, use_autoprompt=True, highlights=True, num_results=EXA_RESULTS
        )
        if not res or not res.results:
            logger.warning("Exa returned no results for query: %s", query)
            return None
        content = "\n\n---\n\n".join(
            [
                r.highlight or r.text
                for r in res.results
                if hasattr(r, "highlight") and r.highlight or hasattr(r, "text") and r.text
            ]
        )
        if not content:
            logger.warning("Exa returned empty content for query: %s", query)
            return None
        result = ResolvedResult(source="exa", content=content[:max_chars], query=query)
        _save_to_cache(query, "exa", result.to_dict())
        return result
    except Exception as e:
        status = getattr(e, "status_code", None)
        if status == 401:
            logger.warning("Exa failed: 401 Unauthorized — API key may be invalid or expired")
        elif status == 429:
            logger.warning("Exa failed: 429 Rate limited — setting cooldown")
            _set_rate_limit("exa")
        elif status == 403:
            logger.warning("Exa failed: 403 Forbidden — %s", e)
        else:
            logger.warning("Exa resolution failed: %s: %s", type(e).__name__, e)
        return None
