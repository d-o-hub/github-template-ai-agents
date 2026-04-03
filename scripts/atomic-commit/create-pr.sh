#!/usr/bin/env bash
# create-pr.sh - Pull request creation script using gh CLI
# Creates PRs with proper template and validation
#
# Usage: ./scripts/atomic-commit/create-pr.sh [OPTIONS]
#
# Options:
#   --title <title>     PR title (required)
#   --body <body>       PR body (or use template)
#   --base <branch>     Target branch (default: main)
#   --draft             Create as draft PR
#   --template <file>   Use custom template file
#
# Exit codes:
#   0 = PR created successfully
#   1 = Failed to create PR
#   2 = Warning state (needs manual action)

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
PR_TITLE=""
PR_BODY=""
BASE_BRANCH="${BASE_BRANCH:-main}"
HEAD_BRANCH=""
DRAFT="${DRAFT:-false}"
TEMPLATE_FILE=""
VERBOSE="${VERBOSE:-true}"
AUTO_FILL="${AUTO_FILL:-true}"
WEB_OPEN="${WEB_OPEN:-false}"
LABELS="${LABELS:-}"
ASSIGNEES="${ASSIGNEES:-}"
REVIEWERS="${REVIEWERS:-}"

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
Usage: create-pr.sh [OPTIONS]

Create a GitHub pull request with proper formatting and validation.

OPTIONS:
    --title <title>       PR title (required if not auto-generated)
    --body <body>         PR body text
    --base <branch>       Target branch (default: main)
    --head <branch>       Source branch (default: current branch)
    --draft               Create as draft PR
    --template <file>     Use custom PR template
    --labels <labels>     Comma-separated list of labels
    --reviewers <users>   Comma-separated list of reviewers
    --assignees <users>   Comma-separated list of assignees
    --web                 Open PR in browser after creation
    --no-auto-fill        Don't auto-fill PR body from commits
    --quiet, -q           Minimal output
    --help, -h            Show this help message

ENVIRONMENT:
    BASE_BRANCH           Default target branch (default: main)
    DRAFT                 Set to 'true' for draft PRs
    LABELS                Default labels to apply
    VERBOSE               Set to 'false' for quiet mode

EXIT CODES:
    0 = PR created successfully
    1 = Failed to create PR
    2 = Warning (PR might need manual review)

EXAMPLES:
    # Create PR with auto-generated title from commits
    create-pr.sh

    # Create PR with custom title
    create-pr.sh --title "feat(auth): Add OAuth2 support"

    # Create draft PR with labels
    create-pr.sh --draft --labels "enhancement,WIP"

    # Create PR targeting develop branch
    create-pr.sh --base develop --title "Fix: Resolve memory leak"
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --title)
                PR_TITLE="$2"
                shift 2
                ;;
            --body)
                PR_BODY="$2"
                shift 2
                ;;
            --base)
                BASE_BRANCH="$2"
                shift 2
                ;;
            --head)
                HEAD_BRANCH="$2"
                shift 2
                ;;
            --draft)
                DRAFT="true"
                shift
                ;;
            --template)
                TEMPLATE_FILE="$2"
                shift 2
                ;;
            --labels)
                LABELS="$2"
                shift 2
                ;;
            --reviewers)
                REVIEWERS="$2"
                shift 2
                ;;
            --assignees)
                ASSIGNEES="$2"
                shift 2
                ;;
            --web)
                WEB_OPEN="true"
                shift
                ;;
            --no-auto-fill)
                AUTO_FILL="false"
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
            -*)
                log_error "Unknown option: $1"
                show_help
                exit "$EXIT_FAILURE"
                ;;
            *)
                # If title not set, use first positional arg
                if [[ -z "$PR_TITLE" ]]; then
                    PR_TITLE="$1"
                fi
                shift
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
    
    # Check gh CLI is installed
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) not installed"
        log_info "Install from: https://cli.github.com/"
        return "$EXIT_FAILURE"
    fi
    log_success "GitHub CLI found"
    
    # Check gh authentication
    if ! gh auth status &> /dev/null; then
        log_error "Not authenticated with GitHub CLI"
        log_info "Run: gh auth login"
        return "$EXIT_FAILURE"
    fi
    log_success "GitHub CLI authenticated"
    
    # Check we're in a GitHub repository
    if ! gh repo view &> /dev/null 2>&1; then
        log_error "Current repository not found on GitHub"
        return "$EXIT_FAILURE"
    fi
    log_success "GitHub repository accessible"
    
    # Get current branch if head not specified
    if [[ -z "$HEAD_BRANCH" ]]; then
        HEAD_BRANCH=$(git branch --show-current 2>/dev/null || true)
        
        if [[ -z "$HEAD_BRANCH" ]]; then
            log_error "Not on a branch (HEAD detached)"
            return "$EXIT_FAILURE"
        fi
    fi
    
    log_success "Source branch: ${CYAN}${HEAD_BRANCH}${NC}"
    log_success "Target branch: ${CYAN}${BASE_BRANCH}${NC}"
    
    # Check for unpushed commits
    local remote="${REMOTE:-origin}"
    local unpushed
    unpushed=$(git log "${remote}/${HEAD_BRANCH}..${HEAD_BRANCH}" --oneline 2>/dev/null | wc -l || echo "0")
    
    if [[ "$unpushed" -gt 0 ]]; then
        log_warning "${unpushed} commit(s) not pushed to remote"
        log_info "Push first: ./scripts/atomic-commit/sync-and-push.sh"
        return "$EXIT_FAILURE"
    fi
    
    log_success "All commits pushed to remote"
    
    # Check if PR already exists
    local existing_pr
    existing_pr=$(gh pr list --head "$HEAD_BRANCH" --base "$BASE_BRANCH" --json number --jq '.[0].number' 2>/dev/null || echo "")
    
    if [[ -n "$existing_pr" ]]; then
        log_warning "PR #${existing_pr} already exists for this branch"
        log_info "View: gh pr view ${existing_pr}"
        
        if [[ "$WEB_OPEN" == "true" ]]; then
            gh pr view "$existing_pr" --web
        fi
        
        return "$EXIT_WARNING"
    fi
    
    return "$EXIT_SUCCESS"
}

# Generate PR title from commits
generate_title() {
    log_section "Generating PR Title"
    
    # Get commit messages from unpushed commits or recent history
    local commits
    commits=$(git log "${BASE_BRANCH}..${HEAD_BRANCH}" --pretty=format:"%s" 2>/dev/null || true)
    
    if [[ -z "$commits" ]]; then
        log_warning "No commits found between branches"
        log_info "Enter PR title manually with --title"
        return "$EXIT_FAILURE"
    fi
    
    # Use the first commit message as the title
    local first_commit
    first_commit=$(echo "$commits" | head -1)
    
    # If it's already conventional format, use it directly
    if echo "$first_commit" | grep -qE '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf)(\([^)]*\))?: '; then
        PR_TITLE="$first_commit"
        log_info "Using conventional commit as title"
    else
        # Prefix with feat: as default
        PR_TITLE="feat: ${first_commit}"
        log_info "Generated title with feat: prefix"
    fi
    
    log_success "Generated title: ${CYAN}${PR_TITLE}${NC}"
    return "$EXIT_SUCCESS"
}

# Build PR body
build_pr_body() {
    log_section "Building PR Body"
    
    # If body already provided, use it
    if [[ -n "$PR_BODY" ]]; then
        log_success "Using provided PR body"
        return "$EXIT_SUCCESS"
    fi
    
    # Try to find and use template
    local template_path=""
    
    if [[ -n "$TEMPLATE_FILE" ]] && [[ -f "$TEMPLATE_FILE" ]]; then
        template_path="$TEMPLATE_FILE"
    elif [[ -f "${REPO_ROOT}/.github/PULL_REQUEST_TEMPLATE.md" ]]; then
        template_path="${REPO_ROOT}/.github/PULL_REQUEST_TEMPLATE.md"
    elif [[ -f "${REPO_ROOT}/.github/pull_request_template.md" ]]; then
        template_path="${REPO_ROOT}/.github/pull_request_template.md"
    fi
    
    if [[ -n "$template_path" ]]; then
        PR_BODY=$(cat "$template_path")
        log_success "Using template: ${template_path}"
    elif [[ "$AUTO_FILL" == "true" ]]; then
        # Auto-generate body from commits
        local commits
        commits=$(git log "${BASE_BRANCH}..${HEAD_BRANCH}" --pretty=format:"- %s" 2>/dev/null || true)
        
        PR_BODY="## Summary

${PR_TITLE}

## Changes

${commits}

## Testing

- [ ] Tests pass locally
- [ ] Code follows project style guidelines"
        
        log_success "Auto-generated PR body from commits"
    else
        # Minimal body
        PR_BODY="## Summary

${PR_TITLE}"
        log_info "Using minimal PR body"
    fi
    
    return "$EXIT_SUCCESS"
}

# Validate PR data
validate_pr_data() {
    log_section "Validating PR Data"
    
    # Validate title
    if [[ -z "${PR_TITLE// /}" ]]; then
        log_error "PR title is required"
        return "$EXIT_FAILURE"
    fi
    
    if [[ ${#PR_TITLE} -gt 72 ]]; then
        log_warning "PR title exceeds 72 characters"
        log_info "Consider shortening for better display"
        # Warning treated as failure
        return "$EXIT_FAILURE"
    fi
    
    # Check conventional format
    if ! echo "$PR_TITLE" | grep -qE '^(feat|fix|docs|style|refactor|test|chore|ci|build|perf|revert)(\([a-zA-Z0-9_-]+\))?!?: .+'; then
        log_warning "PR title doesn't follow conventional format"
        log_info "Format: type(scope): description"
        return "$EXIT_FAILURE"
    fi
    
    log_success "PR title valid"
    
    # Validate body
    if [[ -z "${PR_BODY// /}" ]]; then
        log_error "PR body is empty"
        return "$EXIT_FAILURE"
    fi
    
    # Check for unfilled template placeholders
    local placeholder_pattern='<(\[|\()?[^>]+(\]|\)?)>|{{[^}]+}}|___+|TODO|FIXME|XXX'
    if echo "$PR_BODY" | grep -qE "$placeholder_pattern"; then
        log_error "PR body contains unfilled template placeholders"
        log_info "Remove or fill in placeholders like:"
        log_info "  - <description>, {{variable}}, ___, TODO, FIXME"
        return "$EXIT_FAILURE"
    fi
    
    log_success "PR body valid"
    
    return "$EXIT_SUCCESS"
}

# Create the pull request
create_pr() {
    log_section "Creating Pull Request"
    
    # Build gh pr create command
    local gh_args=()
    
    # Title and body
    gh_args+=(--title "$PR_TITLE")
    gh_args+=(--body "$PR_BODY")
    
    # Branches
    gh_args+=(--base "$BASE_BRANCH")
    gh_args+=(--head "$HEAD_BRANCH")
    
    # Draft
    if [[ "$DRAFT" == "true" ]]; then
        gh_args+=(--draft)
        log_info "Creating as DRAFT PR"
    fi
    
    # Labels
    if [[ -n "$LABELS" ]]; then
        # Parse comma-separated labels
        IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
        for label in "${LABEL_ARRAY[@]}"; do
            gh_args+=(--label "${label// /}")
        done
        log_info "Labels: ${LABELS}"
    fi
    
    # Reviewers
    if [[ -n "$REVIEWERS" ]]; then
        IFS=',' read -ra REVIEWER_ARRAY <<< "$REVIEWERS"
        for reviewer in "${REVIEWER_ARRAY[@]}"; do
            gh_args+=(--reviewer "${reviewer// /}")
        done
        log_info "Reviewers: ${REVIEWERS}"
    fi
    
    # Assignees
    if [[ -n "$ASSIGNEES" ]]; then
        IFS=',' read -ra ASSIGNEE_ARRAY <<< "$ASSIGNEES"
        for assignee in "${ASSIGNEE_ARRAY[@]}"; do
            gh_args+=(--assignee "${assignee// /}")
        done
        log_info "Assignees: ${ASSIGNEES}"
    fi
    
    log_info "Creating PR..."
    
    local pr_url
    local pr_number
    
    if ! pr_url=$(gh pr create "${gh_args[@]}" 2>&1); then
        log_error "Failed to create PR"
        echo "$pr_url" >&2
        return "$EXIT_FAILURE"
    fi
    
    # Extract PR number from URL
    pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$' || echo "")
    
    log_success "PR created successfully!"
    log_info "URL: ${CYAN}${pr_url}${NC}"
    
    if [[ -n "$pr_number" ]]; then
        log_info "Number: #${pr_number}"
    fi
    
    # Open in browser if requested
    if [[ "$WEB_OPEN" == "true" ]]; then
        log_info "Opening in browser..."
        gh pr view "$pr_url" --web || true
    fi
    
    return "$EXIT_SUCCESS"
}

# Main execution
main() {
    parse_args "$@"
    
    cd "$REPO_ROOT"
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║          CREATE PULL REQUEST                                ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Validate environment
    validate_environment || exit "$?"
    
    # Generate title if not provided
    if [[ -z "$PR_TITLE" ]]; then
        generate_title || exit "$?"
    fi
    
    # Build PR body
    build_pr_body || exit "$?"
    
    # Validate PR data
    validate_pr_data || exit "$?"
    
    # Show preview
    log_section "PR Preview"
    echo -e "${BOLD}Title:${NC} ${PR_TITLE}"
    echo -e "${BOLD}Base:${NC} ${BASE_BRANCH}"
    echo -e "${BOLD}Head:${NC} ${HEAD_BRANCH}"
    echo -e "${BOLD}Draft:${NC} ${DRAFT}"
    echo ""
    
    # Create PR
    create_pr || exit "$?"
    
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║${NC} ${GREEN}✓ PULL REQUEST CREATED${NC}                                    ${BOLD}║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    exit "$EXIT_SUCCESS"
}

main "$@"
