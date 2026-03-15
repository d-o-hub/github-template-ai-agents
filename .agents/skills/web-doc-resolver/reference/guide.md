# Web Documentation Resolver - Reference Guide

Complete guide for resolving queries and URLs into compact, LLM-ready markdown using a progressive cascade.

## Cascade Resolution Strategy - Deep Dive

### For URL Inputs

```
1. llms.txt (FREE, structured)
   ↓ if not found
2. Direct HTTP fetch (FREE)
   ↓ if fails
3. Jina Reader API (free tier)
   ↓ if fails
4. Firecrawl API (paid)
   ↓ if fails
5. Mistral Browser (paid)
   ↓ if fails
6. Return error with suggestions
```

**Step-by-Step URL Resolution**:

#### Step 1: Check llms.txt
```bash
# Many documentation sites have /llms.txt for structured LLM content
https://example.com/llms.txt
https://example.com/docs/llms.txt
```

**Why first**: Structured, clean markdown specifically for LLMs

#### Step 2: Direct HTTP Fetch
```python
import requests
response = requests.get(url)
html_to_markdown(response.text)
```

**Why second**: Free, works for most sites

#### Step 3: Jina Reader API
```bash
curl https://r.jina.ai/https://example.com
```

**Why third**: Free tier available, handles JavaScript sites

#### Step 4: Firecrawl API
```python
from firecrawl import FirecrawlApp
app = FirecrawlApp(api_key=KEY)
result = app.scrape_url(url)
```

**Why fourth**: Paid, but high quality extraction

#### Step 5: Mistral Browser
```python
# Use Mistral's browser tool for complex sites
```

**Why fifth**: Paid, last resort for difficult sites

### For Query Inputs

```
1. DuckDuckGo Search (FREE)
   ↓ if insufficient
2. Exa MCP (FREE, if available)
   ↓ if fails
3. Tavily API (paid)
   ↓ if fails
4. Exa SDK (paid)
   ↓ if fails
5. Return error with suggestions
```

**Step-by-Step Query Resolution**:

#### Step 1: DuckDuckGo Search
```python
from duckduckgo_search import DDGS
results = DDGS().text(query, max_results=10)
```

**Why first**: Free, no API key needed, good coverage

#### Step 2: Exa MCP
```markdown
# Use Exa MCP tool if available
ExaSearch(query)
```

**Why second**: Free via MCP, AI-optimized results

#### Step 3: Tavily API
```python
from tavily import TavilyClient
client = TavilyClient(api_key=KEY)
results = client.search(query)
```

**Why third**: Paid, but designed for LLM research

#### Step 4: Exa SDK
```python
from exa_py import Exa
exa = Exa(api_key=KEY)
results = exa.search(query)
```

**Why fourth**: Paid, neural search for technical content

## Platform Tool Mapping

| Platform | Fetch Tool | Search Tool |
|----------|------------|-------------|
| **Claude Code** | `WebFetch` (MCP) | `WebSearch` (MCP) |
| **OpenCode** | `webfetch` | `websearch` |
| **Gemini CLI** | `fetch` | `search` |
| **Python script** | `requests`, `httpx` | `duckduckgo-search` |

### Tool Usage Examples

#### Claude Code
```markdown
# Fetch URL
WebFetch https://docs.rust-lang.org/book/

# Search query
WebSearch "Rust async best practices 2026"
```

#### OpenCode
```markdown
# Fetch URL
webfetch https://docs.python.org/3/

# Search query
websearch "Python async best practices"
```

#### Python Script
```bash
# Auto-detects backend
python scripts/resolve.py "https://docs.python.org/3/"
python scripts/resolve.py "Python async best practices"
```

## Best Practices - Detailed Guide

### DO:

✓ **Check for `llms.txt` first**
- Many docs sites have `/llms.txt` for structured content
- Example: `https://example.com/llms.txt`
- Clean markdown, no HTML parsing needed

✓ **Use specific queries**
- Good: "rust tokio spawn vs spawn_blocking"
- Bad: "rust tokio"

✓ **Filter by date**
- Add "2025" or "2026" for current information
- Example: "Rust async patterns 2026"

✓ **Prefer official docs**
- Always check official documentation first
- Example: `site:docs.rust-lang.org`

✓ **Try multiple sources**
- If one URL fails, search for mirrors
- Example: GitHub repo, alternative docs host

✓ **Respect rate limits**
- Wait between requests
- Use exponential backoff

### DON'T:

✗ **Use paid APIs when free sources available**
- Always try free sources first
- Check quota before using paid APIs

✗ **Fetch entire websites**
- Be targeted
- Fetch specific pages only

✗ **Ignore rate limits**
- Respect API
- Implement backoff

✗ **Trust unverified sources**
- Cross-reference with official docs
- Check author credentials

## Rate Limit Handling

| Provider | Cooldown | Notes |
|----------|----------|-------|
| DuckDuckGo | 30s | Free, generous limits |
| Exa MCP | 30s | Free via MCP |
| Jina Reader | 60s | Free tier available |
| Tavily | 60s | Paid, check credits |
| Exa SDK | 60s | Paid, check credits |
| Firecrawl | 60s | Paid, per-page pricing |

### Rate Limit Implementation

```python
import time
from datetime import datetime, timedelta

class RateLimiter:
    def __init__(self, cooldown_seconds):
        self.cooldown = cooldown_seconds
        self.last_call = None

    def wait_if_needed(self):
        if self.last_call:
            elapsed = datetime.now() - self.last_call
            if elapsed.total_seconds() < self.cooldown:
                wait_time = self.cooldown - elapsed.total_seconds()
                time.sleep(wait_time)
        self.last_call = datetime.now()
```

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `RateLimitError` | Too many requests | Wait cooldown, retry |
| `QuotaExceeded` | Out of credits | Switch to free provider |
| `ConnectionError` | Network issue | Retry with backoff |
| `ParseError` | Invalid HTML/Markdown | Try alternative source |
| `NotFoundError` | URL doesn't exist | Check URL, try search |
| `TimeoutError` | Request took too long | Increase timeout, retry |

### Fallback Pattern

```python
def resolve_with_fallback(url):
    providers = [llms_txt, direct_fetch, jina, firecrawl]
    last_error = None

    for provider in providers:
        try:
            result = provider.fetch(url)
            if result:
                return result
        except (RateLimitError, QuotaExceededError) as e:
            last_error = e
            log_cooldown(provider)
            continue
        except (ConnectionError, TimeoutError) as e:
            last_error = e
            log_retry(provider)
            continue

    raise ResolutionError(f"All providers failed: {last_error}")
```

### Error Recovery Strategies

1. **Rate Limit Hit**:
   - Wait cooldown period
   - Switch to alternative provider
   - Implement exponential backoff

2. **Quota Exceeded**:
   - Switch to free provider
   - Notify user of credit status
   - Queue remaining requests

3. **Connection Failed**:
   - Retry with backoff (1s, 2s, 4s)
   - Try alternative provider
   - Check network connectivity

4. **Parse Failed**:
   - Try different extraction method
   - Fetch raw HTML
   - Use alternative source

## Output Format

Return results in this format:

```markdown
# Source: [URL or Query]
# Resolved: [Timestamp]
# Provider: [Provider used]

[Markdown content here]

---
*Resolved using web-doc-resolver cascade*
```

### Output Options

#### Markdown (Default)
```markdown
# Source: https://docs.rust-lang.org/book/
# Resolved: 2025-03-15 10:30:00 UTC
# Provider: direct_fetch

[Chapter content in markdown]
```

#### JSON
```json
{
  "source": "https://docs.rust-lang.org/book/",
  "resolved_at": "2025-03-15T10:30:00Z",
  "provider": "direct_fetch",
  "content": "...",
  "format": "markdown"
}
```

## Implementation Reference

### Python Script Structure

```python
#!/usr/bin/env python3
"""
Web Documentation Resolver
Resolve queries/URLs into LLM-ready markdown via cascade.
"""

import sys
import argparse
from enum import Enum

class ProviderType(Enum):
    # URL providers
    LLMS_TXT = "llms_txt"
    DIRECT_FETCH = "direct_fetch"
    JINA = "jina"
    FIRECRAWL = "firecrawl"

    # Query providers
    DUCKDUCKGO = "duckduckgo"
    EXA_MCP = "exa_mcp"
    TAVILY = "tavily"
    EXA = "exa"

def resolve(input_str, skip_providers=None, provider_order=None):
    """Resolve URL or query using cascade."""
    is_url = input_str.startswith(("http://", "https://"))

    if is_url:
        return resolve_url(input_str, skip_providers, provider_order)
    else:
        return resolve_query(input_str, skip_providers, provider_order)

def resolve_url(url, skip=None, order=None):
    """Resolve URL using cascade."""
    providers = order or [
        ProviderType.LLMS_TXT,
        ProviderType.DIRECT_FETCH,
        ProviderType.JINA,
        ProviderType.FIRECRAWL,
    ]

    for provider_type in providers:
        if provider_type in (skip or []):
            continue

        try:
            result = fetch_with_provider(provider_type, url)
            if result:
                return format_result(result, provider_type)
        except Exception as e:
            log_error(provider_type, e)
            continue

    raise ResolutionError("All URL providers failed")

def resolve_query(query, skip=None, order=None):
    """Resolve query using cascade."""
    providers = order or [
        ProviderType.DUCKDUCKGO,
        ProviderType.EXA_MCP,
        ProviderType.TAVILY,
        ProviderType.EXA,
    ]

    for provider_type in providers:
        if provider_type in (skip or []):
            continue

        try:
            result = search_with_provider(provider_type, query)
            if result:
                return format_result(result, provider_type)
        except Exception as e:
            log_error(provider_type, e)
            continue

    raise ResolutionError("All search providers failed")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input", help="URL or query to resolve")
    parser.add_argument("--skip", nargs="+", help="Providers to skip")
    parser.add_argument("--provider", help="Use specific provider")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    result = resolve(args.input, skip_providers=args.skip)

    if args.json:
        print(result.to_json())
    else:
        print(result.markdown)
```

## Integration with AI Agents

### Claude Code Integration

```markdown
# In .claude/agents/researcher.md
---
name: researcher
description: Research topics using web search and documentation
tools: WebFetch, WebSearch
---

Use web-doc-resolver skill for all research tasks.
Follow cascade: free sources first, paid APIs only when necessary.
```

### Skill Trigger Rules

Add to `skill-rules.json`:

```json
{
  "skill": "web-doc-resolver",
  "triggers": {
    "keywords": ["fetch", "documentation", "web", "search", "url", "markdown"],
    "patterns": ["docs\\..*", "readme", "tutorial", "guide"],
    "files": []
  },
  "priority": "medium",
  "autoActivate": false
}
```

### Agent Workflow Integration

```
User Request → Agent Analysis → web-doc-resolver → Content → Agent Synthesis → Response
```

**Example Workflow**:
1. User: "How do I verify Stripe webhook signatures?"
2. Agent: Identifies need for official Stripe docs
3. Agent: Invokes web-doc-resolver with URL/query
4. Skill: Resolves via cascade, returns markdown
5. Agent: Synthesizes answer from content
6. Agent: Responds to user with sourced information

## Environment Variables

```bash
# Optional API keys (skill works without them using free sources)
export EXA_API_KEY="your-exa-key"           # For Exa SDK
export TAVILY_API_KEY="your-tavily-key"     # For Tavily
export FIRECRAWL_API_KEY="your-firecrawl"   # For Firecrawl
export MISTRAL_API_KEY="your-mistral-key"   # For Mistral Browser
```

### Configuration File

```yaml
# .web-doc-resolver.yaml
providers:
  url:
    - llms_txt
    - direct_fetch
    - jina
    - firecrawl
  query:
    - duckduckgo
    - exa_mcp
    - tavily
    - exa

rate_limits:
  duckduckgo: 30
  jina: 60
  tavily: 60

output:
  format: markdown
  include_source: true
  include_timestamp: true
```

## Testing

```bash
# Test URL resolution
python scripts/resolve.py "https://docs.python.org/3/"

# Test query resolution
python scripts/resolve.py "Python async best practices"

# Test with provider skip
python scripts/resolve.py "query" --skip exa_mcp --skip exa

# Test JSON output
python scripts/resolve.py "query" --json | jq .

# Test specific provider
python scripts/resolve.py "https://example.com" --provider jina
```

### Test Cases

```python
def test_url_resolution():
    """Test basic URL resolution."""
    result = resolve("https://docs.python.org/3/")
    assert result.provider in ["llms_txt", "direct_fetch", "jina"]
    assert result.content

def test_query_resolution():
    """Test query resolution."""
    result = resolve("Python async best practices")
    assert result.provider in ["duckduckgo", "exa_mcp"]
    assert result.results

def test_provider_skip():
    """Test skipping providers."""
    result = resolve("query", skip=["exa_mcp", "exa"])
    assert result.provider not in ["exa_mcp", "exa"]

def test_json_output():
    """Test JSON output format."""
    result = resolve("query", json=True)
    assert isinstance(result, dict)
    assert "content" in result
```

## Advanced Topics

### Custom Provider Implementation

```python
class CustomProvider:
    def fetch(self, url):
        # Custom fetch logic
        pass

    def search(self, query):
        # Custom search logic
        pass

# Register provider
register_provider("custom", CustomProvider())
```

### Caching Strategy

```python
import hashlib
import json
from pathlib import Path

class Cache:
    def __init__(self, cache_dir=".cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)

    def _key(self, input_str):
        return hashlib.md5(input_str.encode()).hexdigest()

    def get(self, input_str):
        key = self._key(input_str)
        cache_file = self.cache_dir / f"{key}.json"
        if cache_file.exists():
            return json.loads(cache_file.read_text())
        return None

    def set(self, input_str, result):
        key = self._key(input_str)
        cache_file = self.cache_dir / f"{key}.json"
        cache_file.write_text(json.dumps(result))
```

### Batch Resolution

```python
def resolve_batch(inputs, max_concurrent=5):
    """Resolve multiple inputs in parallel."""
    import asyncio

    async def resolve_one(input_str):
        return resolve(input_str)

    async def batch():
        semaphore = asyncio.Semaphore(max_concurrent)

        async def limited_resolve(input_str):
            async with semaphore:
                return await asyncio.to_thread(resolve, input_str)

        tasks = [limited_resolve(i) for i in inputs]
        return await asyncio.gather(*tasks)

    return asyncio.run(batch())
```

## Troubleshooting

### Issue: All Providers Fail

**Symptoms**: ResolutionError from all providers

**Causes**:
- Network connectivity issue
- Invalid URL or query
- All rate limited

**Solutions**:
1. Check network connectivity
2. Verify URL is accessible
3. Wait for rate limits to reset
4. Try alternative query formulation

### Issue: Poor Quality Results

**Symptoms**: Irrelevant or outdated content

**Causes**:
- Vague query
- Outdated sources
- Wrong provider selection

**Solutions**:
1. Make query more specific
2. Add year filter (e.g., "2026")
3. Use site: operator for official docs
4. Try different provider

### Issue: Slow Resolution

**Symptoms**: Takes too long to resolve

**Causes**:
- Multiple provider failures
- Network latency
- Large content extraction

**Solutions**:
1. Skip slow providers
2. Use direct provider specification
3. Implement timeout limits
4. Cache frequently accessed content
