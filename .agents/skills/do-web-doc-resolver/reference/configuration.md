# Configuration Reference

## Environment Variables

### Provider API Keys (All Optional)

| Variable | Provider | Notes |
|----------|----------|-------|
| `EXA_API_KEY` | Exa SDK | Optional - Exa MCP runs first (free) |
| `TAVILY_API_KEY` | Tavily | Optional - comprehensive search |
| `SERPER_API_KEY` | Serper | Optional - 2500 free credits |
| `FIRECRAWL_API_KEY` | Firecrawl | Optional - deep extraction |
| `MISTRAL_API_KEY` | Mistral | Optional - AI-powered fallback |

### Resolver Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `WEB_RESOLVER_MAX_CHARS` | 8000 | Maximum characters in output |
| `WEB_RESOLVER_MIN_CHARS` | 200 | Minimum characters for valid result |
| `WEB_RESOLVER_TIMEOUT` | 30 | Request timeout in seconds |
| `WEB_RESOLVER_CACHE_TTL` | 86400 | Cache TTL in seconds (24h) |
| `WEB_RESOLVER_PROFILE` | balanced | Default execution profile |

### Setting API Keys

```bash
# Linux/macOS
export EXA_API_KEY="your_key"
export TAVILY_API_KEY="your_key"
export SERPER_API_KEY="your_key"
export FIRECRAWL_API_KEY="your_key"
export MISTRAL_API_KEY="your_key"

# Windows (PowerShell)
$env:EXA_API_KEY="your_key"
$env:TAVILY_API_KEY="your_key"
```

## Rust CLI Configuration

The Rust CLI supports `config.toml` and `DO_WDR_*` environment variables:

```toml
# config.toml
[providers.exa]
api_key = "your_key"
enabled = true

[providers.tavily]
api_key = "your_key"
enabled = true

[resolver]
profile = "balanced"
max_chars = 8000
timeout_seconds = 30
```

### Rust CLI Environment Variables

| Variable | Description |
|----------|-------------|
| `DO_WDR_EXA_API_KEY` | Exa API key |
| `DO_WDR_TAVILY_API_KEY` | Tavily API key |
| `DO_WDR_SERPER_API_KEY` | Serper API key |
| `DO_WDR_FIRECRAWL_API_KEY` | Firecrawl API key |
| `DO_WDR_MISTRAL_API_KEY` | Mistral API key |
| `DO_WDR_PROFILE` | Default profile |
| `DO_WDR_MAX_CHARS` | Max output characters |

## Execution Profiles

### Free Profile

- Max 3 provider attempts
- No paid providers
- Quality threshold: 0.70
- Best for: Development, testing

### Fast Profile

- Max 2 provider attempts
- 1 paid provider allowed
- Quality threshold: 0.60
- Best for: Quick lookups

### Balanced Profile (Default)

- 4-6 provider attempts
- 1-2 paid providers allowed
- Quality threshold: 0.65
- Best for: General use

### Quality Profile

- 6-10 provider attempts
- 3-5 paid providers allowed
- Quality threshold: 0.55
- Best for: Research, comprehensive results

## Cache Configuration

### Semantic Cache

- **Backend**: Turso/libsql (feature-gated)
- **TTL**: 24 hours (configurable)
- **Layers**: URL cache, Query cache, Provider cache

### Negative Cache

- **TTL**: 30 minutes
- **Reasons**: `thin_content`, `error`, `timeout`
- **Purpose**: Avoid re-probing known-failing providers

## Quality Scoring

Content is scored on a 0.0-1.0 scale:

| Signal | Penalty |
|--------|---------|
| Too short (< 500 chars) | -0.35 |
| Missing links | -0.15 |
| Duplicate-heavy | -0.25 |
| Noisy content | -0.20 |
