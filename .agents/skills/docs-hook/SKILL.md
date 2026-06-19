---
name: docs-hook
version: "0.3.0"
description: Lightweight git hook integration for updating agents-docs with minimal tokens. Use this skill when updating agents-docs on commit or merge events to sync documentation — even if they just say "update the docs" or "sync the agent docs". Not for learn, agents-md.
category: workflow
license: MIT
---

# Docs Hook

Ultra-lightweight documentation sync via git hooks.

## When to Use

- User asks to update agents-docs on commit or merge events
- Need to sync documentation with minimal tokens
- Even if they just say "update the docs" or "sync the agent docs"

## Trigger

- "git hook", "on commit", "pre-commit"
- "sync docs", "update docs"  
- "merge sync", "push docs"

## Usage

```bash
# Full automatic sync (recommended):
./scripts/post-commit-docs-sync.sh

# Or use the lightweight docs-sync only:
./scripts/docs-sync.sh HEAD~1 HEAD
```

## Automatic Sync on Commit

The `post-commit-docs-sync.sh` script provides comprehensive documentation syncing:

1. **Skill table updates**: Regenerates AGENTS.md skill table when `.agents/skills/` changes
2. **LLM context regeneration**: Updates `llms.txt` and `llms-full.txt` when markdown changes
3. **Agent registry sync**: Updates `AGENTS_REGISTRY.md` when agent configs change
4. **Docs file sync**: Copies changed docs to appropriate directories
5. **Commit amendment**: Automatically amends commit with updated documentation

### Configuration

Environment variables control behavior:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCS_SYNC_ENABLED` | `true` | Enable/disable docs sync |
| `DOCS_SYNC_QUIET` | `false` | Suppress output messages |
| `DOCS_SYNC_LLM_TXT` | `true` | Regenerate LLM context files |

## Minimal Token Workflow

1. **Diff**: Get changed `.md` files between commits
2. **Sync**: Copy to target directory
3. **Done**: No ML, no logging, no metrics

## Working Scripts

- `scripts/post-commit-docs-sync.sh` - Full documentation sync orchestrator
- `scripts/docs-sync.sh` - Lightweight file synchronization only

## See Also

- `learn` — Extract learnings into AGENTS.md
- `agents-md` — AGENTS.md best practices

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
