"""
Individual provider implementations for the Web Doc Resolver.
"""

import json
import logging
import os
import subprocess
import time

from .models import ResolvedResult
from .utils import (
    _get_from_cache,
    _save_to_cache,
    get_session,
)

logger = logging.getLogger(__name__)

MAX_CHARS = int(os.getenv("WEB_RESOLVER_MAX_CHARS", "8000"))
MIN_CHARS = int(os.getenv("WEB_RESOLVER_MIN_CHARS", "200"))
DEFAULT_TIMEOUT = int(os.getenv("WEB_RESOLVER_TIMEOUT", "30"))
EXA_RESULTS = int(os.getenv("WEB_RESOLVER_EXA_RESULTS", "5"))
TAVILY_RESULTS = int(os.getenv("WEB_RESOLVER_TAVILY_RESULTS", "5"))
DDG_RESULTS = int(os.getenv("WEB_RESOLVER_DDG_RESULTS", "5"))

_rate_limits: dict[str, float] = {}


def _is_rate_limited(provider: str) -> bool:
    if provider in _rate_limits:
        if time.time() < _rate_limits[provider]:
            return True
        del _rate_limits[provider]
    return False


def _set_rate_limit(provider: str, cooldown: int = 60):
    _rate_limits[provider] = time.time() + cooldown


# Exported names for both internal use and tests
is_rate_limited = _is_rate_limited
set_rate_limit = _set_rate_limit


def resolve_with_jina(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(url, "jina")
    if cached:
        return ResolvedResult(**cached)
    if _is_rate_limited("jina"):
        return None
    try:
        session = get_session()
        response = session.get(
            f"https://r.jina.ai/{url}", timeout=DEFAULT_TIMEOUT, headers={"Accept": "text/markdown"}
        )
        if response.status_code == 429:
            _set_rate_limit("jina")
            return None
        if response.status_code != 200:
            return None
        content = response.text.strip()
        if len(content) < MIN_CHARS:
            return None
        result = ResolvedResult(source="jina", content=content[:max_chars], url=url)
        _save_to_cache(url, "jina", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_exa_mcp(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "exa_mcp")
    if cached:
        return ResolvedResult(**cached)
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
        response = session.post("https://mcp.exa.ai/mcp", json=mcp_request, timeout=25)
        if response.status_code != 200:
            return None
        for line in response.text.split("\n"):
            if line.startswith("data: "):
                data = json.loads(line[6:])
                if data.get("result") and data["result"].get("content"):
                    content = data["result"]["content"][0].get("text", "")
                    result = ResolvedResult(
                        source="exa_mcp", content=content[:max_chars], query=query
                    )
                    _save_to_cache(query, "exa_mcp", result.to_dict())
                    return result
    except Exception:
        return None
    return None


def resolve_with_exa(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "exa")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("EXA_API_KEY")
    if not api_key or _is_rate_limited("exa"):
        return None
    try:
        from exa_py import Exa

        client = Exa(api_key)
        res = client.search_and_contents(
            query, use_autoprompt=True, highlights=True, num_results=EXA_RESULTS
        )
        if not res or not res.results:
            return None
        content = "\n\n---\n\n".join(
            [
                r.highlight or r.text
                for r in res.results
                if hasattr(r, "highlight") and r.highlight or hasattr(r, "text") and r.text
            ]
        )
        result = ResolvedResult(source="exa", content=content[:max_chars], query=query)
        _save_to_cache(query, "exa", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_tavily(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "tavily")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("TAVILY_API_KEY")
    if not api_key or _is_rate_limited("tavily"):
        return None
    try:
        from tavily import TavilyClient

        client = TavilyClient(api_key=api_key)
        res = client.search(query, max_results=TAVILY_RESULTS)
        if not res or not res.get("results"):
            return None
        content = "\n\n---\n\n".join([f"## {r['title']}\n\n{r['content']}" for r in res["results"]])
        result = ResolvedResult(source="tavily", content=content[:max_chars], query=query)
        _save_to_cache(query, "tavily", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_duckduckgo(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "duckduckgo")
    if cached:
        return ResolvedResult(**cached)
    if _is_rate_limited("duckduckgo"):
        return None
    try:
        from duckduckgo_search import DDGS

        with DDGS() as ddgs:
            results = list(ddgs.text(query, max_results=DDG_RESULTS))
        if not results:
            return None
        content = "\n\n---\n\n".join(
            [f"## {r.get('title','')}\n\n{r.get('body','')}" for r in results]
        )
        result = ResolvedResult(source="duckduckgo", content=content[:max_chars], query=query)
        _save_to_cache(query, "duckduckgo", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_firecrawl(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(url, "firecrawl")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("FIRECRAWL_API_KEY")
    if not api_key or _is_rate_limited("firecrawl"):
        return None
    try:
        from firecrawl import Firecrawl

        app = Firecrawl(api_key=api_key)
        res = app.scrape(url, formats=["markdown"])
        markdown = res.markdown if res and hasattr(res, "markdown") else ""
        result = ResolvedResult(source="firecrawl", content=markdown[:max_chars], url=url)
        _save_to_cache(url, "firecrawl", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_mistral_browser(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(url, "mistral_browser")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("MISTRAL_API_KEY")
    if not api_key or _is_rate_limited("mistral"):
        return None
    try:
        from mistralai.client import Mistral
        from mistralai.client.models import UserMessage, WebSearchTool

        client = Mistral(api_key=api_key)
        resp = client.beta.conversations.start(
            inputs=UserMessage(content=f"Extract URL: {url}"), tools=[WebSearchTool()]
        )
        content = resp.outputs[0].content if resp.outputs else ""
        result = ResolvedResult(source="mistral-browser", content=content[:max_chars], url=url)
        _save_to_cache(url, "mistral_browser", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_mistral_websearch(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    cached = _get_from_cache(query, "mistral_websearch")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("MISTRAL_API_KEY")
    if not api_key or _is_rate_limited("mistral"):
        return None
    try:
        from mistralai.client import Mistral
        from mistralai.client.models import UserMessage

        client = Mistral(api_key=api_key)
        resp = client.chat.complete(
            model="mistral-small-latest", messages=[UserMessage(content=f"Search: {query}")]
        )
        content = resp.choices[0].message.content if resp.choices else ""
        result = ResolvedResult(
            source="mistral-websearch", content=content[:max_chars], query=query
        )
        _save_to_cache(query, "mistral_websearch", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_docling(url: str, max_chars: int) -> ResolvedResult | None:
    try:
        res = subprocess.run(
            ["docling", "--format", "markdown", url], capture_output=True, text=True, timeout=60
        )
        if res.returncode == 0:
            return ResolvedResult(source="docling", content=res.stdout[:max_chars], url=url)
    except Exception:
        pass
    return None


def resolve_with_ocr(url: str, max_chars: int) -> ResolvedResult | None:
    try:
        res = subprocess.run(
            ["tesseract", url, "stdout"], capture_output=True, text=True, timeout=30
        )
        if res.returncode == 0:
            return ResolvedResult(source="ocr-tesseract", content=res.stdout[:max_chars], url=url)
    except Exception:
        pass
    return None
