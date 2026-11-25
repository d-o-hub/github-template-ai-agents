#!/usr/bin/env bash
# lib/phase-monitor.sh - Phase 4 MONITOR ALL ACTIONS and Phase 5 FIX ISSUES
# agent functions for the Git-GitHub workflow skill. Sourced by ../../run.sh.
# shellcheck disable=SC2086,SC2153,SC2154
# Verbatim phase code from the former single-file run.sh. The sourcing run.sh
# defines the config/state globals, logging helpers, and readonly error codes
# used below; that cross-file contract is invisible here, so SC2154
# (never-assigned globals), SC2086 (unquoted expansions of those readonly
# constants), and SC2153 (constants defined in lib/common.sh look misspelled)
# are suppressed with this documented reason.
# Agent 4: MONITOR ACTIONS
agent_monitor_actions() {
    agent "AGENT 4: MONITOR ALL ACTIONS"
    log "═══════════════════════════════════════════════════════════════════"
    log "PR: #$PR_NUMBER"
    log "Timeout: ${TIMEOUT}s | Poll: ${POLL_INTERVAL}s"
    log "Strict: $STRICT_VALIDATION"
    log ""
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would monitor Actions"
        return 0
    fi
    
    local start_time=$(date +%s)
    local all_pass=false
    local attempts=0
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -gt $TIMEOUT ]]; then
            error "Timeout after ${TIMEOUT}s"
            return $E_CHECKS_FAILED
        fi
        
        ((attempts++))
        
        # Get PR checks
        local checks_output=$(gh pr checks "$PR_NUMBER" 2>&1 || true)
        local pr_state=$(gh pr view "$PR_NUMBER" --json state --jq '.state' 2>/dev/null || echo "OPEN")
        
        # Check if already merged
        if [[ "$pr_state" == "MERGED" ]]; then
            success "PR already merged!"
            return 0
        fi
        
        if [[ "$pr_state" == "CLOSED" ]]; then
            error "PR was closed"
            return $E_CHECKS_FAILED
        fi
        
        # Analyze checks
        local has_pending=false
        local has_failure=false
        local has_warning=false
        
        local checks_output_lower="${checks_output,,}"
        # Check pending
        if [[ "$checks_output_lower" =~ (pending|queued|in[[:space:]]progress|running) ]]; then
            has_pending=true
        fi
        
        # Check failures
        if [[ "$checks_output_lower" =~ (fail|error|✗|×) ]]; then
            has_failure=true
        fi
        
        # Check warnings (if strict)
        if [[ "$checks_output_lower" =~ (warning|warn:|deprecated) ]]; then
            has_warning=true
        fi
        
        # Check repo Actions
        local workflow_runs=$(gh run list --branch "$BRANCH_NAME" --limit 10 --json status,conclusion 2>/dev/null || echo "[]")
        if [[ "$workflow_runs" == *'"status":"in_progress"'* ]]; then
            has_pending=true
        fi
        if [[ "$workflow_runs" == *'"conclusion":"failure"'* ]]; then
            has_failure=true
        fi
        
        # Display status
        if [[ $((attempts % 4)) -eq 1 ]]; then
            log "Monitoring... (${elapsed}s elapsed)"
        fi
        
        if [[ "$has_pending" == true ]]; then
            sleep $POLL_INTERVAL
            continue
        fi
        
        # All checks complete
        if [[ "$has_failure" == false && "$has_warning" == false ]]; then
            all_pass=true
            break
        fi
        
        # STRICT MODE: Any failure/warning = fail
        if [[ "$STRICT_VALIDATION" == true ]]; then
            if [[ "$has_failure" == true ]]; then
                error "CHECKS FAILED - Failures detected"
                CHECKS_FAILED+=("Check failures")
            fi
            if [[ "$has_warning" == true ]]; then
                error "CHECKS FAILED - Warnings detected (strict mode)"
                CHECKS_FAILED+=("Warnings")
            fi
            return $E_CHECKS_FAILED
        else
            # Non-strict: just warn
            if [[ "$has_failure" == true ]]; then
                warn "Checks have failures (non-strict mode)"
            fi
            if [[ "$has_warning" == true ]]; then
                warn "Checks have warnings (non-strict mode)"
            fi
            all_pass=true
            break
        fi
    done
    
    if [[ "$all_pass" == true ]]; then
        success "ALL CHECKS PASSED"
        return 0
    fi
    
    return $E_CHECKS_FAILED
}

# Agent 5: FIX ISSUES (using web research and skills)
agent_fix_issues() {
    agent "AGENT 5: FIX ISSUES WITH WEB RESEARCH"
    log "═══════════════════════════════════════════════════════════════════"
    
    if [[ "$AUTO_RESEARCH" == false ]]; then
        error "Auto-research disabled, cannot fix issues automatically"
        return $E_MAX_RETRIES
    fi
    
    ((RETRY_COUNT++))
    log "Fix attempt $RETRY_COUNT of $MAX_RETRIES"
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would research and fix issues"
        return 0
    fi
    
    # Analyze failures
    log "Analyzing failures..."
    local failures="${CHECKS_FAILED[*]}"
    
    info "Failures detected: $failures"
    info "This would trigger web-research-researcher and doc-resolver skills"
    info "For each failure:"
    info "  1. Query web for solution"
    info "  2. Use doc-resolver for official docs"
    info "  3. Apply relevant skills (shell-script-quality, etc.)"
    info "  4. Commit fixes"
    info "  5. Re-run checks"
    
    # In real implementation, this would:
    # - Call web-search-researcher skill
    # - Call do-web-doc-resolver skill
    # - Apply fixes using appropriate skills
    # - Commit changes
    # - Return to monitoring
    
    warn "Fix automation requires manual implementation based on failure type"
    warn "Retry $RETRY_COUNT/$MAX_RETRIES"
    
    if [[ $RETRY_COUNT -ge $MAX_RETRIES ]]; then
        error "Max retries ($MAX_RETRIES) exceeded"
        return $E_MAX_RETRIES
    fi
    
    # Clear failed checks and retry
    CHECKS_FAILED=()
    
    # Re-run monitoring
    return $E_CHECKS_FAILED
}
