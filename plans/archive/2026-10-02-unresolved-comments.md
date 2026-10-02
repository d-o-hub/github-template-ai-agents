# Unresolved Review Comments

> **Archived 2026-10-02 (ADR-042).** Review threads from PRs #362/#363/#368
> (May 2026). Nothing here is outstanding: the one item marked DEFERRED —
> `scripts/validate-links.sh` on empty input — is closed in
> [`../pre-existing-issues.md`](../pre-existing-issues.md) under *Open /
> deferred → validate-links empty / malformed input*, re-verified 2026-09-27
> (no `read` loops remain; the run exits 0 over 88 files and 313 links). Kept
> for history per ADR-042 decision 5.

## PR #368 - Sentinel Hardening

### tests/test-security-fixes.sh Missing from Diff

**Status:** File IS present on the PR branch but was not visible at review time.
**Action:** No change needed. File is included in the squashed commit.

### scripts/validate-links.sh May Hang on Empty Input

**Status:** DEFERRED
**Reason:** This is a pre-existing issue in the script's design. The `while IFS= read -r line` loop reading from a file would simply not execute if the file is empty — bash `read` returns non-zero on EOF, so the loop body would be skipped. However, the concern about hanging could apply in edge cases with stdin redirection. This is not introduced by this PR and requires separate investigation.
**Recommendation:** File a follow-up issue to investigate validate-links.sh behavior with empty/malformed input.

## PR #363 - Dependabot Updates

### Dependabot Changes Discarded

**Status:** INTENTIONAL
**Reason:** The original Dependabot PR updated codeql-action from v4.35.5 to v4.36.0 and actions/stale from v10.2.0 to v10.3.0. However, main branch had already moved codeql-action to v3 (a completely different SHA) since the PR was created. The Dependabot changes were stale and could not be applied to current main. Only the applicable SARIF JSON and category fixes were retained.
**Recommendation:** Close this PR and let Dependabot create a fresh PR against current main.

### Category Format

**Status:** FIXED
**Action:** Changed to standard CodeQL format in the empty SARIF upload. The "Perform CodeQL Analysis" step also updated.
