# Automatic Documentation Syncing on Commit

## Implementation Summary

Created comprehensive automatic documentation syncing that triggers on every git commit, handling skill table updates, LLM context regeneration, agent registry sync, and documentation file synchronization.

## Files Created/Modified

### New Files

**`scripts/post-commit-docs-sync.sh`** - Main documentation sync orchestrator

```bash
#!/usr/bin/env bash
# Post-commit hook for automatic documentation syncing
# Integrates docs-hook skill with the git post-commit lifecycle

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
cd "$REPO_ROOT" || exit 1

# Configuration
DOCS_SYNC_ENABLED="${DOCS_SYNC_ENABLED:-true}"
DOCS_SYNC_QUIET="${DOCS_SYNC_QUIET:-false}"
DOCS_SYNC_LLM_TXT="${DOCS_SYNC_LLM_TXT:-true}"

# Skip if disabled
if [[ "$DOCS_SYNC_ENABLED" != "true" ]]; then
    exit 0
fi

# Get the previous commit hash
PREV_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "")

if [[ -z "$PREV_COMMIT" ]]; then
    exit 0
fi

# Get list of changed files between previous and current commit
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")

if [[ -z "$CHANGED_FILES" ]]; then
    exit 0
fi

# Track if any docs were updated
DOCS_UPDATED=false

# 1. Sync skill documentation if skills changed
if printf "%s\n" "$CHANGED_FILES" | grep -q -- ".agents/skills/"; then
    if [[ "$DOCS_SYNC_QUIET" != "true" ]]; then
        echo "Skills changed - updating documentation..."
    fi
    
    # Update AGENTS.md skill table
    if [[ -f "$REPO_ROOT/scripts/update-agents-md.sh" ]]; then
        "$REPO_ROOT/scripts/update-agents-md.sh" 2>/dev/null || true
        git add AGENTS.md 2>/dev/null || true
        DOCS_UPDATED=true
    fi
    
    # Update agents registry if agent configs changed
    if printf "%s\n" "$CHANGED_FILES" | grep -qE -- "\.(claude|opencode)/agents/"; then
        if [[ -f "$REPO_ROOT/scripts/update-agents-registry.sh" ]]; then
            "$REPO_ROOT/scripts/update-agents-registry.sh" 2>/dev/null || true
            git add agents-docs/AGENTS_REGISTRY.md 2>/dev/null || true
        fi
    fi
fi

# 2. Regenerate LLM context files if markdown changed
if [[ "$DOCS_SYNC_LLM_TXT" == "true" ]] && printf "%s\n" "$CHANGED_FILES" | grep -qE -- '\.(md|txt)$'; then
    if [[ "$DOCS_SYNC_QUIET" != "true" ]]; then
        echo "Documentation changed - regenerating LLM context files..."
    fi
    
    if [[ -f "$REPO_ROOT/scripts/generate-llms-txt.sh" ]]; then
        "$REPO_ROOT/scripts/generate-llms-txt.sh" 2>/dev/null || true
        git add llms.txt llms-full.txt 2>/dev/null || true
        DOCS_UPDATED=true
    fi
fi

# 3. Run docs-sync for lightweight file synchronization
if printf "%s\n" "$CHANGED_FILES" | grep -qE -- '\.(md)$'; then
    if [[ "$DOCS_SYNC_QUIET" != "true" ]]; then
        echo "Running docs sync..."
    fi
    
    if [[ -f "$REPO_ROOT/scripts/docs-sync.sh" ]]; then
        "$REPO_ROOT/scripts/docs-sync.sh" HEAD~1 HEAD 2>/dev/null || true
        DOCS_UPDATED=true
    fi
fi

# 4. Amend commit with updated docs if any were modified
if [[ "$DOCS_UPDATED" == "true" ]]; then
    if ! git diff --cached --quiet 2>/dev/null; then
        if [[ "$DOCS_SYNC_QUIET" != "true" ]]; then
            echo "Amending commit with updated documentation..."
        fi
        
        if ! git commit --amend --no-edit 2>/dev/null; then
            echo "Warning: Failed to amend commit with updated documentation" >&2
        fi
    fi
fi

exit 0
```

### Modified Files

**`scripts/install-hooks.sh`** - Updated post-commit hook to use new script

```bash
cat > "$HOOKS_DIR/post-commit" << 'HOOK'
#!/bin/bash
# Auto-update documentation when skills/agents change
# Runs after each commit to keep docs in sync
# Uses post-commit-docs-sync.sh for full documentation lifecycle

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
cd "$REPO_ROOT" || exit 1

# Delegate to the comprehensive docs sync script
exec "$REPO_ROOT/scripts/post-commit-docs-sync.sh"
HOOK
```

**`.agents/skills/docs-hook/SKILL.md`** - Updated skill documentation (v0.2.10 → v0.3.0)

## How It Works

### Sync Triggers

| File Pattern | Action |
|--------------|--------|
| `.agents/skills/**` | Update AGENTS.md skill table |
| `.claude/agents/**`, `.opencode/agents/**` | Update AGENTS_REGISTRY.md |
| `*.md`, `*.txt` | Regenerate llms.txt and llms-full.txt |
| `*.md` | Run docs-sync for file synchronization |

### Workflow

1. **Pre-commit**: Quality gate runs (existing)
2. **Commit**: User creates commit
3. **Post-commit**: `post-commit-docs-sync.sh` runs automatically
   - Detects changed files
   - Runs appropriate sync operations
   - Stages updated files
   - Amends commit with documentation changes

### Configuration

```bash
# Disable docs sync temporarily
DOCS_SYNC_ENABLED=false git commit -m "..."

# Suppress output
DOCS_SYNC_QUIET=true git commit -m "..."

# Skip LLM context regeneration
DOCS_SYNC_LLM_TXT=false git commit -m "..."
```

## Installation

```bash
# Install hooks (includes docs sync)
./scripts/install-hooks.sh

# Or manually add to .git/hooks/post-commit:
chmod +x scripts/post-commit-docs-sync.sh
echo '#!/bin/bash
exec "$(git rev-parse --show-toplevel)/scripts/post-commit-docs-sync.sh"' > .git/hooks/post-commit
chmod +x .git/hooks/post-commit
```

## Verification

```bash
# Test the script manually
./scripts/post-commit-docs-sync.sh

# Check hook is installed
ls -la .git/hooks/post-commit

# Verify sync works
touch .agents/skills/test-skill/SKILL.md
git add . && git commit -m "test: verify docs sync"
```

## Design Decisions

1. **Amend pattern**: Uses `git commit --amend --no-edit` to include doc updates in the same commit, maintaining atomic commits
2. **Graceful failures**: All sync operations use `|| true` to prevent hook failures from blocking commits
3. **Configuration via env vars**: Allows users to customize behavior without modifying scripts
4. **Integration with existing infrastructure**: Leverages `update-agents-md.sh`, `generate-llms-txt.sh`, and `docs-sync.sh`
5. **Quiet mode**: Supports CI environments where output should be suppressed
