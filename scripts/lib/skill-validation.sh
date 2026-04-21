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

# Global variable for line count
line_count=0

# Validate a single SKILL.md file for format correctness
# Returns 0 if valid, 1 if invalid (prints errors to stderr)
# Sets: line_count (for callers)
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

    local first_line=""

    # Read first line specifically
    read -r first_line < "$skill_file" || true
    if [[ "$first_line" != "---" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Must start with '---'" >&2
        ((errors++))
    fi

    # Optimized: single pass to gather info using awk
    local awk_out
    awk_out=$(awk '
        BEGIN { name=0; desc=0; ver=0; tv="none"; lc=0 }
        /^name:/ { name=1 }
        /^description:/ { desc=1 }
        /^version:/ { ver=1 }
        /^template_version:/ {
            v=$0
            sub(/^template_version:[[:space:]]*/, "", v)
            gsub(/"/, "", v)
            sub(/[[:space:]]+$/, "", v)
            if (v != "") tv=v
        }
        { lc++ }
        END { printf "%d|%d|%d|%s|%d\n", name, desc, ver, tv, lc }
    ' "$skill_file")

    local h_name h_desc h_ver t_ver l_count
    IFS='|' read -r h_name h_desc h_ver t_ver l_count <<< "$awk_out"
    [[ "$t_ver" == "none" ]] && t_ver=""

    # Export line_count for callers like validate-skill-format.sh
    # We use a global variable because validate_skill_file is often called in a loop
    # but we want to avoid subshell overhead of returning multiple values.
    # shellcheck disable=SC2034
    line_count="$l_count"

    if [[ $h_name -eq 0 ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing 'name:' field" >&2
        ((errors++))
    fi
    if [[ $h_desc -eq 0 ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: Missing 'description:' field" >&2
        ((errors++))
    fi
    if [[ $h_ver -eq 0 ]]; then
        echo -e "  ${YELLOW}⚠${NC} $skill_name: Missing 'version:' field (recommended)" >&2
    fi

    if [[ -n "$t_ver" ]]; then
        if [[ -z "$REPO_VERSION" ]]; then
            REPO_VERSION=$(cat "$REPO_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')
        fi
        local current_version="$REPO_VERSION"
        if [[ -n "$current_version" ]]; then
            # Use internal parameter expansion instead of cut
            local c_major="${current_version%%.*}"
            local rest="${current_version#*.}"
            local c_minor="${rest%%.*}"

            local s_major="${t_ver%%.*}"
            local s_rest="${t_ver#*.}"
            local s_minor="${s_rest%%.*}"

            if [[ "$s_major" -lt "$c_major" ]] || \
               { [[ "$s_major" -eq "$c_major" ]] && [[ $((c_minor - s_minor)) -gt 1 ]]; }; then
                echo -e "  ${YELLOW}⚠${NC} $skill_name: template_version $t_ver is >1 minor behind current $current_version" >&2
            fi
        fi
    fi

    if [[ "$line_count" -gt "$MAX_SKILL_LINES" ]]; then
        echo -e "  ${RED}✗${NC} $skill_name: SKILL.md exceeds $MAX_SKILL_LINES lines ($line_count lines)" >&2
        ((errors++))
    fi

    return $errors
}
