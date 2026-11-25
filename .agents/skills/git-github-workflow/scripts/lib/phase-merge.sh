#!/usr/bin/env bash
# lib/phase-merge.sh - Phase 6 MERGE and Phase 7 POST-MERGE VALIDATION agent
# functions for the Git-GitHub workflow skill. Sourced by ../../run.sh.
# shellcheck disable=SC2034,SC2086,SC2154,SC2164
# Verbatim phase code from the former single-file run.sh. The sourcing run.sh
# defines the config/state globals, logging helpers, readonly error codes, and
# the strict shell options used below, and also reads MERGE_STATUS in its
# summary; that cross-file contract is invisible here, so SC2034 (state read
# by the sourcer), SC2154 (never-assigned globals), SC2086 (unquoted expansions
# of those readonly constants), and SC2164 (cd guarded by the caller's
# errexit) are suppressed with this documented reason.
# Agent 6: MERGE
agent_merge() {
    agent "AGENT 6: MERGE"
    log "═══════════════════════════════════════════════════════════════════"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would merge PR #$PR_NUMBER"
        MERGE_STATUS="MERGED"
        return 0
    fi
    
    log "Merging PR #$PR_NUMBER..."
    
    local merge_output
    if ! merge_output=$(gh pr merge "$PR_NUMBER" \
        --squash \
        --delete-branch=false \
        2>&1); then
        error "Merge failed: $merge_output"
        return $E_MERGE_FAILED
    fi
    
    MERGE_STATUS="MERGED"
    success "Successfully merged PR #$PR_NUMBER"
    
    # Close related issues if requested
    if [[ "$CLOSE_ISSUES" == true && ${#ISSUES_FOUND[@]} -gt 0 ]]; then
        log "Closing related issues..."
        for issue in "${ISSUES_FOUND[@]}"; do
            local issue_num=$(echo "$issue" | grep -oE '[0-9]+' | head -1)
            if [[ -n "$issue_num" ]]; then
                gh issue close "$issue_num" --comment "Fixed in PR #$PR_NUMBER" 2>/dev/null || true
            fi
        done
    fi
    
    return 0
}

# Agent 7: POST-MERGE VALIDATION
agent_post_merge_validate() {
    agent "AGENT 7: POST-MERGE VALIDATION"
    log "═══════════════════════════════════════════════════════════════════"
    
    if [[ "$POST_MERGE_VALIDATE" == false ]]; then
        log "Skipping post-merge validation"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would validate main branch"
        return 0
    fi
    
    log "Checking out main branch..."
    cd "$REPO_ROOT"
    
    # Stash any changes
    if [[ -n $(git status --porcelain) ]]; then
        git stash push -m "workflow-stash-$(date +%s)"
    fi
    
    git checkout main
    
    log "Pulling latest changes..."
    if ! git pull origin main; then
        error "Failed to pull main"
        return $E_POST_MERGE_FAILED
    fi
    
    log "Validating repository integrity..."
    
    # Check 1: All expected files present
    log "  Checking files..."
    # Add specific file checks here
    
    # Check 2: Documentation
    log "  Checking documentation..."
    if [[ -d "$REPO_ROOT/docs" || -d "$REPO_ROOT/.agents" ]]; then
        info "  Documentation directories present"
    fi
    
    # Check 3: Run quality gate
    log "  Running quality gate..."
    if [[ -x "$REPO_ROOT/scripts/quality_gate.sh" ]]; then
        if ! "$REPO_ROOT/scripts/quality_gate.sh"; then
            error "Quality gate failed on main!"
            return $E_POST_MERGE_FAILED
        fi
    fi
    
    # Check 4: Verify commit present
    log "  Verifying commit..."
    if ! git log --oneline | grep -q "${COMMIT_SHA:0:7}"; then
        warn "Commit SHA not found in recent history (may be squashed)"
    fi
    
    success "Post-merge validation PASSED"
    return 0
}
