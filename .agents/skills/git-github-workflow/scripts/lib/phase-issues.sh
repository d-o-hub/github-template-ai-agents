#!/usr/bin/env bash
# lib/phase-issues.sh - Phase 2 CHECK GITHUB ISSUES agent function for the
# Git-GitHub workflow skill. Sourced by ../../run.sh.
# shellcheck disable=SC2086,SC2154
# Verbatim phase code from the former single-file run.sh. The sourcing run.sh
# defines the config/state globals, logging helpers, and readonly error codes
# used below; that cross-file contract is invisible here, so SC2154
# (never-assigned globals) and SC2086 (unquoted expansions of those readonly
# constants) are suppressed with this documented reason.
# Agent 2: CHECK GITHUB ISSUES
agent_check_issues() {
    agent "AGENT 2: CHECK GITHUB ISSUES"
    log "═══════════════════════════════════════════════════════════════════"
    
    if [[ "$SKIP_ISSUE_CHECK" == true ]]; then
        log "Skipping issue check (--skip-issue-check)"
        return 0
    fi
    
    if ! command -v gh &>/dev/null; then
        warn "GitHub CLI not available, skipping issue check"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would check GitHub issues"
        return 0
    fi
    
    log "Checking open GitHub issues..."
    
    # Get open issues
    local issues=$(gh issue list --state open --json number,title,labels --jq '.[] | "[#\(.number)] \(.title) [\(.labels | map(.name) | join(", "))]"' 2>/dev/null || echo "")
    
    if [[ -z "$issues" ]]; then
        success "No open issues found"
        return 0
    fi
    
    # Check for blocking labels
    local blocking_issues=$(gh issue list --state open --label "blocking" --json number,title 2>/dev/null || echo "[]")
    local critical_issues=$(gh issue list --state open --label "critical" --json number,title 2>/dev/null || echo "[]")
    
    if [[ "$blocking_issues" != "[]" && "$blocking_issues" != "" ]]; then
        error "BLOCKING issues found:"
        echo "$blocking_issues" | jq -r '.[] | "  #\(.number): \(.title)"'
        
        if [[ "$FIX_ISSUES" == true ]]; then
            log "--fix-issues enabled, will attempt to resolve"
            ISSUES_FOUND+=("$blocking_issues")
        else
            error "Resolve blocking issues before merge or use --fix-issues"
            return $E_ISSUES_BLOCKING
        fi
    fi
    
    if [[ "$critical_issues" != "[]" && "$critical_issues" != "" ]]; then
        warn "CRITICAL issues found:"
        echo "$critical_issues" | jq -r '.[] | "  #\(.number): \(.title)"'
        ISSUES_FOUND+=("$critical_issues")
    fi
    
    info "Open issues:"
    echo "$issues" | head -10
    
    return 0
}
