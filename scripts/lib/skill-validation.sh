#!/usr/bin/env bash
# lib/skill-validation.sh - Shared skill validation functions
# Source this file from other validation scripts.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib/skill-validation.sh"

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SKILLS_SRC="$REPO_ROOT/.agents/skills"
MAX_SKILL_LINES=${MAX_SKILL_LINES:-250}

# Security: Validate numeric configuration to prevent shell arithmetic injection
if [[ ! "$MAX_SKILL_LINES" =~ ^[0-9]+$ ]]; then
    echo "Error: MAX_SKILL_LINES must be numeric" >&2
    exit 1
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Boolean sentinels
readonly TRUE=1
readonly FALSE=0

# Cache for VERSION file content
REPO_VERSION=""
# Shared variable to return line count without extra subshell
SKILL_LINE_COUNT=0

# Validate a single SKILL.md file for format correctness
# Returns 0 if valid, 1 if invalid (prints errors to stderr)
validate_skill_file() {
    local skill_file="$1"
    local skill_name
    # Performance optimization: Use Bash parameter expansion instead of basename/dirname
    local skill_dir="${skill_file%/*}"
    skill_name="${skill_dir##*/}"
    local errors=0

    # Check exists
    if [[ ! -f "$skill_file" ]]; then
        printf "  %b✗%b %s: Missing SKILL.md\n" "${RED}" "${NC}" "$skill_name" >&2
        return 1
    fi

    # Optimization: Read file once and parse with internal Bash logic or a single awk call
    # instead of multiple grep/head/sed/cut calls.

    # Single pass to gather info via awk for performance
    # Outputs a single line: line_count:err_no_dash:has_name:has_desc:has_version:template_version
    local awk_result
    if ! awk_result=$(awk -v true_val="$TRUE" -v false_val="$FALSE" -- '
        BEGIN { has_name=false_val; has_desc=false_val; has_version=false_val; template_version=""; err_no_dash=false_val }
        NR==1 && $0 != "---" { err_no_dash=true_val }
        /^name:/ { has_name=true_val }
        /^description:/ { has_desc=true_val }
        /^version:/ { has_version=true_val }
        /^template_version:/ {
            val=$0; sub(/^template_version:[ \t]*"?/, "", val); sub(/"?[ \t]*$/, "", val);
            template_version=val
        }
        END { print NR ":" err_no_dash ":" has_name ":" has_desc ":" has_version ":" template_version }
    ' "$skill_file"); then
        printf "  %b✗%b %s: Internal validation error (awk failed)\n" "${RED}" "${NC}" "$skill_name" >&2
        return 1
    fi

    local line_count err_no_dash has_name has_description has_version template_version
    IFS=':' read -r line_count err_no_dash has_name has_description has_version template_version <<< "$awk_result"

    if [[ "$err_no_dash" -eq $TRUE ]]; then
        printf "  %b✗%b %s: Must start with '---'\n" "${RED}" "${NC}" "$skill_name" >&2
        ((errors++))
    fi

    if [[ "$has_name" -eq $FALSE ]]; then
        printf "  %b✗%b %s: Missing 'name:' field\n" "${RED}" "${NC}" "$skill_name" >&2
        ((errors++))
    fi
    if [[ "$has_description" -eq $FALSE ]]; then
        printf "  %b✗%b %s: Missing 'description:' field\n" "${RED}" "${NC}" "$skill_name" >&2
        ((errors++))
    fi
    if [[ "$has_version" -eq $FALSE ]]; then
        printf "  %b⚠%b %s: Missing 'version:' field (recommended)\n" "${YELLOW}" "${NC}" "$skill_name" >&2
    fi

    if [[ -n "$template_version" ]]; then
        if [[ -z "$REPO_VERSION" ]]; then
            if [[ -f "$REPO_ROOT/VERSION" ]]; then
                read -r REPO_VERSION < "$REPO_ROOT/VERSION"
                # Remove spaces using internal parameter expansion
                REPO_VERSION="${REPO_VERSION//[[:space:]]/}"
            fi
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

            # Security: Validate numeric components to prevent shell arithmetic injection
            if [[ ! "$c_major" =~ ^[0-9]+$ ]] || [[ ! "$c_minor" =~ ^[0-9]+$ ]] || \
               [[ ! "$s_major" =~ ^[0-9]+$ ]] || [[ ! "$s_minor" =~ ^[0-9]+$ ]]; then
                # If malformed, use safe defaults to avoid injection in $(( ))
                c_major=0; c_minor=0; s_major=0; s_minor=0
            fi

            if (( 10#$s_major < 10#$c_major )) || \
               { (( 10#$s_major == 10#$c_major )) && (( 10#$c_minor - 10#$s_minor > 1 )); }; then
                printf "  %b⚠%b %s: template_version %s is >1 minor behind current %s\n" "${YELLOW}" "${NC}" "$skill_name" "$template_version" "$current_version" >&2
            fi
        fi
    fi

    if [[ "$line_count" -gt "$MAX_SKILL_LINES" ]]; then
        printf "  %b⚠%b %s: SKILL.md exceeds %d lines (%d lines)\n" "${YELLOW}" "${NC}" "$skill_name" "$MAX_SKILL_LINES" "$line_count" >&2
    fi

    # Export line count for callers to avoid redundant reads
    SKILL_LINE_COUNT=$line_count

    return $errors
}
