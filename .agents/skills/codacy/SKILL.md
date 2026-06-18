---
name: codacy
version: "1.4.0"
category: code-quality
description: Use the Codacy Analysis CLI to run LOCAL static analysis on repositories or specific files. Use when the user wants to analyze code locally on their machine without pushing to Codacy Cloud, run CLI-based linting (ESLint, Ruff, Semgrep, RuboCop), scan staged changes or local PRs, or set up local Codacy tooling. This is the LOCAL CLI skill — NOT for querying Codacy Cloud (use codacy-cloud-cli for cloud queries).
license: MIT
metadata:
  author: Codacy
---

> **Glossary:** See [glossary.md](references/glossary.md) for shared definitions of Codacy concepts (issues, findings, severity, coverage, tools, patterns, etc.). **Cloud CLI:** For querying remote Codacy data, use the [`codacy-cloud-cli`](../codacy-cloud-cli/SKILL.md) skill.

The Codacy Analysis CLI (`codacy-analysis`) runs static analysis locally on a repository. It detects languages, selects tools, and reports issues — without pushing code to Codacy.

Always use `--output-format json` for structured output in agentic workflows.

## When to Use

- User wants to analyze code locally without pushing to Codacy Cloud
- Need to run CLI-based linting (ESLint, Ruff, Semgrep, RuboCop)
- Scanning staged changes or setting up local Codacy tooling
- Even if they just say "run codacy locally" or "check code quality"

## Setup

```bash
# Install
npm i -g @codacy/analysis-cli

# Verify
codacy-analysis --help
```

### Authentication (optional)

Authentication is only required for `init --remote` (fetching config from a Codacy repository). Local analysis works without authentication.

```bash
# Option 1: Interactive login
codacy-analysis login

# Option 2: Token flag
codacy-analysis login --token <your-api-token>

# Option 3: Environment variable
export CODACY_API_TOKEN=<your-api-token>

# Obtain tokens: Codacy > My Account > Access Management
# Remove credentials
codacy-analysis logout
```

**Shared session:** The Analysis CLI and the Cloud CLI (`codacy`) share the same credentials at `~/.codacy/credentials`. Logging in or out with either CLI applies to both — there is no need to authenticate separately.

## Getting help

```bash
codacy-analysis --help
codacy-analysis <command> --help
# e.g. codacy-analysis analyze --help
```

## Filesystem conventions

The CLI uses two managed locations:

| Location | Scope | Contents |
|----------|-------|----------|
| `.codacy/` (in repo root) | Per-project | `codacy.config.json`, `generated/` (tool configs), `.gitignore` (auto-created) |
| `~/.codacy/` (home dir) | Machine-wide | Runtimes, tool binaries, caches, logs, credentials |

The analyzed repository is **never modified outside of `.codacy/`**. The `.codacy/.gitignore` is auto-created to exclude `generated/`, logs, and other transient files.

### Key files

See [references/analysis-files.md](references/analysis-files.md) for details.

## Provider values

Used with `init --remote`. See the [Provider section in the glossary](references/glossary.md#provider) for the full table of CLI values (`gh`, `gl`, `bb`).

## Analysis workflow

```
Analysis Progress:
- [ ] Step 1: Initialize configuration
- [ ] Step 2: Inspect tool availability (dry-run)
- [ ] Step 3: Install missing dependencies
- [ ] Step 4: Run analysis
- [ ] Step 5: Interpret results
```

### Step 1: Initialize configuration

See [references/analysis-init.md](references/analysis-init.md) for detailed command options and workflows.

### Step 2: Inspect tool availability (dry-run)

Before running analysis, check which tools are available and which are missing:

```bash
codacy-analysis analyze --inspect --output-format json
```

This produces a capability report without running any analysis. Parse the JSON output:

```bash
# See which tools are ready
codacy-analysis analyze --inspect --output-format json | jq '.capability.ready[] | {toolId, version, installation}'

# See which tools are missing and how to fix them
codacy-analysis analyze --inspect --output-format json | jq '.capability.unavailable[] | {toolId, reason, remediation}'
```

**Important:** `--inspect` and `--install-dependencies` are mutually exclusive. Use `--inspect` first to check readiness, then `--install-dependencies` to install and run in a single step.

**Decision point:**
- If all needed tools are in `capability.ready` → skip to Step 4
- If tools are in `capability.unavailable` → proceed to Step 3

### Step 3: Install missing dependencies

**Preferred: use `--install-dependencies`** — installs tools into the `.codacy/` / `~/.codacy/` scope without affecting the rest of the machine:

```bash
codacy-analysis analyze --install-dependencies --output-format json
```

This installs missing tools and then runs analysis in a single command. The installed binaries go to `~/.codacy/` (machine-scoped, reused across repositories).

**Last resort: manual installation** — if `--install-dependencies` fails for a specific tool, install it manually on the machine (e.g., `brew install shellcheck`, `pip install ruff`). See [references/supported-tools.md](references/supported-tools.md) for tool details.

### Step 4: Run analysis

See [references/analysis-run.md](references/analysis-run.md) for detailed command options and workflows.

### Step 5: Interpret results

See [references/analysis-interpret.md](references/analysis-interpret.md) for details.

## Common workflows

See [references/analysis-workflows.md](references/analysis-workflows.md) for details.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The CLI is slow" | Better to wait for local results than to wait 10+ minutes for a CI failure. |
| "I'll just fix it later" | Unfixed quality gate failures compound technical debt and block others. |
| "It's a false positive" | Suppress it via CLI immediately so the quality gate passes and stays clean. |

## Red Flags

- [ ] Ignoring Codacy failures and pushing anyway.
- [ ] Suppressing issues as "FalsePositive" without verifying they actually are.
- [ ] Running `codacy-analysis analyze` without the `--pr` flag on a large codebase (may be slow).
- [ ] Using the issue `hash` for CLI suppressions (requires numeric `resultDataId`).

## See Also

- `codacy-cloud-cli` — Cloud Codacy CLI for remote data queries
- `static-analysis` — Generic linter triage across any language
- `code-review-assistant` — PR review workflow

## Troubleshooting

See [references/analysis-troubleshooting.md](references/analysis-troubleshooting.md) for details.
