#!/usr/bin/env bash
# lib/phase-commit.sh - Phase 1 ATOMIC COMMIT agent function for the Git-GitHub
# workflow skill. Sourced by ../../run.sh.
# shellcheck disable=SC2086,SC2154,SC2164
# Verbatim phase code from the former single-file run.sh. The sourcing run.sh
# defines the config/state globals, logging helpers, readonly error codes, and
# the strict shell options used below; that cross-file contract is invisible
# here, so SC2154 (never-assigned globals), SC2086 (unquoted expansions of
# those readonly constants), and SC2164 (cd guarded by the caller's errexit)
# are suppressed with this documented reason.
# Agent 1: ATOMIC COMMIT
agent_commit() {
    agent "AGENT 1: ATOMIC COMMIT"
    log "═══════════════════════════════════════════════════════════════════"
    
    cd "$REPO_ROOT"
    
    # Check git status
    if ! git rev-parse --git-dir &>/dev/null; then
        error "Not a git repository"
        return $E_COMMIT_FAILED
    fi
    
    # Check for changes
    if [[ -z $(git status --porcelain) ]]; then
        error "No changes to commit"
        return $E_COMMIT_FAILED
    fi
    
    # Generate branch name
    local timestamp=$(date +%s)
    if [[ -z "$MESSAGE" ]]; then
        local changed_files=$(git status --porcelain | grep '^[AM]' | awk '{print $2}' | head -3 | tr '\n' ', ' | sed 's/,$//')
        MESSAGE="workflow: update ${changed_files:-files}"
    fi
    
    # Detect type from message
    local type=$(echo "$MESSAGE" | grep -oE '^(feat|fix|docs|refactor|test|ci|chore)' || echo "workflow")
    local desc=$(echo "$MESSAGE" | sed 's/^[^(]*: //' | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | cut -c1-30 | sed 's/-*$//')
    BRANCH_NAME="${type}-${desc}-${timestamp}"
    
    log "Branch: $BRANCH_NAME"
    log "Message: $MESSAGE"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would create branch and commit"
        return 0
    fi
    
    # Get current branch
    local current_branch=$(git branch --show-current)
    
    # Create feature branch from main
    if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
        log "Creating feature branch from $current_branch..."
        git checkout -b "$BRANCH_NAME"
    else
        # Already on feature branch
        BRANCH_NAME="$current_branch"
    fi
    
    # Run quality gate first
    log "Running quality gate..."
    if [[ -x "$REPO_ROOT/scripts/quality_gate.sh" ]]; then
        if ! "$REPO_ROOT/scripts/quality_gate.sh"; then
            error "Quality gate failed - fix issues before committing"
            return $E_QUALITY_GATE
        fi
    else
        warn "quality_gate.sh not found, skipping"
    fi
    
    # Stage ALL changes
    log "Staging ALL changes..."
    git add -A
    
    # Create commit
    log "Creating commit..."
    if ! git commit -m "$MESSAGE"; then
        error "Failed to create commit"
        return $E_COMMIT_FAILED
    fi
    
    COMMIT_SHA=$(git rev-parse HEAD)
    success "Created commit: ${COMMIT_SHA:0:8} on branch $BRANCH_NAME"
    
    return 0
}
