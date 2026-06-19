# Codacy Cloud CLI - Code Quality Issues for Main Branch

## Status

**Authentication required** — The Codacy Cloud CLI (`codacy`) is installed but not authenticated. No API token was found in the environment.

## What was attempted

1. Installed `@codacy/codacy-cloud-cli` globally via npm
2. Detected repository remote: `https://github.com/d-o-hub/github-template-ai-agents`
3. Attempted to query issues with `codacy issues` (auto-detects provider/org/repo from git remote)
4. Failed: `Error: No API token found. Set CODACY_API_TOKEN or run 'codacy login'.`

## How to fix

To query code quality issues for the main branch, provide a Codacy API token:

```bash
# Option 1: Set environment variable
export CODACY_API_TOKEN=<your-token>

# Option 2: Interactive login
codacy login

# Then query issues
codacy issues
# Or with explicit params:
codacy issues gh d-o-hub github-template-ai-agents
```

Tokens can be obtained from: **Codacy → My Account → Access Management → Account API Tokens**

## Expected command (once authenticated)

```bash
# Auto-detected from git remote
codacy issues

# Or explicitly
codacy issues gh d-o-hub github-template-ai-agents

# JSON output for machine parsing
codacy issues --output json
```

## Repository info

- **Provider**: GitHub (`gh`)
- **Organization**: `d-o-hub`
- **Repository**: `github-template-ai-agents`
