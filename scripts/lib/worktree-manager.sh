#!/usr/bin/env bash
# lib/worktree-manager.sh - Git worktree management functions
# Source this file from scripts that need worktree operations.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/worktree-manager.sh"

readonly WORKTREE_BASE="${WORKTREE_BASE:-.worktrees}"

# Track created worktrees for cleanup trap
CREATED_WORKTREES=()

# Cleanup trap function - call from trap in main script
cleanup_worktrees() {
    for wt in "${CREATED_WORKTREES[@]}"; do
        # Security: Use --porcelain and grep -x -F for exact literal matching of worktree paths.
        # This prevents false positives from overlapping paths (e.g., /app matching /app-2).
        if git worktree list --porcelain 2>/dev/null | grep -x -F -q -- "worktree ${wt}"; then
            git worktree remove --force -- "$wt" 2>/dev/null || true
        fi
    done
    return 0
}

setup_worktree() {
    local branch_name="$1"
    local worktree_path="${WORKTREE_BASE}/${branch_name}"

    mkdir -p -- "$WORKTREE_BASE"

    # Security: Use --porcelain and grep -x -F for exact literal matching of worktree paths.
    if git worktree list --porcelain 2>/dev/null | grep -x -F -q -- "worktree ${worktree_path}"; then
        git worktree remove --force -- "$worktree_path" 2>/dev/null || true
    fi

    if git rev-parse --verify --quiet "refs/heads/$branch_name" >/dev/null; then
        git worktree add -- "$worktree_path" "$branch_name"
    else
        git worktree add -b "$branch_name" -- "$worktree_path" main
    fi

    CREATED_WORKTREES+=("$worktree_path")
    printf "%s\n" "$worktree_path"
}

cleanup_worktree() {
    local worktree_path="$1"
    # Security: Use --porcelain and grep -x -F for exact literal matching of worktree paths.
    if git worktree list --porcelain 2>/dev/null | grep -x -F -q -- "worktree ${worktree_path}"; then
        git worktree remove --force -- "${worktree_path}" 2>/dev/null || {
            local resolved
            resolved=$(realpath -m -- "$worktree_path" 2>/dev/null || printf "%s\n" "$worktree_path")

            if [[ -z "$resolved" ]] || [[ "$resolved" == "/" ]] || [[ "$resolved" == "." ]] || [[ "$resolved" == "~" ]]; then
                printf "Error: Dangerous or invalid worktree_path: %s\n" "$worktree_path" >&2
                exit 1
            fi

            # Resides under WORKTREE_BASE
            local base_resolved
            base_resolved=$(realpath -m -- "$WORKTREE_BASE" 2>/dev/null || printf "%s\n" "$WORKTREE_BASE")
            if [[ "$resolved/" != "$base_resolved/"* ]]; then
                printf "Error: worktree_path %s is not under %s\n" "$resolved" "$base_resolved" >&2
                exit 1
            fi

            rm -rf -- "$resolved"
            git worktree prune
        }
    fi
}
