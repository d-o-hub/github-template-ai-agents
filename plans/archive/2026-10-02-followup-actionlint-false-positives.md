# Follow-up: Actionlint False Positives

## Status: Resolved (verified 2026-10-02, ADR-042)

Both findings are non-blocking in CI, which settles this without an upstream
change. Archived rather than deleted per ADR-042 decision 5.

Evidence, re-checked 2026-10-02:

- `.github/workflows/dedup-issues.yml:17` still declares `models: read`.
- `.github/workflows/yaml-lint.yml:50-60` runs `reviewdog/action-actionlint`
  pinned at `2085657ab2c7f48c58edcc767fba576f63bea76b` (`# v1.77.0`) with
  `fail_level: error`, `filter_mode: nofilter`.
- Every `YAML Lint` run on `main` is green (runs 37006924167, 37000623655,
  36996361732), so the pinned action accepts the `models` scope.
- Local `actionlint` 1.6.26 still reports `unknown permission scope "models"`,
  which is why this plan looked open: the local binary is older than the one
  CI runs. The upstream issue is therefore moot for this repository.

## Problem

`GitHub Actions Workflow Validation` CI check uses `reviewdog/action-actionlint` which runs actionlint on all workflow files. Two files produce findings that are false positives or actionlint limitations:

### 1. `dedup-issues.yml` — Unknown permission scope `models`

```
permissions:
  models: read  # GitHub Models — FREE for public repos
```

actionlint reports: `unknown permission scope "models"`. This is a valid GitHub permission scope for GitHub Models (AI inference API). actionlint hasn't been updated to recognize it yet.

**Resolution**: Wait for actionlint to add `models` to its known permission scopes. No code change needed.

### 2. `security-scan.yml` — SC2016 info-level warning

Shellcheck reports `SC2016:info` about expressions not expanding in single quotes. This is informational (not an error) and the single quotes are intentional.

**Resolution**: No change needed. The check uses `fail_level: error` so info-level findings shouldn't fail the check.

## What Was Fixed (in this PR)

- `metrics-conflict-resolver.yml`: Fixed 3 double-quote expression errors, 4 printf format string errors, and 2 obfuscated command errors. Verified clean with local actionlint.

## Next Steps

1. Monitor actionlint releases for `models` permission scope support
2. Once actionlint recognizes `models`, the `GitHub Actions Workflow Validation` check should pass cleanly
3. If needed, file an issue at <https://github.com/rhysd/actionlint/issues> to request `models` permission scope support
