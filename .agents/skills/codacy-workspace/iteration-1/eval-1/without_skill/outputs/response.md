# Codacy-Style Code Analysis Report

**Repository**: `github-template-ai-agents`
**Date**: 2026-06-19
**Analysis Tools**: Ruff (Python linting), Bandit (Python security), ShellCheck (shell linting)
**Total Lines of Code Scanned**: 9,023 (Python)
**Note**: Codacy CLI requires authentication tokens for remote configuration. This report uses the equivalent local tools configured in `.codacy.yml`.

---

## Summary

| Category | Tool | Issues | Severity Breakdown |
|----------|------|--------|--------------------|
| Python Linting | Ruff | 55 | N/A (style/quality) |
| Security | Bandit | 409 | Low: 408, Medium: 1 |
| Shell Linting | ShellCheck | 117 | Warning: 40, Info: 77 |
| **Total** | | **581** | |

### Repository Composition

| File Type | Count |
|-----------|-------|
| Python (.py) | 84 |
| Shell (.sh) | 82 |
| YAML (.yml) | 36 |
| Markdown (.md) | 394 |

---

## 1. Python Linting (Ruff)

**Total Issues**: 55 across 22 files

### Issues by Rule

| Rule | Count | Description |
|------|-------|-------------|
| E501 | 16 | Line too long (>88 chars) |
| E702 | 12 | Multiple statements on one line (semicolon) |
| F401 | 10 | Module imported but unused |
| I001 | 5 | Import block is un-sorted or un-formatted |
| E701 | 4 | Multiple statements on one line (colon) |
| F541 | 3 | f-string without placeholders |
| F821 | 3 | Undefined name |
| E402 | 2 | Module level import not at top of file |

### Most Affected Files

| Issues | File |
|--------|------|
| 12 | `.agents/skills/codeberg-api/scripts/forgejo_api.py` |
| 6 | `.agents/skills/do-web-doc-resolver/scripts/synthesis.py` |
| 5 | `.agents/skills/do-web-doc-resolver/tests/test_resolve.py` |
| 4 | `.agents/skills/accessibility-auditor/scripts/verify_accessibility.py` |
| 4 | `.agents/skills/ui-ux-optimize/scripts/verify.py` |
| 4 | `tests/test_run_evals.py` |
| 3 | `tests/verify_optional_skills.py` |
| 2 | `.agents/skills/do-web-doc-resolver/scripts/docs_validation.py` |
| 2 | `.agents/skills/do-web-doc-resolver/scripts/providers/docling.py` |
| 1 | `.agents/skills/do-web-doc-resolver/scripts/_query_resolve.py` |

### Key Findings

**Unused Imports (F401) - 10 issues:**
- `verify_accessibility.py`: `json` and `typing.Tuple` imported but unused
- Various test files importing unused fixtures

**Multiple Statements on One Line (E702) - 12 issues:**
- All in `.agents/skills/codeberg-api/scripts/forgejo_api.py` (lines 147, 150-156)

**Undefined Names (F821) - 3 issues:**
- Requires investigation for potential runtime errors

---

## 2. Security Analysis (Bandit)

**Total Issues**: 409 (Low: 408, Medium: 1)
**Confidence**: High: 406, Medium: 3

### Issues by Test ID (non-test files only)

| Test ID | Severity | Confidence | Count | Description |
|---------|----------|------------|-------|-------------|
| B101 | Low | High | 390 | `assert` used in test files (false positives in pytest) |
| B404 | Low | High | 3 | Import of `subprocess` module |
| B603 | Low | High | 10 | `subprocess` call without `shell=True` |
| B607 | Low | High | 2 | Starting process with partial path |
| B108 | Medium | Medium | 1 | Hardcoded `/tmp` directory usage |
| B105 | Low | Medium | 1 | Possible hardcoded password (false positive on `'PASS'` enum) |

### Non-Test File Security Findings

| File | Line | Test ID | Severity | Issue |
|------|------|---------|----------|-------|
| `.agents/skills/github-pr-sentinel/scripts/gh_pr_watch.py` | 265 | B108 | Medium | Probable insecure usage of temp file/directory (`/tmp/pr-sentinel-...`) |
| `.agents/skills/skill-creator/scripts/run_loop.py` | 139 | B607 | Low | Starting process with partial executable path (`claude`) |
| `.agents/skills/skill-creator/scripts/run_loop.py` | 139 | B603 | Low | subprocess call - check for execution of untrusted input |
| `.agents/skills/github-pr-sentinel/scripts/gh_pr_watch.py` | 118 | B603 | Low | subprocess call - check for execution of untrusted input |
| `scripts/lib/eval_executors.py` | 37 | B603 | Low | subprocess call - check for execution of untrusted input |

### Assessment

The vast majority of Bandit findings (390/409) are **B101 (assert used)** in test files — these are **false positives** in the context of pytest, where `assert` is the canonical assertion mechanism. The `.codacy.yml` correctly excludes `**/tests/**` from bandit scanning to address this.

The single **Medium severity** finding (B108) in `gh_pr_watch.py:265` uses a predictable `/tmp` path pattern. Consider using `tempfile.mkdtemp()` for better security.

---

## 3. Shell Linting (ShellCheck)

**Total Issues**: 117 (Warning: 40, Info: 77)

### Issues by Warning Code

| Code | Severity | Count | Description |
|------|----------|-------|-------------|
| SC2034 | Warning | ~15 | Variable appears unused |
| SC2059 | Info | ~15 | Don't use variables in printf format string |
| SC2016 | Info | ~10 | Expressions don't expand in single quotes |
| SC2030 | Info | ~5 | Modification is local to subshell |
| SC2031 | Info | ~5 | Variable modified in subshell, change might be lost |

### Most Affected Files

| File | Issues |
|------|--------|
| `tests/test-llms-txt-generation.sh` | ~30 |
| `tests/verify-version-logic.sh` | ~10 |
| Various scripts in `.agents/skills/` | ~77 |

### Key Findings

- **Unused variables (SC2034)**: Common in test scripts where variables are defined for use in subshells
- **Printf format issues (SC2059)**: Variables used directly in printf format strings instead of as arguments
- **Subshell modifications (SC2030/SC2031)**: Variables modified in `()` subshells don't persist — likely intentional in test scripts

---

## 4. Recommendations

### High Priority
1. **Fix F821 (Undefined Names)**: 3 instances may cause runtime errors
2. **Investigate B108 (Hardcoded /tmp)**: Use `tempfile` module for secure temp file creation in `gh_pr_watch.py`

### Medium Priority
1. **Remove unused imports (F401)**: 10 instances across accessibility-auditor and other skills
2. **Fix E702 (Multiple statements)**: 12 instances in `forgejo_api.py` — split onto separate lines

### Low Priority
1. **Long lines (E501)**: 16 instances — format or restructure
2. **Shell script cleanup (SC2034/SC2059)**: Address warnings in test scripts

### Already Well-Handled
- B101 (assert in tests): Excluded via `.codacy.yml` — no action needed
- Import ordering (I001): Auto-fixable with `ruff check --fix`

---

## 5. Quality Metrics

| Metric | Value | Status |
|--------|-------|--------|
| Python issues per 1000 LOC | 6.1 | Moderate |
| Security issues (non-test, non-low) | 1 | Good |
| Shell warnings | 40 | Moderate |
| Files with issues (Python) | 22/84 (26%) | Acceptable |

### Overall Assessment

The codebase shows **good security hygiene** with only 1 medium-severity finding and no high-severity issues. Python code quality is moderate with mostly style issues (line length, import ordering) that are auto-fixable. Shell scripts have a moderate number of warnings, mostly in test files.
