**Status**: success
**Summary**: Found the bug — `quality_gate.sh` never uses `git diff` to detect changed files; it uses `find` to discover ALL files and relies on a content-hash cache, while CI uses `dorny/paths-filter` for proper git-based change detection.

## Analysis

### Where the script identifies which files to check

There are two layers:

1. **`quality_gate.sh` lines 293, 299, 380, 400** — Uses `find` commands to discover ALL `.sh` and `.md` files:

```bash
# Shell (line 380):
find . -name "*.sh" -not -path "$GIT_EXCLUDE" -not -path "./target/*" -print0

# Markdown (line 400):
find . -name "*.md" -not -path "*/node_modules/*" -not -path "./target/*" -not -path "$GIT_EXCLUDE" -not -path "./vendor/*" -print0
```

2. **`scripts/lib/lint_cache.sh` `lint_batch_if_changed()` (line 141)** — Takes the full file list and uses a content-hash cache (`.git/lint-cache/`) to skip files whose SHA-256 hash hasn't changed since the last lint run.

### What's wrong

**The script never runs `git diff` to detect changed files.** It processes ALL files of each type every time. The `lint_batch_if_changed` name is misleading — it's a performance optimization cache, not a git-change filter.

In contrast, the CI workflow (`ci.yml` lines 33-61) uses `dorny/paths-filter` which properly detects changed files via `git diff`:

```yaml
- uses: dorny/paths-filter@...
  with:
    filters: |
      code:
        - '**/*.sh'
        - '**/*.md'
        # ...
```

CI then conditionally runs the quality gate based on whether relevant files actually changed. But even when it runs, the quality gate checks ALL files — the `dorny/paths-filter` only gates whether the quality gate runs at all, not which files it checks.

### Why this causes local failure / CI pass

1. **CI skips the gate entirely** — `dorny/paths-filter` may determine no relevant files changed, so the quality gate job is skipped (lines 68-72 of `ci.yml`). The job appears to "pass" because it never ran.

2. **Stale cache divergence** — Locally, the lint cache in `.git/lint-cache/` may have stale entries. The fast-path check (line 71 of `lint_cache.sh`) compares file modification time vs cache time. If the cache was created before your current changes, it may incorrectly skip files that should be re-linted. Conversely, on CI with a fresh clone, there's no cache and everything gets linted.

3. **Missing `SKIP_GLOBAL_HOOKS_CHECK`** — CI sets `SKIP_GLOBAL_HOOKS_CHECK=true` (ci.yml line 179). The pre-commit hook does NOT propagate this to `quality_gate.sh` (pre-commit-hook.sh line 34 calls quality_gate.sh without the env var). So locally, `validate-git-hooks.sh` runs and may fail, while CI skips it entirely.

### The core bug

`quality_gate.sh` does not scope its checks to changed files. It should use `git diff --name-only HEAD` (or `git diff --cached --name-only` in the pre-commit context) to determine which files to lint, rather than using `find` to discover all files. The CI's `dorny/paths-filter` provides change detection but is disconnected from the quality gate's actual file processing logic.

**Files touched**: scripts/quality_gate.sh, scripts/lib/lint_cache.sh, .github/workflows/ci.yml
**Findings worth promoting**:
- `lint_batch_if_changed` is a content-hash cache, not a git-change filter — its name is misleading
- CI uses `dorny/paths-filter` for change detection, but the quality gate ignores it when processing files
- The pre-commit hook doesn't propagate `SKIP_GLOBAL_HOOKS_CHECK` to quality_gate.sh, causing hooks validation to run locally but not in CI
