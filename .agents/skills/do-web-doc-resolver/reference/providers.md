# Provider Reference

## Available Providers

### Query Providers

| Provider | Free | API Key Required | Description |
|----------|------|------------------|-------------|
| `exa_mcp` | Yes | No | Exa MCP via Model Context Protocol |
| `exa` | No | EXA_API_KEY | Exa SDK with highlights |
| `tavily` | No | TAVILY_API_KEY | Comprehensive web search |
| `serper` | No | SERPER_API_KEY | Google search (2500 free credits) |
| `duckduckgo` | Yes | No | DuckDuckGo search |
| `mistral_websearch` | No | MISTRAL_API_KEY | AI-powered web search |

### URL Providers

| Provider | Free | API Key Required | Description |
|----------|------|------------------|-------------|
| `llms_txt` | Yes | No | llms.txt structured documentation |
| `jina` | Yes | No | Jina Reader (20 RPM free tier) |
| `firecrawl` | No | FIRECRAWL_API_KEY | Deep extraction with JS rendering |
| `direct_fetch` | Yes | No | Direct HTTP fetch + HTML-to-text |
| `mistral_browser` | No | MISTRAL_API_KEY | AI-powered browser agent |
| `docling` | No | No | PDF/DOCX/PPTX processing |
| `ocr` | No | No | Image OCR (Tesseract) |

## Provider Details

### Exa MCP (FREE)

- **Endpoint**: https://mcp.exa.ai/mcp
- **Protocol**: JSON-RPC 2.0 over HTTP POST
- **Rate Limit**: 30s cooldown on 429
- **Best For**: Technical documentation, code examples

### Exa SDK

- **Features**: Token-efficient highlights, semantic search
- **Rate Limit**: 60s cooldown on 429
- **Best For**: High-quality research results

### Tavily

- **Features**: Comprehensive search, content extraction
- **Rate Limit**: 60s cooldown on 429
- **Best For**: Broad web research

### Serper

- **Features**: Google search results
- **Free Tier**: 2500 credits
- **Rate Limit**: 60s cooldown on 429
- **Best For**: Google-indexed content

### DuckDuckGo (FREE)

- **Features**: No authentication needed
- **Rate Limit**: 30s cooldown on 429
- **Best For**: Always-available fallback

### llms.txt (FREE)

- **Check**: `{origin}/llms.txt`
- **Cache**: 1-hour TTL per origin
- **Best For**: Documentation sites with structured docs

### Jina Reader (FREE)

- **Endpoint**: `https://r.jina.ai/{url}`
- **Rate Limit**: 20 requests per minute
- **Best For**: Clean markdown extraction from any URL

### Direct Fetch (FREE)

- **Method**: HTTP GET + HTML parsing
- **Features**: Script/style removal, whitespace normalization
- **Best For**: Simple static pages

## Rate Limit Handling

All providers implement automatic rate limit handling:

1. Detect 429 status code or "rate limit" in response
2. Set provider-specific cooldown period
3. Skip provider during cooldown
4. Continue to next provider in cascade

## Circuit Breaker Pattern

Each provider has an independent circuit breaker:

```
CLOSED → (3 failures) → OPEN → (5 min cooldown) → HALF_OPEN → (success) → CLOSED
                         ↑                           ↓
                         └───── (failure) ───────────┘
```
