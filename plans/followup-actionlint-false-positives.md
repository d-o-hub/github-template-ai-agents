# Follow-up: Actionlint False Positives

## Status: Pending (actionlint upstream issue)

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
