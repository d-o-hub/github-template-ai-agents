"""
Individual provider implementations for the Web Doc Resolver.
"""

import json
import logging
import os
import subprocess
import threading
import time

from scripts.models import ResolvedResult
from scripts.utils import (
    _get_from_cache,
    _save_to_cache,
    get_config_data,
    get_session,
    is_safe_url,
)

logger = logging.getLogger(__name__)

# Load from config or env
_config = get_config_data()

MAX_CHARS = int(os.getenv("WEB_RESOLVER_MAX_CHARS", _config.get("max_chars", 8000)))
MIN_CHARS = int(os.getenv("WEB_RESOLVER_MIN_CHARS", _config.get("min_chars", 200)))
DEFAULT_TIMEOUT = int(os.getenv("WEB_RESOLVER_TIMEOUT", "30"))
EXA_RESULTS = int(os.getenv("WEB_RESOLVER_EXA_RESULTS", _config.get("exa_results", 5)))
TAVILY_RESULTS = int(os.getenv("WEB_RESOLVER_TAVILY_RESULTS", _config.get("tavily_results", 5)))
DDG_RESULTS = int(os.getenv("WEB_RESOLVER_DDG_RESULTS", _config.get("ddg_results", 5)))

_rate_limits: dict[str, float] = {}
_rate_limits_lock = threading.Lock()


def _is_rate_limited(provider: str) -> bool:
    with _rate_limits_lock:
        if provider in _rate_limits:
            if time.time() < _rate_limits[provider]:
                return True
            del _rate_limits[provider]
    return False


def _set_rate_limit(provider: str, cooldown: int = 60):
    with _rate_limits_lock:
        _rate_limits[provider] = time.time() + cooldown


def _clear_rate_limits() -> None:
    with _rate_limits_lock:
        _rate_limits.clear()


# Exported names for both internal use and tests
is_rate_limited = _is_rate_limited
set_rate_limit = _set_rate_limit


def resolve_with_jina(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
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
        response = session.post(
            "https://mcp.exa.ai/mcp",
            json=mcp_request,
            headers={"Accept": "application/json, text/event-stream"},
            timeout=25,
        )
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
            logger.warning(f"Tavily returned no results for query: {query}")
            return None
        content = "\n\n---\n\n".join([f"## {r['title']}\n\n{r['content']}" for r in res["results"]])
        result = ResolvedResult(source="tavily", content=content[:max_chars], query=query)
        _save_to_cache(query, "tavily", result.to_dict())
        return result
    except Exception as e:
        logger.error(f"Tavily resolution failed: {e}")
        return None


def resolve_with_serper(query: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    """Search via Serper (Google Search API). Free tier: 2500 credits."""
    cached = _get_from_cache(query, "serper")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("SERPER_API_KEY")
    if not api_key or _is_rate_limited("serper"):
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
            _set_rate_limit("serper", 3600)  # 1 hour cooldown
            return None
        if response.status_code == 401 or response.status_code == 403:
            return None
        if response.status_code != 200:
            return None
        data = response.json()
        organic = data.get("organic", [])
        if not organic:
            return None
        # Format results as markdown
        parts = []
        for r in organic:
            title = r.get("title", "")
            link = r.get("link", "")
            snippet = r.get("snippet", "")
            if title and snippet:
                parts.append(f"## {title}\n\n{snippet}\n\n[{link}]({link})")
        if not parts:
            return None
        content = "\n\n---\n\n".join(parts)
        result = ResolvedResult(source="serper", content=content[:max_chars], query=query)
        _save_to_cache(query, "serper", result.to_dict())
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
            [f"## {r.get('title', '')}\n\n{r.get('body', '')}" for r in results]
        )
        result = ResolvedResult(source="duckduckgo", content=content[:max_chars], query=query)
        _save_to_cache(query, "duckduckgo", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_firecrawl(url: str, max_chars: int = MAX_CHARS) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning("SSRF blocked: %s", url)
        return None
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
    if not is_safe_url(url):
        logger.warning(f"SSRF: blocked URL {url}")
        return None
    cached = _get_from_cache(url, "mistral_browser")
    if cached:
        return ResolvedResult(**cached)
    api_key = os.getenv("MISTRAL_API_KEY")
    if not api_key or _is_rate_limited("mistral"):
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

            if content:
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
        return None
    except Exception as e:
        logger.warning("Mistral browser resolution failed: %s", e)
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
        result = ResolvedResult(
            source="mistral-websearch", content=content[:max_chars], query=query
        )
        _save_to_cache(query, "mistral_websearch", result.to_dict())
        return result
    except Exception:
        return None


def resolve_with_docling(url: str, max_chars: int) -> ResolvedResult | None:
    if not is_safe_url(url):
        logger.warning(f"SSRF: blocked URL {url}")
        return None
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
    if not is_safe_url(url):
        logger.warning(f"SSRF: blocked URL {url}")
        return None
    import tempfile
    from scripts.utils import _safe_request
    try:
        resp = _safe_request(url, timeout=30)
        if not resp:
            return None
        with tempfile.NamedTemporaryFile() as tmp:
            tmp.write(resp.content)
            tmp.flush()
            res = subprocess.run(
                ["tesseract", tmp.name, "stdout"], capture_output=True, text=True, timeout=30
            )
            if res.returncode == 0:
                return ResolvedResult(source="ocr-tesseract", content=res.stdout[:max_chars], url=url)
    except Exception:
        pass
    return None
