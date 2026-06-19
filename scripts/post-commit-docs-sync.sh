#!/usr/bin/env bash
# Post-commit hook for automatic documentation syncing
# Integrates docs-hook skill with the git post-commit lifecycle
# Usage: Add to .git/hooks/post-commit or run via install-hooks.sh

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
    # First commit - skip (nothing to diff against)
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
    # Check if there are actually staged changes to amend
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
