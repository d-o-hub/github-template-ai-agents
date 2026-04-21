#!/usr/bin/env bash
# lib/skill-validation.sh - Shared skill validation functions
# Source this file from other validation scripts.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/skill-validation.sh"

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SKILLS_SRC="$REPO_ROOT/.agents/skills"
MAX_SKILL_LINES=${MAX_SKILL_LINES:-250}

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Cache for VERSION file content
REPO_VERSION=""

# Validate a single SKILL.md file for format correctness
# Returns 0 if valid, 1 if invalid (prints errors to stderr)
validate_skill_file() {
    local skill_file="$1"
    local skill_name
    skill_name="$(basename "$(dirname "$skill_file")")"
    local errors=0

    # Check exists
    if [[ ! -f "$skill_file" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing SKILL.md" >&2
        return 1
    fi

    # Optimization: Read file once and parse with internal Bash logic or a single awk call
    # instead of multiple grep/head/sed/cut calls.

    local has_name=0
    local has_description=0
    local has_version=0
    local template_version=""
    local line_count=0
    local first_line=""

    # Read first line specifically
    read -r first_line < "$skill_file" || true
    if [[ "$first_line" != "---" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Must start with '---'" >&2
        ((errors++))
    fi

    # Single pass to gather info
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_count++))
        if [[ $line == "name:"* ]]; then has_name=1; fi
        if [[ $line == "description:"* ]]; then has_description=1; fi
        if [[ $line == "version:"* ]]; then has_version=1; fi
        if [[ $line == "template_version:"* ]]; then
            template_version="${line#template_version:}"
            template_version="${template_version//\"/}" # remove quotes
            template_version="${template_version#"${template_version%%[![:space:]]*}"}" # trim leading
            template_version="${template_version%"${template_version##*[![:space:]]}"}" # trim trailing
        fi
    done < "$skill_file"

    if [[ $has_name -eq 0 ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing 'name:' field" >&2
        ((errors++))
    fi
    if [[ $has_description -eq 0 ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing 'description:' field" >&2
        ((errors++))
    fi
    if [[ $has_version -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠${NC} $skill_name: Missing 'version:' field (recommended)" >&2
    fi

    if [[ -n "$template_version" ]]; then
        if [[ -z "$REPO_VERSION" ]]; then
            REPO_VERSION=$(cat "$REPO_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')
        fi
        local current_version="$REPO_VERSION"
        if [[ -n "$current_version" ]]; then
            # Use internal parameter expansion instead of cut
            local c_major="${current_version%%.*}"
            local rest="${current_version#*.}"
            local c_minor="${rest%%.*}"

            local s_major="${template_version%%.*}"
            local s_rest="${template_version#*.}"
            local s_minor="${s_rest%%.*}"

            if [[ "$s_major" -lt "$c_major" ]] || \
               { [[ "$s_major" -eq "$c_major" ]] && [[ $((c_minor - s_minor)) -gt 1 ]]; }; then
                echo -e "  ${YELLOW}⚠${NC} $skill_name: template_version $template_version is >1 minor behind current $current_version" >&2
            fi
        fi
    fi

    if [[ "$line_count" -gt "$MAX_SKILL_LINES" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: SKILL.md exceeds $MAX_SKILL_LINES lines ($line_count lines)" >&2
        ((errors++))
    fi

    return $errors
}
