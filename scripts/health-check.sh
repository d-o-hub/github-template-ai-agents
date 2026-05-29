#!/usr/bin/env bash
# health-check.sh - Verify environment has all required template dependencies
#
# Usage: ./scripts/health-check.sh
#
# Exit codes:
#   0 = All required tools present
#   1 = Some tools missing (warning)
#   2 = Critical tools missing (error)

set -uo pipefail

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check if terminal supports colors
if [[ ! -t 1 ]]; then
    RED=''
    YELLOW=''
    GREEN=''
    NC=''
fi

# Counters
REQUIRED_MISSING=0
OPTIONAL_MISSING=0

# Check command existence
check_command() {
    local cmd="$1"
    local required="${2:-false}"
    local min_version="${3:-}"

    if command -v "$cmd" &>/dev/null; then
        local version=""
        case "$cmd" in
            git) version=$(git --version 2>/dev/null | head -1) ;;
            bash) version=${BASH_VERSION} ;;
            shellcheck) version=$(shellcheck --version 2>/dev/null | head -2 | tail -1) ;;
            bats) version=$(bats --version 2>/dev/null) ;;
            jq) version=$(jq --version 2>/dev/null) ;;
            markdownlint) version=$(markdownlint --version 2>/dev/null) ;;
            yamllint) version=$(yamllint --version 2>/dev/null) ;;
            *) version="installed" ;;
        esac

        printf "${GREEN}✓${NC} %s: %s\n" "$cmd" "$version"

        if [[ -n "$min_version" ]]; then
            # Version comparison would go here
            : # Placeholder
        fi
        return 0
    else
        if [[ "$required" == "true" ]]; then
            printf "${RED}✗${NC} %s: ${RED}REQUIRED but not found${NC}\n" "$cmd"
            ((REQUIRED_MISSING++))
        else
            printf "${YELLOW}⚠${NC} %s: ${YELLOW}optional, not found${NC}\n" "$cmd"
            ((OPTIONAL_MISSING++))
        fi
        return 1
    fi
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          TEMPLATE HEALTH CHECK                               ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Check Bash version
echo "Shell Environment:"
printf "  Bash version: %s\n" "${BASH_VERSION}"
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    printf "  ${YELLOW}⚠ Warning: Bash 4.0+ recommended${NC}\n"
fi
echo ""

# Required tools
echo "Required Tools:"
check_command "git" "true"
check_command "bash" "true"

# Core validation tools
echo ""
echo "Core Validation Tools:"
check_command "shellcheck" "false"
check_command "bats" "false"
check_command "markdownlint" "false"
check_command "jq" "false"
check_command "yamllint" "false"

# Git configuration
echo ""
echo "Git Configuration:"
if git config --global user.name &>/dev/null; then
    printf "  ${GREEN}✓${NC} user.name: %s\n" "$(git config --global user.name)"
else
    printf "  ${YELLOW}⚠${NC} user.name: ${YELLOW}not set${NC}\n"
fi

if git config --global user.email &>/dev/null; then
    printf "  ${GREEN}✓${NC} user.email: %s\n" "$(git config --global user.email)"
else
    printf "  ${YELLOW}⚠${NC} user.email: ${YELLOW}not set${NC}\n"
fi

# Check for global hooks that might conflict
echo ""
echo "Git Hooks Configuration:"
if git config --global core.hooksPath &>/dev/null; then
    hooks_path=$(git config --global core.hooksPath)
    printf "  ${YELLOW}⚠${NC} Global hooks detected: %s\n" "$hooks_path"
    printf "     Run: git config --global --unset core.hooksPath\n"
else
    printf "  ${GREEN}✓${NC} No conflicting global hooks\n"
fi

# Check template setup
echo ""
echo "Template Setup:"
if [[ -d ".agents/skills" ]]; then
    skill_count=$(find .agents/skills -maxdepth 1 -type d | wc -l)
    printf "  ${GREEN}✓${NC} Skills directory exists (%s skills)\n" "$skill_count"
else
    printf "  ${RED}✗${NC} Skills directory not found - run ./scripts/setup-skills.sh\n"
fi

if [[ -L ".claude/skills" ]]; then
    printf "  ${GREEN}✓${NC} Claude symlinks configured\n"
else
    printf "  ${YELLOW}⚠${NC} Claude symlinks missing - run ./scripts/setup-skills.sh\n"
fi


if [[ -f ".git/hooks/pre-commit" ]]; then
    printf "  ${GREEN}✓${NC} Pre-commit hook installed\n"
else
    printf "  ${YELLOW}⚠${NC} Pre-commit hook not installed\n"
    printf "     Run: cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit\n"
fi

# Summary
echo ""
echo "════════════════════════════════════════════════════════════════"
if [[ $REQUIRED_MISSING -gt 0 ]]; then
    printf "${RED}Status: FAILED - %s required tool(s) missing${NC}\n" "$REQUIRED_MISSING"
    echo ""
    echo "Install missing tools:"
    echo "  Ubuntu/Debian: sudo apt-get install git bash"
    echo "  macOS: brew install git bash"
    echo ""
    exit 2
elif [[ $OPTIONAL_MISSING -gt 0 ]]; then
    printf "${YELLOW}Status: WARNING - %s optional tool(s) missing${NC}\n" "$OPTIONAL_MISSING"
    echo ""
    echo "To install optional tools:"
    echo "  Ubuntu/Debian:"
    echo "    sudo apt-get install shellcheck bats jq"
    echo "    npm install -g markdownlint-cli"
    echo "    pip install yamllint"
    echo ""
    echo "  macOS:"
    echo "    brew install shellcheck bats jq markdownlint-cli yamllint"
    echo ""
    exit 1
else
    printf "${GREEN}Status: HEALTHY - All tools present${NC}\n"
    echo ""
    echo "You're ready to use the template! Next steps:"
    echo "  1. Run: ./scripts/setup-skills.sh"
    echo "  2. Review: cat AGENTS.md"
    echo "  3. Run quality gate: ./scripts/quality_gate.sh"
    echo ""
    exit 0
fi
