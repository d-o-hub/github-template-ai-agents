**Status**: success
**Summary**: Found that the quality_gate.sh script uses a lint cache (`scripts/lib/lint_cache.sh`) that employs a timestamp-based fast-path which can incorrectly skip unchanged files when timestamps are not reliable, causing local failures while CI passes due to fresh clones.

## Analysis

The `quality_gate.sh` script itself does not directly detect changed files via git; instead, it runs linters on all matching files (shell and markdown) via `lint_batch_if_changed`. This function relies on a file‑hash cache stored in `.git/lint-cache/`. The cache uses a two‑level check:

1. **Fast‑path**: If the cache file is newer than the source file (`cache_key -nt file`), the file is skipped without computing a content hash.
2. **Slow‑path**: If the fast‑path fails, it computes a SHA‑256 hash of the file (and its config) and compares it to the stored hash.

## The Bug

The fast‑path timestamp comparison (`cache_key -nt file`) is **not reliable** in the following scenario:

- You have an existing lint cache from a previous run.
- You perform a git operation (e.g., `git checkout`, `git pull`, `git reset`) that updates file content but **does not update the file's modification timestamp** (which can happen with certain git operations or editors).
- The cache file remains newer than the source file (because the cache was created after the last modification timestamp).
- The fast‑path incorrectly assumes the file is unchanged and skips linting.
- If the file actually contains lint errors, the gate fails locally.
- In CI, there is no prior cache, so the slow‑path runs and correctly detects the lint error (or the error is not present because CI checks a different state).

## Why CI Passes

CI clones the repository fresh, so there is no stale lint cache. All files are linted via the slow‑path (content hash). If the file is clean, the gate passes. If the file has errors, CI would also fail—but the user reports CI passes, meaning the error is either not present in the CI checkout or the fast‑path is causing a false negative locally.

## Recommendation

The timestamp fast‑path should be removed or made conditional on a more reliable indicator (e.g., git status). Alternatively, the lint cache could store a git commit SHA or a content hash of the file list to detect changes. For immediate mitigation, you can delete the cache:

```bash
rm -rf .git/lint-cache/
```

or run `quality_gate.sh` with `SKIP_LINT_CACHE=1` if such an env var were supported.

## Files Touched
- `/workspaces/github-template-ai-agents/scripts/quality_gate.sh` (read)
- `/workspaces/github-template-ai-agents/scripts/lib/lint_cache.sh` (read)

## Findings Worth Promoting
- The lint cache's timestamp fast-path is fragile and can cause false negatives when timestamps are not updated after content changes.
- CI success vs local failure often indicates a cache or environment discrepancy; always consider caching layers when debugging.
- The `lint_batch_if_changed` function is the core of change detection in the quality gate—not git diff.