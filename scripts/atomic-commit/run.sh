#!/bin/bash
#
# Atomic Commit Orchestrator
# Coordinates the full atomic commit workflow with rollback support
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT="${ATOMIC_COMMIT_TIMEOUT:-1800}"  # 30 minutes
NO_ROLLBACK="${ATOMIC_COMMIT_NO_ROLLBACK:-0}"
DRY_RUN="${1:-}"

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
cleanup_on_error() {
    local exit_code=$?
    if [ $exit_code -ne 0 ] && [ "$NO_ROLLBACK" -eq 0 ]; then
        log_error "Workflow failed at phase: $PHASE (exit code: $exit_code)"
        execute_rollback
    fi
    exit $exit_code
}
trap cleanup_on_error EXIT

# Rollback all phases
execute_rollback() {
    echo ""
    log_warn "═══════════════════════════════════════════════════════"
    log_warn "              ROLLING BACK WORKFLOW                      "
    log_warn "═══════════════════════════════════════════════════════"
    echo ""
    
    # Rollback in reverse order
    if [ -n "$PR_NUMBER" ]; then
        log_info "Closing PR #$PR_NUMBER..."
        gh pr close "$PR_NUMBER" --delete-branch=false 2>/dev/null || true
    fi
    
    if [ -n "$COMMIT_SHA" ]; then
        log_info "Removing local commit..."
        git reset --soft HEAD~1 2>/dev/null || true
        git reset HEAD 2>/dev/null || true
    fi
    
    log_success "Rollback complete"
}

# Detect commit type from changed files
detect_commit_type() {
    local files_changed
    files_changed=$(git diff --cached --name-only 2>/dev/null || git diff --name-only)
    
    if echo "$files_changed" | grep -qE "(test|spec|__tests__)"; then
        echo "test"
    elif echo "$files_changed" | grep -qE "\.github|scripts/|Makefile|\.ya?ml$"; then
        echo "ci"
    elif echo "$files_changed" | grep -qE "(README|CHANGELOG|LICENSE|\.md$)"; then
        echo "docs"
    elif echo "$files_changed" | grep -qE "(refactor|restructure)"; then
        echo "refactor"
    elif echo "$files_changed" | grep -qE "(fix|bug|hotfix)"; then
        echo "fix"
    else
        echo "feat"
    fi
}

# Generate conventional commit message
generate_commit_message() {
    local type="$1"
    local files
    local scope=""
    local description=""
    
    # Get staged files first
    files=$(git diff --cached --name-only 2>/dev/null || true)
    
    # If no staged files, get unstaged
    if [ -z "$files" ]; then
        files=$(git diff --name-only 2>/dev/null || true)
    fi
    
    # If still no files, check untracked
    if [ -z "$files" ]; then
        files=$(git ls-files --others --exclude-standard 2>/dev/null || true)
    fi
    
    # Default if no files found
    if [ -z "$files" ]; then
        echo "$type: update repository"
        return 0
    fi
    
    # Determine scope from first directory
    scope=$(echo "$files" | grep "/" | head -1 | cut -d'/' -f1)
    
    # Generate description based on file count
    local file_count
    file_count=$(echo "$files" | grep -c '^' 2>/dev/null || echo "0")
    
    if [ "$file_count" -eq 1 ] || [ "$file_count" -eq 0 ]; then
        # Single file - use filename
        local filename
        filename=$(echo "$files" | head -1)
        if [ -n "$filename" ]; then
            description=$(basename "$filename" 2>/dev/null || echo "$filename")
        fi
    fi
    
    # Default description if single file didn't work
    if [ -z "$description" ]; then
        description="update files"
    fi
    
    if [ -n "$scope" ]; then
        echo "$type($scope): $description"
    else
        echo "$type: $description"
    fi
}

# Phase 1: Pre-commit validation
phase_pre_commit() {
    PHASE="PRE-COMMIT"
    log_info "=== Phase 1: Pre-Commit Validation ==="
    
    # Check branch
    local branch
    branch=$(git branch --show-current)
    if [[ "$branch" =~ ^(main|master|production|release)$ ]]; then
        log_error "Cannot commit on protected branch: $branch"
        return 1
    fi
    log_success "On feature branch: $branch"
    
    # Run quality gate
    log_info "Running quality gate..."
    if [ -f "./scripts/quality_gate.sh" ]; then
        if ! ./scripts/quality_gate.sh; then
            log_error "Quality gate failed - fix all warnings"
            return 2
        fi
    else
        log_warn "Quality gate script not found, skipping"
    fi
    
    # Check for secrets
    if command -v git-secrets &>/dev/null; then
        if ! git-secrets scan; then
            log_error "Secrets detected in diff"
            return 2
        fi
    fi
    
    log_success "Pre-commit validation passed"
    return 0
}

# Phase 2: Atomic commit
phase_commit() {
    PHASE="COMMIT"
    log_info "=== Phase 2: Atomic Commit ==="
    
    if [ "$DRY_RUN" == "--dry-run" ]; then
        log_info "[DRY RUN] Would stage and commit all changes"
        return 0
    fi
    
    # Stage all
    git add -A
    
    # Check if there's anything to commit
    if git diff --cached --quiet; then
        log_error "No changes to commit"
        return 3
    fi
    
    # Detect type and generate message
    local commit_type
    commit_type=$(detect_commit_type)
    log_info "Detected commit type: $commit_type"
    
    local commit_msg
    commit_msg=$(generate_commit_message "$commit_type")
    log_info "Commit message: $commit_msg"
    
    # Commit
    if ! git commit -m "$commit_msg"; then
        log_error "Commit failed"
        return 3
    fi
    
    COMMIT_SHA=$(git rev-parse HEAD)
    log_success "Created commit: ${COMMIT_SHA:0:8}"
    return 0
}

# Phase 3: Pre-push (remote sync check)
phase_pre_push() {
    PHASE="PRE-PUSH"
    log_info "=== Phase 3: Pre-Push Sync ==="
    
    local branch
    branch=$(git branch --show-current)
    
    # Fetch latest
    log_info "Fetching from origin..."
    if ! git fetch origin; then
        log_error "Failed to fetch from origin"
        return 4
    fi
    
    # Check if remote branch exists
    if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        # Check divergence
        if git merge-base --is-ancestor "origin/$branch" HEAD 2>/dev/null; then
            log_success "Remote is ancestor, can fast-forward"
        else
            log_error "Remote has diverged. Run: git pull --rebase origin $branch"
            return 4
        fi
    else
        log_info "New branch: $branch"
    fi
    
    log_success "Pre-push sync OK"
    return 0
}

# Phase 4: Push
phase_push() {
    PHASE="PUSH"
    log_info "=== Phase 4: Push ==="
    
    if [ "$DRY_RUN" == "--dry-run" ]; then
        log_info "[DRY RUN] Would push to origin"
        return 0
    fi
    
    local branch
    branch=$(git branch --show-current)
    
    # Push with tracking
    if ! git push -u origin "$branch"; then
        log_error "Push failed"
        return 4
    fi
    
    # Verify
    local local_sha remote_sha
    local_sha=$(git rev-parse HEAD)
    remote_sha=$(git rev-parse "origin/$branch")
    
    if [ "$local_sha" != "$remote_sha" ]; then
        log_error "SHA mismatch after push"
        return 4
    fi
    
    log_success "Pushed to origin/$branch"
    return 0
}

# Phase 5: Create PR
phase_pr_create() {
    PHASE="PR-CREATE"
    log_info "=== Phase 5: Create Pull Request ==="
    
    # Check gh CLI
    if ! gh auth status &>/dev/null; then
        log_error "GitHub CLI not authenticated. Run: gh auth login"
        return 5
    fi
    
    if [ "$DRY_RUN" == "--dry-run" ]; then
        log_info "[DRY RUN] Would create PR"
        return 0
    fi
    
    local branch commit_msg pr_title
    branch=$(git branch --show-current)
    commit_msg=$(git log -1 --pretty=%B)
    pr_title=$(echo "$commit_msg" | head -1)
    
    # Generate PR body
    local pr_body
    pr_body=$(cat << EOF
## Summary
$(echo "$commit_msg" | head -5 | sed 's/^/- /')

## Changes
$(git diff --name-only HEAD~1 HEAD | head -20 | sed 's/^/- `/; s/$/`/')

## Checklist
- [x] Quality gate passed
- [x] Conventional commit format
- [x] All checks will be verified

## Commits
\`\`\`
$(git log --oneline --no-decorate HEAD~1..HEAD)
\`\`\`
EOF
)
    
    # Detect base branch
    local base_branch="main"
    if git rev-parse --verify origin/master &>/dev/null; then
        base_branch="master"
    fi
    
    # Create PR
    log_info "Creating PR..."
    if ! PR_URL=$(gh pr create --title "$pr_title" --body "$pr_body" --base "$base_branch" 2>&1); then
        # Check if PR already exists
        local existing_pr
        existing_pr=$(gh pr list --head "$branch" --json url --jq '.[0].url' 2>/dev/null || true)
        if [ -n "$existing_pr" ]; then
            log_warn "PR already exists: $existing_pr"
            PR_URL="$existing_pr"
        else
            log_error "Failed to create PR"
            return 5
        fi
    fi
    
    PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
    log_success "PR #$PR_NUMBER: $PR_URL"
    return 0
}

# Phase 6: Verify checks
phase_verify() {
    PHASE="VERIFY"
    log_info "=== Phase 6: Verify CI Checks ==="
    log_info "Waiting for all GitHub Actions to complete..."
    log_info "Timeout: ${TIMEOUT}s (30 minutes)"
    echo ""
    
    if [ "$DRY_RUN" == "--dry-run" ]; then
        log_info "[DRY RUN] Would watch checks for PR #$PR_NUMBER"
        return 0
    fi
    
    local start_time end_time elapsed
    start_time=$(date +%s)
    
    # Watch checks
    local checks_output checks_exit
    checks_output=$(mktemp)
    if ! gh pr checks "$PR_NUMBER" --watch --interval 10 2>&1 | tee "$checks_output"; then
        checks_exit=${PIPESTATUS[0]}
        
        # Check for timeout
        end_time=$(date +%s)
        elapsed=$((end_time - start_time))
        
        if [ $elapsed -ge $TIMEOUT ]; then
            log_error "Timeout waiting for checks (${elapsed}s)"
            return 7
        fi
        
        # Check for warnings (zero tolerance)
        if grep -qiE "(warning|warn:|deprecated|obsolete)" "$checks_output"; then
            log_error "Zero Warnings Policy: Warnings detected in check output"
            return 6
        fi
        
        log_error "Checks failed"
        return 6
    fi
    
    # Final check for warnings in output
    if grep -qiE "(warning|warn:|deprecated|obsolete)" "$checks_output"; then
        log_error "Zero Warnings Policy: Warnings detected in check output"
        return 6
    fi
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    log_success "All checks passed (${elapsed}s)"
    rm -f "$checks_output"
    return 0
}

# Phase 7: Report
phase_report() {
    PHASE="REPORT"
    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$((end_time - START_TIME))
    
    echo ""
    log_success "════════════════════════════════════════════════════════"
    log_success "         ATOMIC COMMIT WORKFLOW COMPLETE                  "
    log_success "════════════════════════════════════════════════════════"
    echo ""
    log_success "✓ Commit: ${COMMIT_SHA:0:8} - $(git log -1 --pretty=%s)"
    log_success "✓ Branch: $(git branch --show-current)"
    log_success "✓ PR: #$PR_NUMBER - $PR_URL"
    log_success "✓ Time: ${elapsed}s"
    log_success "✓ All checks passed (zero warnings)"
    echo ""
    log_info "Next steps:"
    log_info "  1. Review PR: $PR_URL"
    log_info "  2. Request reviewers"
    log_info "  3. Merge when ready"
    echo ""
}

# Main execution
main() {
    START_TIME=$(date +%s)
    
    echo ""
    log_info "╔═══════════════════════════════════════════════════════╗"
    log_info "║         ATOMIC COMMIT WORKFLOW START                  ║"
    log_info "╚═══════════════════════════════════════════════════════╝"
    echo ""
    
    # Parse arguments
    case "${1:-}" in
        --dry-run)
            DRY_RUN="--dry-run"
            log_warn "DRY RUN MODE - No changes will be made"
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run|--help]"
            echo ""
            echo "Options:"
            echo "  --dry-run    Validate without making changes"
            echo "  --help       Show this help"
            echo ""
            echo "Environment variables:"
            echo "  ATOMIC_COMMIT_TIMEOUT      Check wait timeout (default: 1800)"
            echo "  ATOMIC_COMMIT_NO_ROLLBACK  Set 1 to disable rollback"
            exit 0
            ;;
    esac
    
    # Execute phases
    phase_pre_commit || exit 2
    phase_commit || exit 3
    phase_pre_push || exit 4
    phase_push || exit 4
    phase_pr_create || exit 5
    phase_verify || exit 6
    phase_report
    
    exit 0
}

main "$@"
