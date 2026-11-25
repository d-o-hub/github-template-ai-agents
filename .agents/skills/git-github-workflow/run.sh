#!/usr/bin/env bash
# Git-GitHub Workflow - Unified atomic workflow with swarm coordination
# Phases: COMMIT → CHECK ISSUES → CREATE PR → MONITOR → FIX (if needed) → MERGE → VALIDATE
#
# Config/state globals below (and the parsed args that set them) form the shared
# contract of this script with the sourced scripts/lib/ phase modules; the
# analytic "unused" warnings for that cross-file use are suppressed file-wide.
# shellcheck disable=SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Configuration
DRY_RUN=false
MESSAGE=""
FIX_ISSUES=false
CLOSE_ISSUES=false
STRICT_VALIDATION=true
SKIP_ISSUE_CHECK=false
POST_MERGE_VALIDATE=true
AUTO_RESEARCH=true
MAX_RETRIES=3
TIMEOUT=3600
POLL_INTERVAL=15

# State tracking
COMMIT_SHA=""
BRANCH_NAME=""
PR_NUMBER=""
PR_URL=""
ISSUES_FOUND=()
CHECKS_FAILED=()
RETRY_COUNT=0
MERGE_STATUS=""

# Phase agents and shared helpers live in scripts/lib/, sourced relative to
# this file so the skill works from any checkout location.
# shellcheck source=scripts/lib/common.sh
source "$SCRIPT_DIR/scripts/lib/common.sh"
# shellcheck source=scripts/lib/phase-commit.sh
source "$SCRIPT_DIR/scripts/lib/phase-commit.sh"
# shellcheck source=scripts/lib/phase-issues.sh
source "$SCRIPT_DIR/scripts/lib/phase-issues.sh"
# shellcheck source=scripts/lib/phase-pr.sh
source "$SCRIPT_DIR/scripts/lib/phase-pr.sh"
# shellcheck source=scripts/lib/phase-monitor.sh
source "$SCRIPT_DIR/scripts/lib/phase-monitor.sh"
# shellcheck source=scripts/lib/phase-merge.sh
source "$SCRIPT_DIR/scripts/lib/phase-merge.sh"

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --message|-m)
                MESSAGE="$2"
                shift 2
                ;;
            --fix-issues)
                FIX_ISSUES=true
                shift
                ;;
            --close-issues)
                CLOSE_ISSUES=true
                shift
                ;;
            --strict-validation)
                STRICT_VALIDATION=true
                shift
                ;;
            --no-strict-validation)
                STRICT_VALIDATION=false
                shift
                ;;
            --skip-issue-check)
                SKIP_ISSUE_CHECK=true
                shift
                ;;
            --post-merge-validate)
                POST_MERGE_VALIDATE=true
                shift
                ;;
            --no-post-merge-validate)
                POST_MERGE_VALIDATE=false
                shift
                ;;
            --auto-research)
                AUTO_RESEARCH=true
                shift
                ;;
            --no-auto-research)
                AUTO_RESEARCH=false
                shift
                ;;
            --max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
Usage: run.sh [OPTIONS]

Unified Git-GitHub Workflow with Swarm Coordination

Phases:
  1. ATOMIC COMMIT - Stage all, validate, commit
  2. CHECK GITHUB ISSUES - List and check issues
  3. CREATE PR - Push branch, create PR
  4. MONITOR ACTIONS - ALL checks must pass
  5. FIX ISSUES (if needed) - Web research, apply fixes
  6. MERGE - Merge to main
  7. POST-MERGE VALIDATE - Verify all files/docs

Options:
    -m, --message "MSG"       Commit message (auto-generate if omitted)
    --fix-issues              Attempt to fix issues automatically
    --close-issues            Close related issues on merge
    --strict-validation       ALL checks must pass (default)
    --no-strict-validation    Allow pre-existing failures
    --skip-issue-check        Don't check GitHub issues
    --post-merge-validate     Run validation after merge (default)
    --no-post-merge-validate  Skip post-merge validation
    --auto-research           Use web research on failures (default)
    --no-auto-research        Disable auto-research
    --max-retries N           Max fix attempts (default: 3)
    --timeout SECONDS         Actions timeout (default: 3600)
    --dry-run                 Simulate without executing
    -h, --help                Show this help

Environment:
    GIT_GITHUB_WORKFLOW_TIMEOUT=3600
    GIT_GITHUB_WORKFLOW_MAX_RETRIES=3
    GIT_GITHUB_WORKFLOW_STRICT_VALIDATION=1

Examples:
    run.sh -m "feat: new feature"           # Full workflow
    run.sh --fix-issues --close-issues      # Auto-fix and close
    run.sh --dry-run                        # Simulate only
EOF
}

# Main execution
main() {
    parse_args "$@"
    
    log ""
    log "╔═══════════════════════════════════════════════════════════════════╗"
    log "║     GIT-GITHUB WORKFLOW with Swarm Coordination                   ║"
    log "╚═══════════════════════════════════════════════════════════════════╝"
    log ""
    log "Configuration:"
    log "  Fix issues: $FIX_ISSUES"
    log "  Strict validation: $STRICT_VALIDATION"
    log "  Auto-research: $AUTO_RESEARCH"
    log "  Max retries: $MAX_RETRIES"
    log "  Post-merge validate: $POST_MERGE_VALIDATE"
    log ""
    
    local exit_code=$E_SUCCESS
    
    # Phase 1: Atomic Commit
    if ! agent_commit; then
        exit_code=$?
        error "PHASE 1 FAILED: Atomic commit"
    fi
    
    # Phase 2: Check Issues (if commit succeeded)
    if [[ $exit_code -eq $E_SUCCESS ]]; then
        if ! agent_check_issues; then
            exit_code=$?
            error "PHASE 2 FAILED: Issue check"
        fi
    fi
    
    # Phase 3: Create PR
    if [[ $exit_code -eq $E_SUCCESS ]]; then
        if ! agent_create_pr; then
            exit_code=$?
            error "PHASE 3 FAILED: PR creation"
        fi
    fi
    
    # Phase 4 & 5: Monitor and Fix (loop)
    if [[ $exit_code -eq $E_SUCCESS ]]; then
        while true; do
            if agent_monitor_actions; then
                # All checks passed
                break
            else
                # Checks failed
                if [[ "$AUTO_RESEARCH" == true && $RETRY_COUNT -lt $MAX_RETRIES ]]; then
                    if ! agent_fix_issues; then
                        exit_code=$?
                        error "PHASE 5 FAILED: Could not fix issues"
                        break
                    fi
                    # Retry monitoring
                    continue
                else
                    # shellcheck disable=SC2153
                    exit_code=$E_CHECKS_FAILED
                    error "PHASE 4 FAILED: Checks did not pass"
                    break
                fi
            fi
        done
    fi
    
    # Phase 6: Merge
    if [[ $exit_code -eq $E_SUCCESS ]]; then
        if ! agent_merge; then
            exit_code=$?
            error "PHASE 6 FAILED: Merge"
        fi
    fi
    
    # Phase 7: Post-Merge Validation
    if [[ $exit_code -eq $E_SUCCESS ]]; then
        if ! agent_post_merge_validate; then
            exit_code=$?
            error "PHASE 7 FAILED: Post-merge validation"
        fi
    fi
    
    # Final report
    log ""
    log "╔═══════════════════════════════════════════════════════════════════╗"
    if [[ $exit_code -eq $E_SUCCESS ]]; then
        success "║     WORKFLOW COMPLETED SUCCESSFULLY                               ║"
        log "╚═══════════════════════════════════════════════════════════════════╝"
        log ""
        log "Summary:"
        log "  Branch: $BRANCH_NAME"
        log "  Commit: ${COMMIT_SHA:0:8}"
        log "  PR: #$PR_NUMBER"
        log "  Merge: $MERGE_STATUS"
        log "  Issues found: ${#ISSUES_FOUND[@]}"
        log "  Fix attempts: $RETRY_COUNT"
        log ""
    else
        error "║     WORKFLOW FAILED                                               ║"
        log "╚═══════════════════════════════════════════════════════════════════╝"
        log ""
        error "Exit code: $exit_code"
        log ""
        log "Failed at phase:"
        case $exit_code in
            2) log "  Phase 1: Atomic Commit" ;;
            3) log "  Phase 1: Quality Gate" ;;
            4) log "  Phase 2: GitHub Issues" ;;
            5) log "  Phase 3: PR Creation" ;;
            6) log "  Phase 4: Actions Monitoring" ;;
            7) log "  Phase 5: Issue Resolution (max retries)" ;;
            8) log "  Phase 6: Merge" ;;
            9) log "  Phase 7: Post-Merge Validation" ;;
        esac
        log ""
    fi
    
    # $exit_code holds one of the readonly E_* constants sourced from
    # scripts/lib/common.sh, so the expansion cannot glob or split.
    # shellcheck disable=SC2086
    exit $exit_code
}

main "$@"
