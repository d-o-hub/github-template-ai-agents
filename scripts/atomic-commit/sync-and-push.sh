#!/usr/bin/env bash
# sync-and-push.sh - Safe synchronization and push script
# Pulls with rebase, handles conflicts, and pushes with --force-with-lease
#
# Usage: ./scripts/atomic-commit/sync-and-push.sh [OPTIONS]
#
# Options:
#   --branch <name>     Target branch (default: current branch)
#   --force             Use --force-with-lease for safe force push
#   --no-rebase         Use merge instead of rebase
#   --auto-stash        Automatically stash/unstash changes
#
# Exit codes:
#   0 = Sync and push successful
#   1 = Failed (conflicts, push rejected, etc.)
#   2 = Warning state (requires manual intervention)

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_WARNING=2

# Configuration
TARGET_BRANCH=""
USE_FORCE="${USE_FORCE:-false}"
NO_REBASE="${NO_REBASE:-false}"
AUTO_STASH="${AUTO_STASH:-false}"
VERBOSE="${VERBOSE:-true}"
REMOTE="${REMOTE:-origin}"
POLL_INTERVAL="${POLL_INTERVAL:-5}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-5}"

# State tracking
STASHED="${STASHED:-false}"
ORIGINAL_BRANCH=""

# Color definitions
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly BOLD=''
    readonly NC=''
fi

# Logging functions
log_info() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_section() {
    echo ""
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
    echo -e "${CYAN}${BOLD}$(printf '=%.0s' $(seq 1 $((${#1} + 3))))${NC}"
}

# Error handler with cleanup
# shellcheck disable=SC2329
error_handler() {
    local line=$1
    log_error "Unexpected error in ${SCRIPT_NAME} at line ${line}"
    cleanup
    exit "$EXIT_FAILURE"
}
trap 'error_handler $LINENO' ERR

# Cleanup function
cleanup() {
    if [[ "$STASHED" == "true" ]]; then
        log_info "Restoring stashed changes..."
        if git stash pop 2>/dev/null; then
            log_success "Stashed changes restored"
            STASHED="false"
        else
            log_warning "Failed to restore stashed changes automatically"
            log_info "Run manually: git stash pop"
        fi
    fi
}

# Show help
show_help() {
    cat << 'EOF'
Usage: sync-and-push.sh [OPTIONS]

Synchronize with remote and push changes safely.

OPTIONS:
    --branch <name>     Target branch (default: current branch)
    --force             Use --force-with-lease for safe force push
    --no-rebase         Use merge instead of rebase (not recommended)
    --auto-stash        Automatically stash/unstash local changes
    --remote <name>     Remote name (default: origin)
    --quiet, -q         Minimal output
    --help, -h          Show this help message

ENVIRONMENT:
    USE_FORCE           Set to 'true' for force-with-lease push
    AUTO_STASH          Set to 'true' to auto-stash changes
    REMOTE              Remote name (default: origin)

EXIT CODES:
    0 = Success
    1 = Failure
    2 = Warning (requires manual intervention)

EXAMPLES:
    # Sync and push current branch
    sync-and-push.sh

    # Force push with lease (safe)
    sync-and-push.sh --force

    # Auto-stash local changes before sync
    sync-and-push.sh --auto-stash
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --branch)
                TARGET_BRANCH="$2"
                shift 2
                ;;
            --force)
                USE_FORCE="true"
                shift
                ;;
            --no-rebase)
                NO_REBASE="true"
                shift
                ;;
            --auto-stash)
                AUTO_STASH="true"
                shift
                ;;
            --remote)
                REMOTE="$2"
                shift 2
                ;;
            --quiet|-q)
                VERBOSE="false"
                shift
                ;;
            --help|-h)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit "$EXIT_FAILURE"
                ;;
            *)
                log_error "Unexpected argument: $1"
                show_help
                exit "$EXIT_FAILURE"
                ;;
        esac
    done
}

# Validate environment
validate_environment() {
    log_section "Environment Validation"
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository"
        return "$EXIT_FAILURE"
    fi
    
    # Get current branch
    ORIGINAL_BRANCH=$(git branch --show-current 2>/dev/null || true)
    
    if [[ -z "$ORIGINAL_BRANCH" ]]; then
        log_error "Not on a branch (HEAD detached)"
        log_info "Checkout a branch first: git checkout <branch-name>"
        return "$EXIT_FAILURE"
    fi
    
    log_success "Current branch: ${CYAN}${ORIGINAL_BRANCH}${NC}"
    
    # Set target branch
    if [[ -z "$TARGET_BRANCH" ]]; then
        TARGET_BRANCH="$ORIGINAL_BRANCH"
    fi
    
    # Check if remote exists
    if ! git remote get-url "$REMOTE" > /dev/null 2>&1; then
        log_error "Remote '${REMOTE}' not found"
        log_info "Available remotes:"
        git remote -v >&2
        return "$EXIT_FAILURE"
    fi
    
    log_success "Remote '${REMOTE}' configured"
    
    # Check if we have unpushed commits
    local unpushed_count
    unpushed_count=$(git log "${REMOTE}/${TARGET_BRANCH}..${TARGET_BRANCH}" --oneline 2>/dev/null | wc -l || echo "0")
    
    if [[ "$unpushed_count" -eq 0 ]]; then
        log_warning "No unpushed commits on ${TARGET_BRANCH}"
        log_info "Nothing to push"
        return "$EXIT_WARNING"
    fi
    
    log_info "Unpushed commits: ${unpushed_count}"
    
    return "$EXIT_SUCCESS"
}

# Check for local changes that might conflict
handle_local_changes() {
    log_section "Local Changes Check"
    
    local has_changes=false
    
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        has_changes=true
    fi
    
    if [[ "$has_changes" == "true" ]]; then
        log_warning "Uncommitted changes detected"
        
        if [[ "$AUTO_STASH" == "true" ]]; then
            log_info "Auto-stashing changes..."
            
            if git stash push -m "auto-stash by sync-and-push.sh"; then
                STASHED="true"
                log_success "Changes stashed"
            else
                log_error "Failed to stash changes"
                return "$EXIT_FAILURE"
            fi
        else
            log_error "Cannot sync with uncommitted changes"
            log_info "Options:"
            log_info "  1. Commit your changes first"
            log_info "  2. Stash manually: git stash"
            log_info "  3. Use --auto-stash flag"
            return "$EXIT_FAILURE"
        fi
    else
        log_success "Working directory clean"
    fi
    
    return "$EXIT_SUCCESS"
}

# Fetch from remote
fetch_remote() {
    log_section "Fetching from Remote"
    
    log_info "Fetching updates from ${REMOTE}..."
    
    if ! git fetch "$REMOTE" --prune 2>&1; then
        log_error "Failed to fetch from remote"
        return "$EXIT_FAILURE"
    fi
    
    log_success "Fetch completed"
    
    # Check if target branch exists on remote
    if ! git show-ref --verify --quiet "refs/remotes/${REMOTE}/${TARGET_BRANCH}" 2>/dev/null; then
        log_warning "Branch '${TARGET_BRANCH}' doesn't exist on remote yet"
        log_info "This will be the first push to create the branch"
        return "$EXIT_WARNING"
    fi
    
    return "$EXIT_SUCCESS"
}

# Check for diverged branches
check_divergence() {
    log_section "Divergence Check"
    
    local local_commit
    local_commit=$(git rev-parse "${TARGET_BRANCH}" 2>/dev/null || echo "")
    local remote_commit
    remote_commit=$(git rev-parse "${REMOTE}/${TARGET_BRANCH}" 2>/dev/null || echo "")
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
        log_success "Local and remote are in sync"
        return "$EXIT_SUCCESS"
    fi
    
    # Check if remote has commits we don't have
    local behind_count
    behind_count=$(git log "${TARGET_BRANCH}..${REMOTE}/${TARGET_BRANCH}" --oneline 2>/dev/null | wc -l || echo "0")
    
    # Check if we have commits remote doesn't have
    local ahead_count
    ahead_count=$(git log "${REMOTE}/${TARGET_BRANCH}..${TARGET_BRANCH}" --oneline 2>/dev/null | wc -l || echo "0")
    
    if [[ "$behind_count" -gt 0 ]] && [[ "$ahead_count" -gt 0 ]]; then
        log_warning "Branches have diverged"
        log_info "Local is ${ahead_count} commit(s) ahead and ${behind_count} commit(s) behind remote"
        return 3  # Special code for divergence
    elif [[ "$behind_count" -gt 0 ]]; then
        log_info "Local is ${behind_count} commit(s) behind remote"
        return 3
    else
        log_info "Local is ${ahead_count} commit(s) ahead of remote"
        return "$EXIT_SUCCESS"
    fi
}

# Rebase local changes onto remote
rebase_changes() {
    log_section "Rebasing Changes"
    
    if [[ "$NO_REBASE" == "true" ]]; then
        log_warning "Rebase disabled, using merge (not recommended)"
        
        if ! git merge "${REMOTE}/${TARGET_BRANCH}" --no-edit 2>&1; then
            log_error "Merge failed"
            log_info "Resolve conflicts manually and run again"
            return "$EXIT_FAILURE"
        fi
        
        log_success "Merge completed"
        return "$EXIT_SUCCESS"
    fi
    
    log_info "Rebasing onto ${REMOTE}/${TARGET_BRANCH}..."
    
    if ! git rebase "${REMOTE}/${TARGET_BRANCH}" 2>&1; then
        log_error "Rebase failed - conflicts detected"
        
        # Check for rebase in progress
        if [[ -d "$(git rev-parse --git-path rebase-merge)" ]] || \
           [[ -d "$(git rev-parse --git-path rebase-apply)" ]]; then
            log_info ""
            log_info "Rebase is in progress. To resolve:"
            log_info "  1. Fix the conflicts in the marked files"
            log_info "  2. Stage resolved files: git add <file>"
            log_info "  3. Continue rebase: git rebase --continue"
            log_info "  4. Or abort: git rebase --abort"
            log_info ""
            log_info "Conflicted files:"
            git diff --name-only --diff-filter=U 2>/dev/null || true
        fi
        
        return "$EXIT_FAILURE"
    fi
    
    log_success "Rebase completed successfully"
    return "$EXIT_SUCCESS"
}

# Push changes to remote with retry logic
push_changes() {
    log_section "Pushing to Remote"
    
    local push_args=()
    
    # Always use --force-with-lease instead of --force for safety
    if [[ "$USE_FORCE" == "true" ]]; then
        push_args+=("--force-with-lease")
        log_warning "Using force-with-lease (safe force push)"
        log_info "Push will fail if remote has new commits"
    fi
    
    # Set upstream if needed
    push_args+=("--set-upstream" "$REMOTE" "$TARGET_BRANCH")
    
    log_info "Pushing ${TARGET_BRANCH} to ${REMOTE}..."
    
    local retry_count=0
    local push_success=false
    local push_output
    local push_exit=0
    
    while [[ $retry_count -lt $MAX_RETRIES ]] && [[ "$push_success" == "false" ]]; do
        push_exit=0
        
        if [[ $retry_count -gt 0 ]]; then
            log_info "Retry attempt $retry_count/$MAX_RETRIES after ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        fi
        
        if push_output=$(git push "${push_args[@]}" 2>&1); then
            push_success=true
            log_success "Push successful"
        else
            push_exit=$?
            retry_count=$((retry_count + 1))
            
            if [[ $retry_count -lt $MAX_RETRIES ]]; then
                log_warning "Push failed (exit $push_exit), will retry..."
                
                # Analyze failure reason for specific handling
                if echo "$push_output" | grep -q "rejected"; then
                    log_info "Push was rejected - remote has new commits"
                    log_info "Attempting to fetch and rebase before retry..."
                    
                    # Auto-retry with fetch and rebase
                    if git fetch "$REMOTE" 2>/dev/null && \
                       git rebase "${REMOTE}/${TARGET_BRANCH}" 2>/dev/null; then
                        log_success "Rebased onto ${REMOTE}/${TARGET_BRANCH}"
                    else
                        log_warning "Auto-rebase failed, manual intervention may be needed"
                    fi
                elif echo "$push_output" | grep -q "lease"; then
                    log_info "Force-with-lease prevented push - remote has changed"
                fi
            else
                log_error "Push failed after $MAX_RETRIES attempts"
                echo "$push_output" >&2
            fi
        fi
    done
    
    if [[ "$push_success" == "false" ]]; then
        log_error "All retry attempts exhausted"
        
        # Final failure analysis
        if echo "$push_output" | grep -q "rejected"; then
            log_info "Remote has diverged - run sync-and-push.sh again to rebase and retry"
        elif echo "$push_output" | grep -q "lease"; then
            log_info "Force-with-lease prevented push - review changes and retry if appropriate"
        fi
        
        return "$EXIT_FAILURE"
    fi
    
    # Extract push details
    if echo "$push_output" | grep -q "remote:"; then
        echo "$push_output" | grep "remote:" | head -5 | while read -r line; do
            log_info "$line"
        done
    fi
    
    return "$EXIT_SUCCESS"
}

# Main execution
main() {
    parse_args "$@"
    
    cd "$REPO_ROOT"
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          SYNC AND PUSH                                      ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Validate environment
    validate_environment || exit "$?"
    
    # Handle local changes
    handle_local_changes || exit "$?"
    
    # Fetch from remote
    fetch_remote || exit "$?"
    
    # Check divergence
    local divergence_result=0
    check_divergence || divergence_result=$?
    
    # If diverged, rebase
    if [[ $divergence_result -eq 3 ]]; then
        rebase_changes || exit "$?"
    fi
    
    # Push changes
    push_changes || exit "$?"
    
    # Cleanup (unstash if needed)
    cleanup
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC} ${GREEN}✓ SYNC AND PUSH COMPLETED${NC}                                 ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    exit "$EXIT_SUCCESS"
}

# Trap exit to ensure cleanup
trap cleanup EXIT

main "$@"
