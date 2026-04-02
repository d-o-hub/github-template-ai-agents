---
name: do-web-doc-resolver
description: Resolve queries or URLs into compact, LLM-ready markdown using an intelligent, low-cost cascade. Prioritizes free sources (Exa MCP, llms.txt, DuckDuckGo), uses paid APIs only when necessary. Use when fetching documentation, resolving web URLs, or building context from web sources.
license: MIT
metadata:
  source: https://github.com/d-oit/do-web-doc-resolver
  version: "0.4.0"
---

# Web Documentation Resolver

Resolve queries or URLs into compact, LLM-ready markdown using a progressive, free-first cascade.

## When to Use

Activate this skill when you need to:
- Fetch and parse documentation from a URL
- Search for technical information across the web
- Build context from web sources for AI agents
- Extract clean markdown from websites
- Query for technical documentation, APIs, or code examples

## Quick Start

```bash
# Python CLI
python scripts/resolve.py "https://docs.rust-lang.org/book/"
python scripts/resolve.py "Rust async programming best practices"

# Rust CLI (faster)
do-wdr resolve "https://example.com"
do-wdr resolve "machine learning tutorials" --profile free
```

## Cascade Resolution Strategy

### For URL Inputs

1. **Semantic Cache** — Instant retrieval for known URLs
2. **llms.txt** — Check for structured docs at `{origin}/llms.txt` (FREE)
3. **Jina Reader** — `https://r.jina.ai/{url}` (FREE, 20 RPM)
4. **Direct HTTP Fetch** — Basic HTML-to-text extraction (FREE)
5. **Firecrawl** — Deep extraction with JS rendering (paid)
6. **Mistral Browser** — AI-powered fallback (paid)
7. **DuckDuckGo** — Search fallback (FREE)

### For Query Inputs

1. **Semantic Cache** — Multi-layer cache (URL, Query, Provider)
2. **Exa MCP** — FREE search via Model Context Protocol (no API key!)
3. **Exa SDK** — Token-efficient highlights (paid, low-cost)
4. **Tavily** — Comprehensive search (paid)
5. **Serper** — Google search via Serper API (2500 free credits)
6. **DuckDuckGo** — Free search, always available (FREE)
7. **Mistral Web Search** — AI-powered fallback (paid)

## Execution Profiles

| Profile | Max Attempts | Max Paid | Max Latency | Quality |
|---------|-------------|----------|-------------|---------|
| `free` | 3 | 0 | 6s | 0.70 |
| `fast` | 2 | 1 | 4s | 0.60 |
| `balanced` | 4-6 | 1-2 | 9-12s | 0.65 |
| `quality` | 6-10 | 3-5 | 15-20s | 0.55 |

## Key Features

- **Zero-key operation**: Works with no API keys using free sources
- **Circuit breakers**: Per-provider failure tracking with 5-minute cooldowns
- **Routing memory**: Per-domain provider success rate learning
- **Quality scoring**: Content scored 0.0-1.0 based on signals
- **Content compaction**: Boilerplate removal and deduplication
- **AI synthesis**: Cohesive answers from multiple providers

## Configuration

All API keys are optional. The resolver works without any keys.

```bash
# Provider keys (all optional)
export EXA_API_KEY="your_key"
export TAVILY_API_KEY="your_key"
export SERPER_API_KEY="your_key"
export FIRECRAWL_API_KEY="your_key"
export MISTRAL_API_KEY="your_key"

# Resolver settings
export WEB_RESOLVER_MAX_CHARS=8000
export WEB_RESOLVER_MIN_CHARS=200
export WEB_RESOLVER_TIMEOUT=30
```

## Output Format

```python
{
    "url": "https://example.com/docs",
    "content": "# Documentation\n\n...",
    "source": "exa_mcp",
    "score": 0.87,
    "metrics": {
        "latency_ms": 1234,
        "providers_attempted": ["exa_mcp"],
        "cache_hit": false
    }
}
```

## Error Handling

| Error Type | Detection | Behavior |
|------------|-----------|----------|
| rate_limit | 429 | Set cooldown, skip provider |
| auth_error | 401, 403 | Log error, skip provider |
| quota_exhausted | 402 | Log warning, skip provider |
| network_error | timeout | Log error, skip provider |
| not_found | 404 | Log error, skip provider |

## References

| Topic | File |
|-------|------|
| Cascade decision trees | `reference/cascade.md` |
| Provider details | `reference/providers.md` |
| Configuration | `reference/configuration.md` |
