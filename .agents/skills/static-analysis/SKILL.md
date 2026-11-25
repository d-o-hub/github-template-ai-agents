---
name: static-analysis
version: 1.1.0
category: code-quality
description: Triage and fix static analysis findings across any programming language, including Codacy local analysis and Codacy Cloud queries. Use this skill when running linters (ruff, eslint, clippy, shellcheck), running the Codacy Analysis CLI on staged or PR-scoped changes, or querying Codacy Cloud for remote issues, security findings, and PR results — even if they just say "run the linter", "fix the lint warnings", or "triage the Codacy findings". Trigger on "lint", "static analysis", "triage warnings", "fix findings". Not for code-review-assistant, security-code-auditor.
license: MIT
metadata:
  author: opencode
  lastUpdated: "2026-11-25"
---

# Static Analysis & Linter Triage

Expert skill for managing static analysis, PR triage, and linting feedback loops across any programming language — including the Codacy CLI surface absorbed from the retired codacy skill (ADR-038).

## Quick Check

- [ ] Run pre-commit linters locally
- [ ] Classify CI lint failures by severity
- [ ] Auto-fix safe style/formatting issues
- [ ] Document every suppression with a valid reason
- [ ] File issues for complex architectural findings

## When to Use

- Before committing changes (local linting).
- When CI quality gates or linting workflows fail.
- During PR reviews to triage static analysis findings.
- When integrating new languages or linters into a project.
- Running Codacy analysis locally, or querying Codacy Cloud for issues, security findings, or PR quality data.

## Pre-commit Workflow

Always run local linters before pushing to minimize CI round-trips.

1. **Detect Changes**: Identify files modified in the current session.
2. **Run Targeted Linters**: Use tools like `markdownlint`, `shellcheck`, or language-specific linters (e.g., `eslint`, `ruff`) on changed files.
3. **Verify Quality Gate**: Run `./scripts/quality_gate.sh` (if available) to ensure all local checks pass.

## CI Integration

Read linter output from CI artifacts and PR annotations to identify regressions.

- **Check CI Summary**: Read `ci-summary.md` or GitHub Action logs.
- **Inspect Annotations**: Look for line-specific comments from automated tools (Codacy, SonarCloud, GitHub Actions).
- **Match to Source**: Map CI errors back to local files and line numbers.

## Agent Triage Workflow

Follow this structured process when responding to analysis findings:

1. **Classify Severity**:
   - **Error**: Must be fixed or formally suppressed. Blocks merge.
   - **Warning**: Should be fixed if possible. Indicates potential future issues.
2. **Auto-fix Safe Findings**:
   - Immediately apply automated fixes for formatting (Prettier, `gofmt`), imports (`ruff`, `isort`), or simple style rules.
3. **Handle Complex Findings**:
   - If a fix is non-trivial or requires architectural changes, file a follow-up issue and document the technical debt.
4. **Suppressions**:
   - Never suppress an error without documenting *why*.
   - Use the [Required Comment Format](#suppression-guidelines).

## Linter Tool Registry

| Language/Type | Recommended Linter | Local Command |
|---------------|-------------------|---------------|
| **Markdown** | `markdownlint-cli2` | `npx markdownlint-cli2 "**/*.md"` |
| **Shell** | `shellcheck` | `shellcheck scripts/*.sh` |
| **JS / TS** | `eslint` | `npm run lint` or `npx eslint .` |
| **Python** | `ruff` | `ruff check .` |
| **Rust** | `clippy` | `cargo clippy` |
| **Go** | `golangci-lint` | `golangci-lint run` |
| **Secrets** | `gitleaks` | `gitleaks detect --source . -v` |

## Codacy Git-Aware Analysis

Use the Codacy Analysis CLI for targeted pre-commit and PR-scoped analysis (full CLI surface — install, auth, exit codes, cloud-vs-local division — lives in [references/codacy-cli.md](references/codacy-cli.md), absorbed from the codacy skill):

```bash
# Pre-commit: analyze only staged files
codacy-analysis analyze --staged --output-format json

# Branch analysis: all changes vs merge base
codacy-analysis analyze --diff --output-format json

# PR analysis: changes vs PR target branch
codacy-analysis analyze --pr --output-format json

# Combine with specific tools
codacy-analysis analyze --staged --tool Ruff --tool ESLint9 --output-format json
```

**When to use:**
- `--staged` — Before committing; catches issues in exactly the code you're about to commit
- `--diff` — During development; sees all uncommitted + committed changes on the branch
- `--pr` — During PR review; compares against the PR's target branch

Parse results with jq for triage:

```bash
# Count issues by severity
codacy-analysis analyze --staged --output-format json | jq '.issues | group_by(.severity) | map({severity: .[0].severity, count: length})'

# Get critical/high only
codacy-analysis analyze --staged --output-format json | jq '[.issues[] | select(.severity == "Error" or .severity == "High")]'
```

## Codacy Cloud & PR Integration

The Codacy CLI reference (absorbed from codacy, per ADR-038) covers cloud queries: repository reanalysis, issue and security-finding lists, PR summaries with quality gate and coverage deltas, pattern enable/disable, and config import.

- **Read PR Comments**: Codacy posts findings as PR comments. Treat these as blocking if they are categorized as "Issues".
- **Triage via CLI**: fetch PR data and ignore false positives with the Cloud CLI; CLI ignores require the numeric `resultDataId`, never the issue `hash`.
- **Cloud data lags HEAD**: issue lists, coverage, and findings reflect the last analyzed commit; configuration changes apply only after reanalysis (`--reanalyze-and-wait`).
- **Configuration**: check the repo's Codacy YAML config for project-specific rules; local config reaches the cloud only through the documented import flow.

## Suppression Guidelines

When suppressing a linter finding (e.g., via `eslint-disable`, `noqa`, or `# shellcheck disable`), you **MUST** include a comment in the following format:

`[tool-disable] <rule-id>: <reason> -- <agent-id> (<date>)`

**Example:**

```bash
# shellcheck disable=SC2034: Variable is used in sourced lib -- Jules (2026-11-25)
UNUSED_VAR="internal"
```

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Linting slows me down" | Automated linting prevents 80% of trivial PR feedback, saving time in the long run. |
| "It's just a warning" | Warnings today are bugs tomorrow. Fixing them early maintains a "broken window" free codebase. |
| "I'll fix it in the next PR" | Technical debt starts with a single "I'll fix it later." Fix it now while the context is fresh. |
| "The CLI is slow" — better to wait for a dashboard | Local CLI results beat waiting 10+ minutes for a CI failure; the CLI is also scriptable. (absorbed from codacy) |

## Red Flags

- [ ] Suppressing lint errors without a documented reason.
- [ ] Pushing code that fails local `./scripts/quality_gate.sh`.
- [ ] Ignoring "style" findings that affect readability (e.g., inconsistent naming).
- [ ] Manually fixing formatting instead of using automated tools.
- [ ] Suppressing issues as "FalsePositive" without verifying they actually are. (absorbed from codacy)
- [ ] Using the issue `hash` for CLI suppressions instead of the numeric `resultDataId`. (absorbed from codacy)
- [ ] Assuming Codacy configuration changes take effect immediately without reanalysis. (absorbed from codacy)
- [ ] Running full-repo analysis where `--staged`/`--pr` scoping would do. (absorbed from codacy)

## See Also

- `code-review-assistant` — PR review workflow with code smell detection
- Codacy CLI usage — [references/codacy-cli.md](references/codacy-cli.md) (absorbed from codacy, per ADR-038)

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
