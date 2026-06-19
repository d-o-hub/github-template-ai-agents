# Triage Mixed Python/Shell Findings in a Single Pass

## The Problem

You have a PR with both ruff (Python) and shellcheck (Shell) findings from Codacy, and you want to triage them in one session without context-switching.

## Solution: Unified Triaging Strategy

### Step 1: Aggregate Findings Locally

Run both linters in sequence and pipe output to a single review point:

```bash
# Python findings
ruff check . --output-format=json > /tmp/ruff.json

# Shell findings
shellcheck scripts/*.sh --format=json > /tmp/shellcheck.json
```

Alternatively, for inline review:

```bash
ruff check . && shellcheck scripts/*.sh
```

### Step 2: Classify by Severity (Not Language)

Sort all findings into three buckets regardless of source:

1. **Blocking errors** — Syntax issues, undefined variables, shellcheck SC2xxx errors that indicate real bugs
2. **Warnings** — Style violations, unused imports, minor shell style issues
3. **Informational** — Suggestions, best-practice hints

### Step 3: Batch Fixes by Type

Group fixes to minimize context switching:

- **Formatting issues** (both languages): Apply auto-fixers first
  - `ruff check . --fix`
  - `shfmt -w scripts/*.sh` (if applicable)
- **Unused variables**: Fix across both languages in one pass
- **Complex findings**: Document with issue trackers if non-trivial

### Step 4: Codacy CLI Triage

Use the Codacy CLI to batch-suppress false positives without leaving your terminal:

```bash
# Fetch PR findings
codacy pull-request

# Or query the dashboard
codacy-analysis-cli analyze --project-token <token>
```

## Key Insight

The languages don't matter — triage by severity and fixability. A shellcheck "undefined variable" is the same class of problem as a ruff "undefined name". Group by action, not by language.

## Red Flags to Avoid

- Suppressing errors without documenting why
- Only fixing one language's findings and leaving the other
- Mixing auto-fixable and manual findings in the same commit (separate them)

## See Also

- `static-analysis` skill — Full triage workflow
- `codacy` skill — Local CLI for Codacy integration
- `code-review-assistant` — PR review with code smell detection