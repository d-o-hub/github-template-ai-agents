#!/usr/bin/env bash
# atomic-commit.sh - Atomic commit execution script
# Stages all changes, validates, and commits with conventional format
#
# Usage: ./scripts/atomic-commit/atomic-commit.sh [OPTIONS] [commit-message]
#
# Options:
#   --type <type>       Commit type (feat, fix, docs, etc.)
#   --scope <scope>     Commit scope
#   --no-verify         Skip pre-commit checks (DANGEROUS)
#   --amend             Amend previous commit
#   --dry-run           Show what would be done without executing
#
# Exit codes:
#   0 = Commit successful
#   1 = Commit failed
#   2 = Validation warning (treated as failure)

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_FAILURE=1
readonly EXIT_WARNING=2

# Configuration
COMMIT_TYPE=""
COMMIT_SCOPE=""
COMMIT_MESSAGE=""
NO_VERIFY="${NO_VERIFY:-false}"
AMEND="${AMEND:-false}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_HOOKS="${SKIP_HOOKS:-false}"
VERBOSE="${VERBOSE:-true}"
AUTO_STAGE="${AUTO_STAGE:-true}"

# Color definitions
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly BOLD='\033[1m'
    readonly NC='\033[0m'
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly MAGENTA=''
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

log_dry_run() {
    echo -e "${MAGENTA}[DRY-RUN]${NC} $1"
}

# Error handler
error_handler() {
    local line=$1
    log_error "Unexpected error in ${SCRIPT_NAME} at line ${line}"
    exit "$EXIT_FAILURE"
}
trap 'error_handler $LINENO' ERR

# Show help
show_help() {
    cat << 'EOF'
Usage: atomic-commit.sh [OPTIONS] [commit-message]

Create an atomic commit with validation and conventional formatting.

ARGUMENTS:
    commit-message      The commit message (required unless --amend)

OPTIONS:
    --type <type>       Commit type: feat, fix, docs, style, refactor,
                        test, chore, ci, build, perf (default: auto-detect)
    --scope <scope>     Commit scope (e.g., api, ui, auth)
    --no-verify         Skip pre-commit checks (DANGEROUS)
    --amend             Amend the previous commit
    --dry-run           Show what would be done without executing
    --no-stage          Don't auto-stage modified files
    --quiet, -q         Minimal output
    --help, -h          Show this help message

ENVIRONMENT:
    NO_VERIFY           Set to 'true' to skip verification
    DRY_RUN             Set to 'true' for dry run mode
    VERBOSE             Set to 'false' for quiet mode

EXIT CODES:
    0 = Success
    1 = Failure
    2 = Warning (treated as failure)

EXAMPLES:
    # Simple commit with auto-detected type
    atomic-commit.sh "Add user authentication"

    # Conventional commit with type and scope
    atomic-commit.sh --type feat --scope auth "Add OAuth2 support"

    # Amend previous commit
    atomic-commit.sh --amend "Updated commit message"

    # Dry run to preview changes
    atomic-commit.sh --dry-run --type fix "Fix login bug"
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                COMMIT_TYPE="$2"
                shift 2
                ;;
            --scope)
                COMMIT_SCOPE="$2"
                shift 2
                ;;
            --no-verify)
                NO_VERIFY="true"
                shift
                ;;
            --amend)
                AMEND="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --no-stage)
                AUTO_STAGE="false"
                shift
                ;;
            --quiet|-q)
                VERBOSE="false"
                shift
                ;;
            --help|-h)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            --)
                shift
                COMMIT_MESSAGE="$*"
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit "$EXIT_FAILURE"
                ;;
            *)
                if [[ -z "$COMMIT_MESSAGE" ]]; then
                    COMMIT_MESSAGE="$1"
                else
                    COMMIT_MESSAGE="${COMMIT_MESSAGE} $1"
                fi
                shift
                ;;
        esac
    done
}

# Validate the environment
validate_environment() {
    log_section "Environment Validation"
    
    # Check we're in a git repo
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository"
        return "$EXIT_FAILURE"
    fi
    log_success "Git repository validated"
    
    # Check git identity is configured
    if ! git config user.name > /dev/null 2>&1; then
        log_error "Git user.name not configured"
        log_info "Run: git config user.name 'Your Name'"
        return "$EXIT_FAILURE"
    fi
    
    if ! git config user.email > /dev/null 2>&1; then
        log_error "Git user.email not configured"
        log_info "Run: git config user.email 'your@email.com'"
        return "$EXIT_FAILURE"
    fi
    log_success "Git identity configured"
    
    # Check for merge/rebase in progress
    if [[ -d "$(git rev-parse --git-path rebase-merge)" ]] || \
       [[ -d "$(git rev-parse --git-path rebase-apply)" ]] || \
       [[ -f "$(git rev-parse --git-path MERGE_HEAD)" ]]; then
        log_error "Repository is in merge/rebase state"
        return "$EXIT_FAILURE"
    fi
    
    return "$EXIT_SUCCESS"
}

# Auto-detect commit type from changes
auto_detect_type() {
    local files_changed="${1:-}"
    
    if [[ -z "$files_changed" ]]; then
        echo "chore"
        return
    fi
    
    # Check for test files
    if echo "$files_changed" | grep -qE '(test|spec)\.(js|ts|py|rs|go|sh)$'; then
        echo "test"
        return
    fi
    
    # Check for documentation
    if echo "$files_changed" | grep -qE '\.(md|txt|rst)$'; then
        echo "docs"
        return
    fi
    
    # Check for CI/config files
    if echo "$files_changed" | grep -qE '^(\.github|\.gitlab|scripts/|Makefile|Dockerfile)'; then
        echo "ci"
        return
    fi
    
    # Check for dependency files
    if echo "$files_changed" | grep -qE '(package\.json|Cargo\.toml|requirements\.txt|go\.mod)'; then
        echo "build"
        return
    fi
    
    # Check for source files (src/, lib/, etc.)
    if echo "$files_changed" | grep -qE '^(src/|lib/|app/|components/)'; then
        echo "feat"
        return
    fi
    
    # Default
    echo "chore"
}

# Build the full conventional commit message
build_commit_message() {
    local type="${1:-feat}"
    local scope="${2:-}"
    local description="${3:-}"
    
    local full_message="${type}"
    
    if [[ -n "$scope" ]]; then
        full_message="${full_message}(${scope})"
    fi
    
    full_message="${full_message}: ${description}"
    
    echo "$full_message"
}

# Validate the commit message format
validate_commit_message() {
    local msg="${1:-}"
    
    log_section "Commit Message Validation"
    
    # Check empty message
    if [[ -z "${msg// /}" ]]; then
        log_error "Commit message cannot be empty"
        return "$EXIT_FAILURE"
    fi
    
    # Check conventional commit format
    local pattern='^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert)(\([a-zA-Z0-9_-]+\))?!?: .+'
    
    if ! echo "$msg" | grep -qE "$pattern"; then
        log_error "Invalid conventional commit format"
        log_info "Expected: <type>[(scope)]: <description>"
        log_info "Types: feat, fix, docs, style, refactor, test, chore, ci, build, perf, revert"
        log_info "Example: feat(auth): add OAuth2 login support"
        return "$EXIT_FAILURE"
    fi
    
    # Check subject line length
    local subject
    subject=$(echo "$msg" | head -1)
    if [[ ${#subject} -gt 72 ]]; then
        log_warning "Subject line exceeds 72 characters (${#subject})"
        log_info "Consider shortening: ${subject:0:72}..."
        # Warning is treated as failure
        return "$EXIT_FAILURE"
    fi
    
    log_success "Commit message format valid"
    return "$EXIT_SUCCESS"
}

# Run pre-commit checks
run_pre_commit_checks() {
    if [[ "$NO_VERIFY" == "true" ]]; then
        log_warning "Skipping pre-commit checks (--no-verify specified)"
        return "$EXIT_SUCCESS"
    fi
    
    log_section "Pre-Commit Checks"
    
    local pre_commit_script="${SCRIPT_DIR}/pre-commit-check.sh"
    
    if [[ ! -f "$pre_commit_script" ]]; then
        log_error "Pre-commit check script not found: $pre_commit_script"
        return "$EXIT_FAILURE"
    fi
    
    log_info "Running pre-commit checks..."
    
    if ! "$pre_commit_script" --staged-only; then
        log_error "Pre-commit checks failed"
        return "$EXIT_FAILURE"
    fi
    
    log_success "Pre-commit checks passed"
    return "$EXIT_SUCCESS"
}

# Stage changes for commit
stage_changes() {
    log_section "Staging Changes"
    
    if [[ "$AUTO_STAGE" != "true" ]]; then
        log_info "Auto-staging disabled, using existing staged changes"
    else
        log_info "Staging all modified and new files..."
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would execute: git add -A"
        else
            git add -A
        fi
    fi
    
    # Check what will be committed
    local staged_files
    if [[ "$DRY_RUN" == "true" ]]; then
        staged_files=$(git diff --cached --name-only 2>/dev/null || true)
    else
        staged_files=$(git diff --cached --name-only 2>/dev/null || true)
    fi
    
    if [[ -z "$staged_files" ]]; then
        log_error "No staged changes to commit"
        log_info "Use --no-stage if you've already staged changes manually"
        return "$EXIT_FAILURE"
    fi
    
    log_info "Files to be committed:"
    echo "$staged_files" | while read -r file; do
        echo "  ${GREEN}•${NC} $file"
    done
    
    local file_count
    file_count=$(echo "$staged_files" | grep -c '^' || echo "0")
    log_success "$file_count file(s) staged for commit"
    
    return "$EXIT_SUCCESS"
}

# Execute the commit
execute_commit() {
    local full_message="${1:-}"
    
    log_section "Executing Commit"
    
    # Build git commit command
    local git_args=()
    
    if [[ "$AMEND" == "true" ]]; then
        git_args+=("--amend")
        git_args+=("--no-edit")
    fi
    
    if [[ "$NO_VERIFY" == "true" ]]; then
        git_args+=("--no-verify")
    fi
    
    git_args+=("-m" "$full_message")
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_dry_run "Would execute: git commit ${git_args[*]}"
        log_dry_run "Commit message: $full_message"
        log_success "Dry run completed - no changes made"
        return "$EXIT_SUCCESS"
    fi
    
    # Execute the commit
    log_info "Creating commit..."
    
    if ! git commit "${git_args[@]}"; then
        log_error "Commit failed"
        return "$EXIT_FAILURE"
    fi
    
    # Get commit info
    local commit_hash
    commit_hash=$(git rev-parse --short HEAD)
    local commit_subject
    commit_subject=$(git log -1 --pretty=format:"%s")
    
    log_success "Commit created successfully"
    log_info "Hash: ${CYAN}${commit_hash}${NC}"
    log_info "Message: ${commit_subject}"
    
    return "$EXIT_SUCCESS"
}

# Main execution
main() {
    parse_args "$@"
    
    cd "$REPO_ROOT"
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          ATOMIC COMMIT                                      ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Validate environment
    validate_environment || exit "$EXIT_FAILURE"
    
    # Handle amend without message
    if [[ "$AMEND" == "true" ]] && [[ -z "$COMMIT_MESSAGE" ]]; then
        # Just amend without changing message
        log_info "Amending previous commit without changing message"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log_dry_run "Would execute: git commit --amend --no-edit"
        else
            if ! git commit --amend --no-edit; then
                log_error "Amend failed"
                exit "$EXIT_FAILURE"
            fi
            log_success "Commit amended successfully"
        fi
        exit "$EXIT_SUCCESS"
    fi
    
    # Validate commit message provided
    if [[ -z "$COMMIT_MESSAGE" ]]; then
        log_error "No commit message provided"
        show_help
        exit "$EXIT_FAILURE"
    fi
    
    # Get list of changed files for auto-detection
    local changed_files=""
    if [[ "$AUTO_STAGE" == "true" ]]; then
        changed_files=$(git diff --name-only 2>/dev/null || true)
        changed_files="${changed_files}$(git diff --cached --name-only 2>/dev/null || true)"
    fi
    
    # Auto-detect type if not specified
    if [[ -z "$COMMIT_TYPE" ]]; then
        COMMIT_TYPE=$(auto_detect_type "$changed_files")
        log_info "Auto-detected commit type: ${CYAN}${COMMIT_TYPE}${NC}"
    fi
    
    # Build full conventional commit message
    local full_message
    full_message=$(build_commit_message "$COMMIT_TYPE" "$COMMIT_SCOPE" "$COMMIT_MESSAGE")
    
    log_info "Final commit message: ${CYAN}${full_message}${NC}"
    
    # Validate commit message format
    validate_commit_message "$full_message" || exit "$EXIT_FAILURE"
    
    # Run pre-commit checks
    run_pre_commit_checks || exit "$EXIT_FAILURE"
    
    # Stage changes
    stage_changes || exit "$EXIT_FAILURE"
    
    # Execute commit
    execute_commit "$full_message" || exit "$EXIT_FAILURE"
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC} ${GREEN}✓ ATOMIC COMMIT COMPLETED${NC}                                 ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    exit "$EXIT_SUCCESS"
}

main "$@"
