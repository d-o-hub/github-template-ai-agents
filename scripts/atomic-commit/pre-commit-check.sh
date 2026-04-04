#!/usr/bin/env bash
# pre-commit-check.sh - Pre-commit validation script
# Performs comprehensive checks before allowing a commit
#
# Usage: ./scripts/atomic-commit/pre-commit-check.sh [--staged-only]
#
# Exit codes:
#   0 = All checks passed
#   1 = Critical failure (blocks commit)
#   2 = Warning found (treated as failure - no skipping)
#
# Integration: Called by atomic-commit.sh before staging

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
STAGED_ONLY="${STAGED_ONLY:-false}"
VERBOSE="${VERBOSE:-true}"

# Color definitions (disabled in non-TTY or when FORCE_COLOR=0)
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
    # Warnings are NOT skipped - they block the commit
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_section() {
    echo ""
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
    echo -e "${CYAN}${BOLD}$(printf '=%.0s' $(seq 1 $((${#1} + 3))))${NC}"
}

# Error handler
# shellcheck disable=SC2329
error_handler() {
    local line=$1
    log_error "Error in ${SCRIPT_NAME} at line ${line}"
    exit "$EXIT_FAILURE"
}
trap 'error_handler $LINENO' ERR

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --staged-only)
                STAGED_ONLY="true"
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
            *)
                log_error "Unknown option: $1"
                show_help
                exit "$EXIT_FAILURE"
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
Usage: pre-commit-check.sh [OPTIONS]

Pre-commit validation script that runs comprehensive checks.

OPTIONS:
    --staged-only    Only check staged files
    --quiet, -q      Minimal output
    --help, -h       Show this help message

ENVIRONMENT:
    STAGED_ONLY      Same as --staged-only (default: false)
    VERBOSE          Enable verbose output (default: true)
    FORCE_COLOR      Set to 0 to disable colors

Exit codes:
    0 = All checks passed
    1 = Critical failure
    2 = Warning (treated as failure)
EOF
}

# Check if we're in a git repository
check_git_repo() {
    log_section "Repository Validation"
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository"
        return "$EXIT_FAILURE"
    fi
    
    log_success "Git repository detected"
    
    # Check if we're in the middle of a merge/rebase
    if [[ -d "$(git rev-parse --git-path rebase-merge)" ]] || \
       [[ -d "$(git rev-parse --git-path rebase-apply)" ]] || \
       [[ -f "$(git rev-parse --git-path MERGE_HEAD)" ]]; then
        log_error "Repository is in merge/rebase state. Resolve before committing."
        return "$EXIT_FAILURE"
    fi
    
    log_success "Repository state is clean"
    return "$EXIT_SUCCESS"
}

# Run the quality gate
check_quality_gate() {
    log_section "Quality Gate"
    
    local quality_gate_script="${REPO_ROOT}/scripts/quality_gate.sh"
    
    if [[ ! -f "$quality_gate_script" ]]; then
        log_error "Quality gate script not found: $quality_gate_script"
        return "$EXIT_FAILURE"
    fi
    
    log_info "Running quality gate..."
    
    if ! "$quality_gate_script"; then
        log_error "Quality gate failed"
        return "$EXIT_FAILURE"
    fi
    
    log_success "Quality gate passed"
    return "$EXIT_SUCCESS"
}

# Check for secrets in code
check_secrets() {
    log_section "Secret Detection"

    local found_secrets=0
    
    # Patterns that indicate secrets (case-insensitive)
    local secret_patterns=(
        'password\s*=\s*["\047][^"\047]+["\047]'  # password = "..."
        'passwd\s*=\s*["\047][^"\047]+["\047]'    # passwd = "..."
        'pwd\s*=\s*["\047][^"\047]{8,}["\047]'     # pwd = "..." (8+ chars)
        'secret\s*=\s*["\047][^"\047]+["\047]'    # secret = "..."
        'api[_-]?key\s*=\s*["\047][^"\047]+["\047]'  # api_key = "..."
        'apikey\s*=\s*["\047][^"\047]+["\047]'    # apikey = "..."
        'auth[_-]?token\s*=\s*["\047][^"\047]+["\047]'  # auth_token = "..."
        'access[_-]?token\s*=\s*["\047][^"\047]+["\047]' # access_token = "..."
        'bearer\s+[a-zA-Z0-9_-]{20,}'              # Bearer tokens
        'private[_-]?key\s*=\s*["\047][^"\047]+["\047]' # private_key = "..."
        'sk-[a-zA-Z0-9]{20,}'                       # OpenAI-style keys
        'ghp_[a-zA-Z0-9]{36}'                       # GitHub PAT
        'gho_[a-zA-Z0-9]{36}'                       # GitHub OAuth
        'AKIA[0-9A-Z]{16}'                           # AWS Access Key ID
        'AIza[0-9A-Za-z_-]{35}'                      # Google API Key
        'basic\s+[a-zA-Z0-9+/]{20,}={0,2}'           # Basic auth (base64)
    )
    
    # Get files to check
    local files_to_check=""
    if [[ "$STAGED_ONLY" == "true" ]]; then
        files_to_check=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    else
        files_to_check=$(git diff --name-only --diff-filter=ACM 2>/dev/null || true)
        files_to_check="${files_to_check}$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)"
    fi
    
    # Remove duplicates
    files_to_check=$(echo "$files_to_check" | sort -u)
    
    if [[ -z "$files_to_check" ]]; then
        log_info "No files to check for secrets"
        return "$EXIT_SUCCESS"
    fi
    
    log_info "Scanning $(echo "$files_to_check" | wc -l) file(s) for secrets..."
    
    # Check each file
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        
        # Skip binary files
        if file "$file" | grep -q "binary"; then
            continue
        fi
        
        # Skip certain file types
        if [[ "$file" =~ \.(jpg|jpeg|png|gif|ico|pdf|zip|tar|gz|woff|woff2|ttf|eot)$ ]]; then
            continue
        fi
        
        # Skip node_modules and vendor directories
        if [[ "$file" =~ (node_modules|vendor|\.git)/ ]]; then
            continue
        fi
        
        for pattern in "${secret_patterns[@]}"; do
            # Use mktemp for secure temporary file
            local temp_file
            temp_file=$(mktemp) || { log_error "Failed to create temp file"; return "$EXIT_FAILURE"; }
            trap 'rm -f "$temp_file"' RETURN
            
            if grep -iEn "$pattern" "$file" 2>/dev/null | head -5 > "$temp_file"; then
                if [[ -s "$temp_file" ]]; then
                    log_error "Potential secret found in: $file"
                    while IFS= read -r match; do
                        echo "  ${YELLOW}  Line: $match${NC}" >&2
                    done < "$temp_file"
                    found_secrets=1
                fi
            fi
        done
    done <<< "$files_to_check"
    
    # Check for .env files that shouldn't be committed
    if echo "$files_to_check" | grep -qE '^.env'; then
        log_error ".env file(s) detected in commit:"
        echo "$files_to_check" | grep -E '^.env' | while read -r f; do
            echo "  ${YELLOW}  $f${NC}"
        done
        log_error "Environment files should not be committed. Add to .gitignore."
        found_secrets=1
    fi
    
    if [[ $found_secrets -eq 1 ]]; then
        log_error "Potential secrets detected! Review before committing."
        return "$EXIT_FAILURE"
    fi
    
    log_success "No secrets detected"
    return "$EXIT_SUCCESS"
}

# Check that tests pass
check_tests() {
    log_section "Test Execution"
    
    local test_result=0
    
    # Determine which test command to run based on project type
    if [[ -f "${REPO_ROOT}/Cargo.toml" ]]; then
        log_info "Running Rust tests..."
        if ! (cd "$REPO_ROOT" && cargo test --lib 2>&1); then
            test_result=1
        fi
    elif [[ -f "${REPO_ROOT}/package.json" ]]; then
        log_info "Running Node.js tests..."
        if [[ -f "${REPO_ROOT}/pnpm-lock.yaml" ]]; then
            if ! (cd "$REPO_ROOT" && pnpm test 2>&1); then
                test_result=1
            fi
        elif [[ -f "${REPO_ROOT}/package-lock.json" ]]; then
            if ! (cd "$REPO_ROOT" && npm test 2>&1); then
                test_result=1
            fi
        fi
    elif [[ -f "${REPO_ROOT}/requirements.txt" ]] || [[ -f "${REPO_ROOT}/pyproject.toml" ]]; then
        log_info "Running Python tests..."
        if command -v pytest &> /dev/null; then
            if ! (cd "$REPO_ROOT" && pytest tests/ -q 2>&1); then
                test_result=1
            fi
        else
            log_warning "pytest not found, skipping Python tests"
            return "$EXIT_WARNING"
        fi
    elif [[ -f "${REPO_ROOT}/go.mod" ]]; then
        log_info "Running Go tests..."
        if ! (cd "$REPO_ROOT" && go test ./... 2>&1); then
            test_result=1
        fi
    else
        log_info "No recognized test framework found"
        return "$EXIT_SUCCESS"
    fi
    
    if [[ $test_result -ne 0 ]]; then
        log_error "Tests failed"
        return "$EXIT_FAILURE"
    fi
    
    log_success "All tests passed"
    return "$EXIT_SUCCESS"
}

# Verify commit message format (if provided)
# shellcheck disable=SC2329
check_commit_message() {
    log_section "Commit Message Validation"
    
    local commit_msg_file="${1:-}"
    
    if [[ -z "$commit_msg_file" ]] || [[ ! -f "$commit_msg_file" ]]; then
        log_info "No commit message file provided, skipping validation"
        return "$EXIT_SUCCESS"
    fi
    
    local msg
    msg=$(cat "$commit_msg_file")
    
    # Check for empty message
    if [[ -z "${msg// /}" ]]; then
        log_error "Commit message is empty"
        return "$EXIT_FAILURE"
    fi
    
    # Check conventional commit format
    # Format: type(scope): description or type: description
    local conventional_pattern='^(feat|fix|docs|style|refactor|test|chore|ci|build|perf)(\([a-z-]+\))?: .+'
    
    if ! echo "$msg" | grep -qE "$conventional_pattern"; then
        log_warning "Commit message doesn't follow conventional commit format"
        log_info "Expected format: type(scope): description"
        log_info "Types: feat, fix, docs, style, refactor, test, chore, ci, build, perf"
        
        # This is a warning but we treat warnings as failures
        return "$EXIT_WARNING"
    fi
    
    # Check message length (subject line should be <= 72 chars)
    local subject
    subject=$(echo "$msg" | head -1)
    if [[ ${#subject} -gt 72 ]]; then
        log_warning "Subject line exceeds 72 characters (${#subject} chars)"
        return "$EXIT_WARNING"
    fi
    
    log_success "Commit message format valid"
    return "$EXIT_SUCCESS"
}

# Main execution
main() {
    parse_args "$@"
    
    cd "$REPO_ROOT"
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          PRE-COMMIT CHECKS                                  ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    local overall_result=0
    local check_results=()
    
    # Run checks
    check_git_repo
    check_results+=($?)
    
    check_quality_gate
    check_results+=($?)
    
    check_secrets
    check_results+=($?)
    
    check_tests
    check_results+=($?)
    
    # Aggregate results
    for result in "${check_results[@]}"; do
        if [[ $result -gt $overall_result ]]; then
            overall_result=$result
        fi
    done
    
    # Final summary
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    
    if [[ $overall_result -eq $EXIT_SUCCESS ]]; then
        echo -e "${BOLD}║${NC} ${GREEN}✓ ALL CHECKS PASSED${NC}                                      ${BOLD}║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        exit "$EXIT_SUCCESS"
    elif [[ $overall_result -eq $EXIT_WARNING ]]; then
        echo -e "${BOLD}║${NC} ${YELLOW}⚠ CHECKS FAILED (Warning)${NC}                                ${BOLD}║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}Warnings are treated as failures. Fix issues before committing.${NC}"
        exit "$EXIT_FAILURE"  # Warnings treated as failures
    else
        echo -e "${BOLD}║${NC} ${RED}✗ CHECKS FAILED (Critical)${NC}                               ${BOLD}║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${RED}Critical failures detected. Fix issues before committing.${NC}"
        exit "$EXIT_FAILURE"
    fi
}

main "$@"
