---
name: web-doc-resolver
description: Resolve queries or URLs into compact, LLM-ready markdown using a low-cost cascade. Prioritizes free sources, uses paid APIs only when necessary. Use when fetching documentation, resolving web URLs, or building context from web sources.
---

# Web Documentation Resolver

Resolve queries or URLs into compact, LLM-ready markdown using a progressive cascade.

## Quick Start

```
Web Doc Resolution Cascade:
- [ ] Step 1: Check llms.txt (free, structured)
- [ ] Step 2: Direct fetch / free search
- [ ] Step 3: Paid API fallback (if configured)
- [ ] Step 4: Return markdown result
```

## When to Use

Activate this skill when you need to:
- Fetch and parse documentation from a URL
- Search for technical information across the web
- Build context from web sources
- Extract markdown from websites
- Query for technical documentation, APIs, or code examples

## Cascade Resolution Strategy

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
```

### For Query Inputs

```
1. DuckDuckGo Search (FREE)
   ↓ if insufficient
2. Exa MCP (FREE, if available)
   ↓ if fails
3. Tavily API (paid)
   ↓ if fails
4. Exa SDK (paid)
```

## Platform Tool Mapping

| Platform | Fetch Tool | Search Tool |
|----------|------------|-------------|
| **Claude Code** | `WebFetch` (MCP) | `WebSearch` (MCP) |
| **OpenCode** | `webfetch` | `websearch` |
| **Gemini CLI** | `fetch` | `search` |
| **Python script** | `requests`, `httpx` | `duckduckgo-search` |

## Usage Examples

### Basic URL Resolution

```bash
# Using platform tool directly (Claude Code)
WebFetch https://docs.rust-lang.org/book/

# Using Python script (auto-detects backend)
python scripts/resolve.py "https://docs.rust-lang.org/book/"
```

### Query Resolution

```bash
# Using platform tool directly
WebSearch "Rust async programming best practices 2026"

# Using Python script
python scripts/resolve.py "Rust tokio spawn vs spawn_blocking"
```

### With Provider Control

```bash
# Skip specific providers
python scripts/resolve.py "query" --skip exa_mcp --skip exa

# Use specific provider directly
python scripts/resolve.py "https://example.com" --provider jina
```

## Best Practices

### DO:
✓ Check for `llms.txt` first - many docs sites have `/llms.txt` for structured content
✓ Use specific queries - "rust tokio spawn vs spawn_blocking" not "rust tokio"
✓ Filter by date - add "2025" or "2026" for current information
✓ Prefer official docs - always check official documentation first
✓ Try multiple sources - if one URL fails, search for mirrors

### DON'T:
✗ Use paid APIs when free sources available
✗ Fetch entire websites - be targeted
✗ Ignore rate limits - respect API quotas

## Rate Limit Handling

| Provider | Cooldown | Notes |
|----------|----------|-------|
| DuckDuckGo | 30s | Free, generous limits |
| Exa MCP | 30s | Free via MCP |
| Jina Reader | 60s | Free tier available |
| Tavily | 60s | Paid, check credits |
| Exa SDK | 60s | Paid, check credits |
| Firecrawl | 60s | Paid, per-page pricing |

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `RateLimitError` | Too many requests | Wait cooldown, retry |
| `QuotaExceeded` | Out of credits | Switch to free provider |
| `ConnectionError` | Network issue | Retry with backoff |
| `ParseError` | Invalid HTML/Markdown | Try alternative source |

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
            continue

    raise ResolutionError(f"All providers failed: {last_error}")
```

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

## Environment Variables

```bash
# Optional API keys (skill works without them using free sources)
export EXA_API_KEY="your-exa-key"           # For Exa SDK
export TAVILY_API_KEY="your-tavily-key"     # For Tavily
export FIRECRAWL_API_KEY="your-firecrawl"   # For Firecrawl
export MISTRAL_API_KEY="your-mistral-key"   # For Mistral Browser
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

## Troubleshooting

### All Providers Fail
- Check network connectivity
- Verify URL is accessible
- Wait for rate limits to reset

### Poor Quality Results
- Make query more specific
- Add year filter (e.g., "2026")
- Use site: operator for official docs

### Slow Resolution
- Skip slow providers with --skip flag
- Use direct provider specification
- Cache frequently accessed content

## Summary

The web-doc-resolver skill provides efficient, cost-effective web resolution:
1. **Progressive cascade**: Free sources first, paid APIs last
2. **Platform agnostic**: Works with Claude Code, OpenCode, Gemini, Python
3. **Rate limit aware**: Respects provider limits with cooldowns
4. **Error resilient**: Graceful fallback between providers
5. **Flexible output**: Markdown or JSON format

This skill enables AI agents to fetch current, accurate information from the web while minimizing costs.

## Reference Files

- **[reference/guide.md](reference/guide.md)** - Complete cascade resolution strategy, platform tool mapping, detailed best practices, rate limit handling, error handling patterns, output formats, Python implementation reference, AI agent integration guide, environment configuration, testing examples, and advanced topics including caching and batch resolution
