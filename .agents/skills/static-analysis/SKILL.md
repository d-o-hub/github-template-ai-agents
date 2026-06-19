---
name: static-analysis
version: 1.0.0
category: code-quality
description: Triage and fix static analysis findings across any programming language. Use this skill when running linters (ruff, eslint, clippy, shellcheck), analyzing lint output, fixing warnings or errors, or managing cross-language static analysis results in a project — even if they just say "run the linter" or "fix the lint warnings". Trigger on "lint", "static analysis", "triage warnings", "fix findings". Not for code-review-assistant, security-code-auditor.
license: MIT
---

# Static Analysis & Linter Triage

Expert skill for managing static analysis, PR triage, and linting feedback loops across any programming language.

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

## Codacy Integration

If `codacy.yml` or a Codacy project exists:

1. **Read PR Comments**: Codacy posts findings as PR comments. Treat these as blocking if they are categorized as "Issues".
2. **Triage via CLI**: Use `codacy pull-request` to fetch and ignore false positives if the dashboard is not accessible.
3. **Configuration**: Check `.codacy.yml` in the root for project-specific rules.

## Suppression Guidelines

When suppressing a linter finding (e.g., via `eslint-disable`, `noqa`, or `# shellcheck disable`), you **MUST** include a comment in the following format:

`[tool-disable] <rule-id>: <reason> -- <agent-id> (<date>)`

**Example:**

```bash
# shellcheck disable=SC2034: Variable is used in sourced lib -- Jules (2025-05-15)
UNUSED_VAR="internal"
```

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Linting slows me down" | Automated linting prevents 80% of trivial PR feedback, saving time in the long run. |
| "It's just a warning" | Warnings today are bugs tomorrow. Fixing them early maintains a "broken window" free codebase. |
| "I'll fix it in the next PR" | Technical debt starts with a single "I'll fix it later." Fix it now while the context is fresh. |

## Red Flags

- [ ] Suppressing lint errors without a documented reason.
- [ ] Pushing code that fails local `./scripts/quality_gate.sh`.
- [ ] Ignoring "style" findings that affect readability (e.g., inconsistent naming).
- [ ] Manually fixing formatting instead of using automated tools.

## See Also

- `code-review-assistant` — PR review workflow with code smell detection
- `codacy` — Local Codacy Analysis CLI for static analysis
- `codacy-cloud-cli` — Cloud Codacy CLI for remote data queries
