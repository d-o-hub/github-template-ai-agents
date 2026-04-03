#!/usr/bin/env bash
# verify-checks.sh - GitHub Actions checks verification script
# Polls GitHub Actions until all checks pass or fail
#
# Usage: ./scripts/atomic-commit/verify-checks.sh [OPTIONS]
#
# Options:
#   --pr <number>       Verify checks for specific PR
#   --branch <name>     Verify checks for branch (default: current)
#   --timeout <seconds> Max wait time (default: 600)
#   --watch             Watch mode - keep polling until completion
#
# Exit codes:
#   0 = All checks passed
#   1 = One or more checks failed
#   2 = Timeout or other warning state

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
PR_NUMBER=""
TARGET_BRANCH=""
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-600}"
POLL_INTERVAL="${POLL_INTERVAL:-15}"
WATCH_MODE="${WATCH_MODE:-false}"
VERBOSE="${VERBOSE:-true}"
REQUIRE_ALL="${REQUIRE_ALL:-true}"
SHOW_PROGRESS="${SHOW_PROGRESS:-true}"

# State tracking
START_TIME=$(date +%s)
LAST_STATUS=""

# Color definitions
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly BOLD='\033[1m'
    readonly DIM='\033[2m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly BOLD=''
    readonly DIM=''
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

# Progress display
show_waiting() {
    if [[ "$SHOW_PROGRESS" == "true" ]]; then
        local elapsed=$(( $(date +%s) - START_TIME ))
        local mins=$(( elapsed / 60 ))
        local secs=$(( elapsed % 60 ))
        printf "${DIM}Waiting for checks... %02d:%02d elapsed${NC}\r" "$mins" "$secs"
    fi
}

clear_progress() {
    if [[ "$SHOW_PROGRESS" == "true" ]]; then
        printf "\r%${COLUMNS:-80}s\r" " "
    fi
}

# Error handler
# shellcheck disable=SC2329
error_handler() {
    local line=$1
    log_error "Unexpected error in ${SCRIPT_NAME} at line ${line}"
    exit "$EXIT_FAILURE"
}
trap 'error_handler $LINENO' ERR

# Show help
show_help() {
    cat << 'EOF'
Usage: verify-checks.sh [OPTIONS]

Poll GitHub Actions until all checks complete.

OPTIONS:
    --pr <number>         Verify checks for specific PR
    --branch <name>       Verify checks for branch (default: current)
    --timeout <seconds>   Max wait time (default: 600 = 10 min)
    --poll <seconds>      Polling interval (default: 15)
    --watch, -w           Watch mode - poll until completion
    --quiet, -q           Minimal output
    --fail-ok             Exit 0 even if checks fail
    --help, -h            Show this help message

ENVIRONMENT:
    TIMEOUT_SECONDS       Max wait time in seconds
    POLL_INTERVAL         Seconds between checks
    WATCH_MODE            Set to 'true' for watch mode
    VERBOSE               Set to 'false' for quiet mode

EXIT CODES:
    0 = All checks passed (or --fail-ok with failures)
    1 = One or more checks failed
    2 = Timeout or warning state

EXAMPLES:
    # Check current branch
    verify-checks.sh

    # Watch checks on a PR
    verify-checks.sh --pr 42 --watch

    # Check with 5 minute timeout
    verify-checks.sh --timeout 300
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --pr)
                PR_NUMBER="$2"
                shift 2
                ;;
            --branch)
                TARGET_BRANCH="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT_SECONDS="$2"
                shift 2
                ;;
            --poll)
                POLL_INTERVAL="$2"
                shift 2
                ;;
            --watch|-w)
                WATCH_MODE="true"
                shift
                ;;
            --quiet|-q)
                VERBOSE="false"
                SHOW_PROGRESS="false"
                shift
                ;;
            --fail-ok)
                REQUIRE_ALL="false"
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
    
    # Check git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository"
        return "$EXIT_FAILURE"
    fi
    log_success "Git repository validated"
    
    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) not installed"
        return "$EXIT_FAILURE"
    fi
    log_success "GitHub CLI found"
    
    # Check authentication
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI"
        return "$EXIT_FAILURE"
    fi
    log_success "GitHub CLI authenticated"
    
    # Determine target
    if [[ -n "$PR_NUMBER" ]]; then
        log_info "Target: PR #${PR_NUMBER}"
    elif [[ -n "$TARGET_BRANCH" ]]; then
        log_info "Target branch: ${TARGET_BRANCH}"
    else
        TARGET_BRANCH=$(git branch --show-current 2>/dev/null || true)
        if [[ -z "$TARGET_BRANCH" ]]; then
            log_error "Not on a branch"
            return "$EXIT_FAILURE"
        fi
        log_info "Current branch: ${TARGET_BRANCH}"
    fi
    
    return "$EXIT_SUCCESS"
}

# Get checks for PR or branch
get_checks() {
    local checks_output=""
    local checks_exit=0
    
    if [[ -n "$PR_NUMBER" ]]; then
        # Get checks for PR
        if ! checks_output=$(gh pr checks "$PR_NUMBER" --json "name,state,link" 2>&1); then
            # If JSON output fails, try plain text
            checks_output=$(gh pr checks "$PR_NUMBER" 2>&1 || true)
            checks_exit=$?
        fi
    else
        # Get checks for branch via API
        local repo
        repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "")
        
        if [[ -n "$repo" ]]; then
            # Try to get checks via gh run list
            checks_output=$(gh run list --branch "$TARGET_BRANCH" --json "name,status,conclusion,url" 2>&1 || true)
        fi
    fi
    
    echo "$checks_output"
    return $checks_exit
}

# Parse check results
parse_checks() {
    local checks_data="${1:-}"
    
    local pending=0
    local success=0
    local failure=0
    local total=0
    
    # Parse JSON output if available
    if echo "$checks_data" | grep -q "\[" 2>/dev/null; then
        # JSON parsing for gh pr checks
        total=$(echo "$checks_data" | grep -c '"name"' || echo "0")
        pending=$(echo "$checks_data" | grep -c '"state":"PENDING"' || echo "0")
        success=$(echo "$checks_data" | grep -c '"state":"SUCCESS"' || echo "0")
        failure=$(echo "$checks_data" | grep -c '"state":"FAILURE"' || echo "0")
    else
        # Parse text output
        if echo "$checks_data" | grep -q "pass"; then
            success=$(echo "$checks_data" | grep -c "pass" || echo "0")
        fi
        if echo "$checks_data" | grep -q "fail"; then
            failure=$(echo "$checks_data" | grep -c "fail" || echo "0")
        fi
        if echo "$checks_data" | grep -q "pending\|in_progress"; then
            pending=$(echo "$checks_data" | grep -c "pending\|in_progress" || echo "0")
        fi
    fi
    
    # If no checks found but we're querying, assume still pending
    if [[ $total -eq 0 ]] && [[ $pending -eq 0 ]] && [[ $success -eq 0 ]] && [[ $failure -eq 0 ]]; then
        pending=1  # Indicate we need to wait
    fi
    
    echo "${pending},${success},${failure},${total}"
}

# Display check results
display_results() {
    local pending="${1:-0}"
    local success="${2:-0}"
    local failure="${3:-0}"
    local total="${4:-0}"
    
    clear_progress
    
    echo ""
    echo -e "${BOLD}Check Results:${NC}"
    echo -e "  ${GREEN}✓ Passed:${NC}   ${success}"
    echo -e "  ${RED}✗ Failed:${NC}   ${failure}"
    echo -e "  ${YELLOW}○ Pending:${NC}  ${pending}"
    echo -e "  ${BOLD}  Total:${NC}    ${total}"
    echo ""
}

# Poll checks until completion
poll_checks() {
    log_section "Polling GitHub Actions"
    
    log_info "Timeout: ${TIMEOUT_SECONDS}s | Poll interval: ${POLL_INTERVAL}s"
    log_info "Press Ctrl+C to cancel"
    echo ""
    
    local iteration=0
    local first_run=true
    
    while true; do
        iteration=$((iteration + 1))
        
        # Check timeout
        local elapsed=$(( $(date +%s) - START_TIME ))
        if [[ $elapsed -ge $TIMEOUT_SECONDS ]]; then
            clear_progress
            log_warning "Timeout reached after ${TIMEOUT_SECONDS} seconds"
            return "$EXIT_WARNING"
        fi
        
        # Get current check status
        local checks_data
        checks_data=$(get_checks)
        
        local parsed
        parsed=$(parse_checks "$checks_data")
        
        local pending
        local success
        local failure
        local total
        
        pending=$(echo "$parsed" | cut -d',' -f1)
        success=$(echo "$parsed" | cut -d',' -f2)
        failure=$(echo "$parsed" | cut -d',' -f3)
        total=$(echo "$parsed" | cut -d',' -f4)
        
        # Display status on first run or when changed
        local current_status="${pending},${success},${failure}"
        if [[ "$first_run" == "true" ]] || [[ "$current_status" != "$LAST_STATUS" ]]; then
            display_results "$pending" "$success" "$failure" "$total"
            LAST_STATUS="$current_status"
            first_run=false
        fi
        
        # Check if complete
        if [[ $pending -eq 0 ]]; then
            clear_progress
            
            if [[ $failure -eq 0 ]]; then
                log_success "All checks passed!"
                return "$EXIT_SUCCESS"
            else
                log_error "${failure} check(s) failed"
                
                # Show failed checks
                echo ""
                echo -e "${BOLD}Failed checks:${NC}"
                echo "$checks_data" | grep -E "fail" | while read -r line; do
                    echo "  ${RED}•${NC} $line"
                done
                
                if [[ "$REQUIRE_ALL" == "true" ]]; then
                    return "$EXIT_FAILURE"
                else
                    log_warning "--fail-ok specified, exiting with success"
                    return "$EXIT_SUCCESS"
                fi
            fi
        fi
        
        # Show progress
        show_waiting
        
        # Check if we should continue watching
        if [[ "$WATCH_MODE" != "true" ]] && [[ $iteration -ge 1 ]]; then
            clear_progress
            log_info "Checks still pending. Use --watch to wait for completion."
            return "$EXIT_WARNING"
        fi
        
        # Wait before next poll
        sleep "$POLL_INTERVAL"
    done
}

# Main execution
main() {
    parse_args "$@"
    
    cd "$REPO_ROOT"
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          VERIFY GITHUB CHECKS                               ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Validate environment
    validate_environment || exit "$?"
    
    # Poll checks
    poll_checks
    local result=$?
    
    # Final output
    echo ""
    if [[ $result -eq $EXIT_SUCCESS ]]; then
        echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║${NC} ${GREEN}✓ ALL CHECKS PASSED${NC}                                      ${BOLD}║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    elif [[ $result -eq $EXIT_WARNING ]]; then
        echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║${NC} ${YELLOW}⚠ CHECKS INCOMPLETE${NC}                                      ${BOLD}║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║${NC} ${RED}✗ CHECKS FAILED${NC}                                          ${BOLD}║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    fi
    echo ""
    
    exit $result
}

# Handle Ctrl+C gracefully
trap 'clear_progress; echo ""; log_warning "Interrupted by user"; exit 130' INT

main "$@"
