---
name: do-web-doc-resolver
description: Resolve queries or URLs into compact, LLM-ready markdown using an intelligent, low-cost cascade. Prioritizes free sources (Exa MCP, llms.txt, DuckDuckGo), uses paid APIs only when necessary. Use when fetching documentation, resolving web URLs, or building context from web sources.
license: MIT
metadata:
  source: https://github.com/d-oit/do-web-doc-resolver
---

# do-web-doc-resolver Skill

Resolve queries or URLs into compact, LLM-ready markdown using a progressive cascade.

## When to Use

Activate this skill when you need to:
- Fetch and parse documentation from a URL
- Search for technical information across the web
- Build context from web sources
- Extract markdown from websites
- Query for technical documentation, APIs, or code examples

## Cascade Resolution Strategy

### For URL Inputs

1. llms.txt (FREE, structured)
   ↓ if not found
2. Jina Reader API (free tier)
   ↓ if fails
3. Direct HTTP fetch (FREE)
   ↓ if fails
4. Firecrawl API (paid)
   ↓ if fails
5. Mistral Browser (paid)
   ↓ if fails
6. DuckDuckGo search fallback (FREE)

### For Query Inputs

1. Exa MCP (FREE - no API key required)
   ↓ if fails
2. Exa SDK (if EXA_API_KEY set)
   ↓ if fails
3. Tavily (if TAVILY_API_KEY set)
   ↓ if fails
4. Serper (if SERPER_API_KEY set)
   ↓ if fails
5. DuckDuckGo (FREE - always available)
   ↓ if fails
6. Mistral Web Search (if MISTRAL_API_KEY set)

## Quick Start

```
Web Doc Resolution Cascade:
- [ ] Step 1: Check llms.txt (free, structured)
- [ ] Step 2: Exa MCP / free search
- [ ] Step 3: Paid API fallback (if configured)
- [ ] Step 4: Return markdown result
```

## Key Features

- **Zero-key operation**: Works with no API keys using free sources
- **Circuit breakers**: Per-provider failure tracking with cooldowns
- **Routing memory**: Per-domain provider success rate learning
- **Semantic cache**: Multi-layer cache (URL, Query, Provider)
- **Quality scoring**: Bias scoring based on domain trust and heuristics

## Related

See full implementation: [d-oit/do-web-doc-resolver](https://github.com/d-oit/do-web-doc-resolver)
