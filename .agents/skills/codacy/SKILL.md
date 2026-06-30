---
name: codacy
version: "2.0.0"
category: code-quality
description: Use the Codacy CLI for local static analysis and cloud data queries. Use the Analysis CLI (`codacy-analysis`) to run local analysis without pushing to Codacy Cloud, or the Cloud CLI (`codacy`) to query remote repositories, issues, security findings, pull requests, and patterns. Use when the user wants to analyze code locally, check code quality metrics on Codacy Cloud, inspect remote PR results, browse vulnerabilities, or search patterns — even if they just say "run codacy" or "check code quality". Not for generic linter triage (use static-analysis).
license: MIT
metadata:
  author: Codacy
---

> **Glossary:** See [glossary.md](references/glossary.md) for shared definitions of Codacy concepts (issues, findings, severity, coverage, tools, patterns, etc.).

Codacy provides two CLI tools:
- **Analysis CLI** (`codacy-analysis`): Runs static analysis locally without pushing code to Codacy Cloud
- **Cloud CLI** (`codacy`): Queries remote Codacy data (repositories, issues, PRs, security findings)

Both share credentials at `~/.codacy/credentials`. Logging in with either CLI applies to both.

## When to Use

- User wants to analyze code locally without pushing to Codacy Cloud
- Need to run CLI-based linting (ESLint, Ruff, Semgrep, RuboCop)
- Scanning staged changes or setting up local Codacy tooling
- User wants to check code quality metrics on Codacy Cloud
- Need to inspect remote PR analysis results or browse vulnerabilities
- Enabling/disabling tools or searching patterns on Codacy Cloud
- Even if they just say "run codacy" or "check code quality"

## Setup

```bash
# Install Analysis CLI (local analysis)
npm i -g @codacy/analysis-cli

# Install Cloud CLI (remote queries)
npm install -g @codacy/codacy-cloud-cli

# Verify
codacy-analysis --help
codacy --help
```

### Authentication (optional for local, required for cloud)

```bash
# Option 1: Interactive login (shared by both CLIs)
codacy login

# Option 2: Token flag
codacy login --token <your-api-token>

# Option 3: Environment variable
export CODACY_API_TOKEN=<your-api-token>

# Obtain tokens: Codacy > My Account > Access Management
# Remove credentials
codacy logout
```

**Shared session:** Both CLIs share `~/.codacy/credentials`. Logging in/out with either applies to both.

## Local Analysis (Analysis CLI)

The Analysis CLI (`codacy-analysis`) runs static analysis locally. It detects languages, selects tools, and reports issues — without pushing code to Codacy.

Always use `--output-format json` for structured output in agentic workflows.

### Analysis Workflow

```
1. Initialize configuration
2. Inspect tool availability (dry-run)
3. Install missing dependencies
4. Run analysis
5. Interpret results
```

### Step 1: Initialize configuration

```bash
codacy-analysis init
# Or with remote config:
codacy-analysis init --remote --provider gh --organization my-org --repository my-repo
```

### Step 2: Inspect tool availability

```bash
codacy-analysis analyze --inspect --output-format json

# See which tools are ready
codacy-analysis analyze --inspect --output-format json | jq '.capability.ready[] | {toolId, version}'

# See which tools are missing
codacy-analysis analyze --inspect --output-format json | jq '.capability.unavailable[] | {toolId, reason}'
```

### Step 3: Install missing dependencies

```bash
codacy-analysis analyze --install-dependencies --output-format json
```

### Step 4: Run analysis

```bash
codacy-analysis analyze --output-format json
```

### Step 5: Interpret results

See [references/analysis-interpret.md](references/analysis-interpret.md) for details.

## Cloud Queries (Cloud CLI)

The Cloud CLI (`codacy`) queries remote Codacy data. Auto-detects provider, organization, and repository from git remote.

```bash
# List issues
codacy issues

# Check repository status
codacy repository

# Inspect a pull request
codacy pull-request 42

# Trigger reanalysis and wait
codacy repository --reanalyze-and-wait
```

Use `--output json` on any command for machine-readable output.

### How Codacy data works

- **Data reflects the HEAD commit** — issue lists, coverage, and security findings show the latest analyzed commit
- **Configuration changes are not instant** — enable/disable tools only take effect after next analysis
- **Organization standards are enforced** — cannot be overridden at repository level

### Reanalysis

```bash
# Trigger reanalysis and wait for results (preferred)
codacy repository --reanalyze-and-wait
codacy repository -w -o json    # JSON delta report

# Fire-and-forget reanalysis
codacy repository --reanalyze
```

## Filesystem conventions

| Location | Scope | Contents |
|----------|-------|----------|
| `.codacy/` (repo root) | Per-project | `codacy.config.json`, `generated/` (tool configs) |
| `~/.codacy/` (home dir) | Machine-wide | Runtimes, tool binaries, caches, logs, credentials |

The analyzed repository is **never modified outside of `.codacy/`**.

## Common workflows

- Local analysis: See [references/analysis-workflows.md](references/analysis-workflows.md)
- Cloud queries: See [references/cloud-workflows.md](references/cloud-workflows.md)
- Cloud commands: See [references/cloud-commands.md](references/cloud-commands.md)

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The CLI is slow" | Better to wait for local results than to wait 10+ minutes for a CI failure. |
| "I'll just fix it later" | Unfixed quality gate failures compound technical debt and block others. |
| "I can just check the dashboard" | CLI is faster for automation and scripting than navigating a UI. |

## Red Flags

- [ ] Ignoring Codacy failures and pushing anyway.
- [ ] Suppressing issues as "FalsePositive" without verifying they actually are.
- [ ] Running `codacy-analysis analyze` without the `--pr` flag on a large codebase (may be slow).
- [ ] Using the issue `hash` for CLI suppressions (requires numeric `resultDataId`).
- [ ] Assuming configuration changes take effect immediately without reanalysis.

## See Also

- `static-analysis` — Generic linter triage across any language
- `code-review-assistant` — PR review workflow

## Troubleshooting

See [references/analysis-troubleshooting.md](references/analysis-troubleshooting.md) for details.
