#!/bin/bash
#
# Atomic Commit Orchestrator - FIXED VERSION
# Coordinates the full atomic commit workflow with rollback support
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TIMEOUT="${ATOMIC_COMMIT_TIMEOUT:-1800}"
NO_ROLLBACK="${ATOMIC_COMMIT_NO_ROLLBACK:-0}"

# Named constants
readonly MAX_POLL_ATTEMPTS=12
readonly POLL_INTERVAL_SECONDS=5

# State tracking
PHASE=""
COMMIT_SHA=""
PR_NUMBER=""
PR_URL=""
START_TIME=""

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[FAIL]${NC} $*" >&2; }

# Error handler
# shellcheck disable=SC2329
cleanup_on_error() {
    local exit_code="$?"
    if [ "$exit_code" -ne 0 ] && [ "$NO_ROLLBACK" -eq 0 ]; then
        log_error "Workflow failed at phase: $PHASE"
        execute_rollback
    fi
    exit "$exit_code"
}
trap cleanup_on_error EXIT

# Rollback function
# shellcheck disable=SC2329
execute_rollback() {
    echo ""
    log_warn "=== ROLLING BACK ==="
    if [ -n "$PR_NUMBER" ]; then
        gh pr close "$PR_NUMBER" --delete-branch=false 2>/dev/null || true
    fi
    if [ -n "$COMMIT_SHA" ]; then
        git reset --soft HEAD~1 2>/dev/null || true
        git reset HEAD 2>/dev/null || true
    fi
    log_success "Rollback complete"
}

# Detect commit type from changed files
detect_commit_type() {
    local files_changed
    files_changed=$(git diff --cached --name-only 2>/dev/null || git diff --name-only)
    if echo "$files_changed" | grep -qE "test|spec"; then echo "test"
    elif echo "$files_changed" | grep -qE "\.github|scripts"; then echo "ci"
    elif echo "$files_changed" | grep -qE "README|\.md$"; then echo "docs"
    elif echo "$files_changed" | grep -qE "fix|bug"; then echo "fix"
    else echo "feat"; fi
}

# Generate commit message
generate_commit_message() {
    local type="$1"
    local files description
    files=$(git diff --cached --name-only 2>/dev/null || git diff --name-only || true)
    if [ -z "$files" ]; then echo "$type: update"; return 0; fi
    description=$(echo "$files" | head -1 | xargs basename 2>/dev/null || echo "files")
    echo "$type: $description"
}

phase_pre_commit() {
    PHASE="PRE-COMMIT"
    log_info "=== Phase 1: Pre-Commit Validation ==="
    local branch
    branch=$(git branch --show-current)
    if [[ "$branch" =~ ^(main|master)$ ]]; then
        log_error "Cannot commit on protected branch: $branch"
        return 1
    fi
    if [ -f "./scripts/quality_gate.sh" ]; then
        if ! ./scripts/quality_gate.sh; then
            log_error "Quality gate failed"
            return 2
        fi
    fi
    log_success "Pre-commit validation passed"
    return 0
}

phase_commit() {
    PHASE="COMMIT"
    log_info "=== Phase 2: Atomic Commit ==="
    if [ "${1:-}" == "--dry-run" ]; then
        log_info "[DRY RUN] Would commit"
        return 0
    fi
    git add -A
    if git diff --cached --quiet; then
        log_error "No changes to commit"
        return 3
    fi
    local commit_type msg
    commit_type=$(detect_commit_type)
    msg=$(generate_commit_message "$commit_type")
    log_info "Commit: $msg"
    if ! git commit -m "$msg"; then
        log_error "Commit failed"
        return 3
    fi
    COMMIT_SHA=$(git rev-parse HEAD)
    log_success "Created commit: ${COMMIT_SHA:0:8}"
    return 0
}

phase_pre_push() {
    PHASE="PRE-PUSH"
    log_info "=== Phase 3: Pre-Push Sync ==="
    local branch
    branch=$(git branch --show-current)
    git fetch origin || return 4
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        if ! git merge-base --is-ancestor "origin/$branch" HEAD 2>/dev/null; then
            log_error "Remote diverged"
            return 4
        fi
    fi
    log_success "Pre-push sync OK"
    return 0
}

phase_push() {
    PHASE="PUSH"
    log_info "=== Phase 4: Push ==="
    local branch
    branch=$(git branch --show-current)
    if ! git push -u origin "$branch"; then
        log_error "Push failed"
        return 4
    fi
    log_success "Pushed to origin/$branch"
    return 0
}

phase_pr_create() {
    PHASE="PR-CREATE"
    log_info "=== Phase 5: Create Pull Request ==="
    if ! gh auth status &>/dev/null; then
        log_error "GitHub CLI not authenticated"
        return 5
    fi
    local branch title body base
    branch=$(git branch --show-current)
    title=$(git log -1 --pretty=%s)
    body="PR created by atomic-commit"
    base="main"
    if git rev-parse --verify origin/master &>/dev/null; then base="master"; fi
    if ! PR_URL=$(gh pr create --title "$title" --body "$body" --base "$base" 2>&1); then
        local existing
        existing=$(gh pr list --head "$branch" --json url --jq '.[0].url' 2>/dev/null || true)
        if [ -n "$existing" ]; then PR_URL="$existing"
        else log_error "PR creation failed"; return 5; fi
    fi
    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
    log_success "PR #$PR_NUMBER created"
    return 0
}

# FIXED Phase 6: Verify checks with polling
phase_verify() {
    PHASE="VERIFY"
    log_info "=== Phase 6: Verify CI Checks ==="
    log_info "Timeout: ${TIMEOUT}s"
    echo ""
    local start_time elapsed check_list poll_count
    start_time=$(date +%s)
    
    # FIXED: Poll for checks to appear
    log_info "Step 1: Polling for checks..."
    poll_count=0
    check_list=""
    
    while [ $poll_count -lt $MAX_POLL_ATTEMPTS ]; do
        check_list=$(gh pr checks "$PR_NUMBER" 2>&1) || true
        if ! echo "$check_list" | grep -qi "no checks reported"; then
            if [ -n "$check_list" ]; then
                log_success "Checks found after $((poll_count * POLL_INTERVAL_SECONDS))s"
                break
            fi
        fi
        poll_count=$((poll_count + 1))
        if [ $poll_count -lt $MAX_POLL_ATTEMPTS ]; then
            log_info "  Waiting... (${poll_count}/${MAX_POLL_ATTEMPTS})"
            sleep $POLL_INTERVAL_SECONDS
        fi
    done
    
    # Handle no-CI case
    if echo "$check_list" | grep -qi "no checks reported" || [ -z "$check_list" ]; then
        elapsed=$(( $(date +%s) - start_time ))
        log_warn "No CI configured"
        log_success "Done (${elapsed}s)"
        return 0
    fi
    
    # Watch checks
    log_info "Step 2: Watching checks..."
    echo "$check_list" | head -5
    echo ""
    
    local checks_output
    checks_output=$(mktemp)
    if ! timeout "$TIMEOUT" gh pr checks "$PR_NUMBER" --watch --interval 10 2>&1 | tee "$checks_output"; then
        elapsed=$(( $(date +%s) - start_time ))
        if [ $elapsed -ge "$TIMEOUT" ]; then
            log_error "Timeout (${elapsed}s)"
            rm -f "$checks_output"
            return 7
        fi
        if grep -qiE "warning|deprecated" "$checks_output"; then
            log_error "Warnings found"
            rm -f "$checks_output"
            return 6
        fi
        log_error "Checks failed"
        rm -f "$checks_output"
        return 6
    fi
    elapsed=$(( $(date +%s) - start_time ))
    if grep -qiE "warning|deprecated" "$checks_output"; then
        log_error "Warnings in output"
        rm -f "$checks_output"
        return 6
    fi
    log_success "All checks passed (${elapsed}s)"
    rm -f "$checks_output"
    return 0
}

phase_report() {
    PHASE="REPORT"
    local elapsed
    elapsed=$(( $(date +%s) - START_TIME ))
    echo ""
    log_success "=== WORKFLOW COMPLETE ==="
    log_success "Commit: ${COMMIT_SHA:0:8}"
    log_success "PR: #$PR_NUMBER"
    log_success "Time: ${elapsed}s"
    log_info "PR URL: $PR_URL"
    echo ""
}

main() {
    START_TIME=$(date +%s)
    echo ""
    log_info "=== ATOMIC COMMIT ==="
    echo ""
    if [ "${1:-}" == "--help" ]; then
        echo "Usage: $0 [--dry-run|--help]"
        exit 0
    fi
    phase_pre_commit || exit 2
    phase_commit "${1:-}" || exit 3
    phase_pre_push || exit 4
    phase_push || exit 4
    phase_pr_create || exit 5
    phase_verify || exit 6
    phase_report
    exit 0
}

main "$@"
