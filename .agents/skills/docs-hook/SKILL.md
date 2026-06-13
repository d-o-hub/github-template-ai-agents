---
name: docs-hook
version: "0.2.10"
description: Lightweight git hook integration for updating agents-docs with minimal tokens. Triggered on commit/merge events to sync documentation.
category: workflow
license: MIT
---

# Docs Hook

Ultra-lightweight documentation sync via git hooks.

## Trigger

- "git hook", "on commit", "pre-commit"
- "sync docs", "update docs"  
- "merge sync", "push docs"

## Usage

```bash
# After any commit that modifies .md files:
./scripts/docs-sync.sh HEAD~1 HEAD
```

Or add to `.git/hooks/post-commit`:

```bash
#!/bin/bash
./scripts/docs-sync.sh HEAD~1 HEAD
```

## Minimal Token Workflow

1. **Diff**: Get changed `.md` files between commits
2. **Sync**: Copy to target directory
3. **Done**: No ML, no logging, no metrics

## Working Script

See `scripts/docs-sync.sh` - the actual executable.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Docs can sync manually, no need for automation" | Manual sync is forgotten within days. Automation ensures consistency. |
| "The hook is slow, I'll skip it" | A few seconds of sync time prevents hours of out-of-date documentation debt. |
| "Only production docs need syncing" | Stale developer docs cause onboarding confusion and incorrect assumptions. |

## Red Flags

- [ ] Disabling the docs hook to speed up commits
- [ ] Manually copying docs instead of using the sync script
- [ ] Ignoring sync failures after documentation changes
