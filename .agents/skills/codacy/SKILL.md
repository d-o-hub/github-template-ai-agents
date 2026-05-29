---
name: codacy
version: 1.0.0
description: Orchestrate static analysis using Codacy CLIs. Use when Codacy blocks a PR, for fixing quality gate failures, or suppressing false positives across multi-language projects (Go, Rust, C, TS, etc.).
license: MIT
---

# Codacy Static Analysis

Use Codacy CLIs (Analysis CLI for local, Cloud CLI for remote) to maintain code quality and security standards across the entire codebase.

## When to Use

- When a PR is blocked by a Codacy quality gate.
- To triage and fix static analysis findings (Go, Rust, C, TypeScript, Shell, Markdown, etc.).
- To suppress false positives identified in the Codacy dashboard.
- To verify local changes before pushing (for supported tools).

## Do NOT Use

- For architectural changes or logic bugs not caught by static analysis.
- As the sole source of truth for language-specific deep analysis (e.g., local `cargo clippy` or `go vet` may be more precise).
- For local analysis of languages requiring complex runtimes not present in the environment.

## Installation & Auth

```bash
# Requires Node.js
npm i -g @codacy/analysis-cli @codacy/codacy-cloud-cli
export CODACY_API_TOKEN=<your-api-token>
```

## Workflows

### PR Triage

1. **Fetch Analysis**: `codacy pull-request gh <org> <repo> <prNumber> --output json > /tmp/codacy-pr.json`
2. **Review Issues**: Examine `newIssues` in the JSON. Note the `resultDataId` for any false positives.
3. **Suppress False Positives**: `codacy pull-request gh <org> <repo> <prNumber> --ignore-issue <resultDataId> --ignore-reason FalsePositive`

### Local Verification

```bash
# Initialize if missing
codacy-analysis init --default

# Run local analysis on current branch
codacy-analysis analyze --pr --output-format json
```

## Rationalizations

| Challenge | Rationale |
|-----------|-----------|
| "The CLI is slow" | Better to wait for local results than to wait 10+ minutes for a CI failure. |
| "I'll just fix it later" | Unfixed quality gate failures compound technical debt and block others. |
| "It's a false positive" | Suppress it via CLI immediately so the quality gate passes and stays clean. |

## Red Flags

- [ ] Ignoring Codacy failures and pushing anyway.
- [ ] Suppressing issues as "FalsePositive" without verifying they actually are.
- [ ] Running `codacy-analysis analyze` without the `--pr` flag on a large codebase (may be slow).
- [ ] Using the issue `hash` for CLI suppressions (requires numeric `resultDataId`).

## References

- `references/output-format.md` - JSON schema for PR analysis.
- `references/supported-tools.md` - Detailed tool availability for Go, Rust, C, TS, etc.
- `references/config-format.md` - .codacy.yml configuration syntax.
