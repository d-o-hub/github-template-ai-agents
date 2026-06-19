# Triage Ruff + ShellCheck Findings in a Single Pass

## The Problem

Codacy flags ruff findings in `.py` files and shellcheck findings in `.sh` files on the same PR. You need to triage both without context-switching.

## Single-Pass Triage Workflow

### 1. Local Pre-Commit: Run Both Linters Against Changed Files

Before pushing, detect which files changed and run the matching linters in one pass:

```bash
# Detect changed files
CHANGED_PY=$(git diff --name-only --diff-filter=ACM HEAD | grep '\.py$')
CHANGED_SH=$(git diff --name-only --diff-filter=ACM HEAD | grep '\.sh$')

# Run both linters, capture output
if [ -n "$CHANGED_PY" ]; then
  ruff check $CHANGED_PY 2>&1 | tee /tmp/ruff-results.txt
fi

if [ -n "$CHANGED_SH" ]; then
  shellcheck $CHANGED_SH 2>&1 | tee /tmp/shellcheck-results.txt
fi
```

### 2. Classify Findings by Severity (Cross-Language)

Apply the same triage logic from the skill regardless of language:

| Severity | Action |
|----------|--------|
| **Error** | Fix immediately or suppress with documented reason. Blocks merge. |
| **Warning** | Fix if possible. File follow-up issue if architectural. |

For ruff, severity maps to rule categories:
- `E` (Error rules) and `F` (Fatal/pyflakes) = Error severity
- `W` (Warning) and `I` (Import sorting) = Warning severity, auto-fixable

For shellcheck, severity maps to SC code ranges:
- `SC2xxx` errors = Error severity
- `SC2xxx` warnings/info = Warning severity, often auto-fixable

### 3. Auto-Fix Safe Findings (Both Languages)

Run both auto-fixers in sequence — no context switch needed:

```bash
# Python: auto-fix import sorting, formatting
if [ -n "$CHANGED_PY" ]; then
  ruff check --fix $CHANGED_PY
fi

# Shell: no built-in auto-fix, but shellcheck output can guide manual fixes
# Group shellcheck findings by rule for batch fixes
if [ -n "$CHANGED_SH" ]; then
  shellcheck -f gcc $CHANGED_SH | awk -F: '{print $4}' | sort | uniq -c | sort -rn
fi
```

### 4. Handle Complex Findings

For findings that require architectural changes (e.g., a shellcheck finding about unquoted variables in a pipeline that needs restructuring, or a ruff `C901` complexity warning), file a follow-up issue and document the tech debt. Do not suppress without a reason.

### 5. Suppressions

When suppressing across both languages, use the required format:

```bash
# shellcheck disable=SC2086: Intentional word splitting for glob expansion -- agent (2026-06-18)
```

```python
# noqa: E501: Long lines are config constants, not logic -- agent (2026-06-18)
LONG_SETTING = "..."
```

### 6. Codacy PR Triage

When reviewing Codacy PR annotations that mix both languages:

1. Read PR comments — Codacy posts findings as PR comments, treat as blocking if categorized as "Issues".
2. Use `codacy pull-request` CLI to fetch findings without leaving the terminal.
3. Group findings by language, then by severity, then fix in order: errors first, auto-fixable warnings second, architectural issues last.

## Quality Gate Check

Run the project quality gate before pushing to confirm all findings are addressed:

```bash
./scripts/quality_gate.sh
```

## Summary

The key insight is that triage classification (Error vs Warning) and the fix workflow (auto-fix safe issues, suppress with reason, file issues for complex ones) are **language-agnostic**. You apply the same decision tree to both ruff and shellcheck output. Run both linters locally before pushing, classify by severity not by language, and handle fixes in priority order.
