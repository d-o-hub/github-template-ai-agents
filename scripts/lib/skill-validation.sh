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

# Frontmatter results keyed by SKILL.md path, filled by load_skill_frontmatter.
# One interpreter start for the whole run replaces a python fork per skill,
# which measured 2.2s of validate-skills.sh's 4.3s runtime.
declare -gA SKILL_FRONTMATTER_CACHE=()
declare -gA SKILL_FRONTMATTER_ISSUES=()

# Cache for VERSION file content
REPO_VERSION=""
# Shared variable to return line count without extra subshell
SKILL_LINE_COUNT=0
# Resolve dependencies beside this library even when REPO_ROOT is a fixture.
SKILL_VALIDATION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Template pin: a template repository intentionally holds VERSION at the
# placeholder below (see agents-docs/VERSION.md), so any skill's
# template_version is trivially "current" and the minor-version staleness
# comparison can never fire. The comparison is therefore skipped explicitly
# and announced once per run, instead of sitting here as unreachable code that
# reads like a bug. A consumer repository that sets a real VERSION takes the
# comparison path as normal. Policy: agents-docs/SKILLS.md.
readonly TEMPLATE_VERSION_PIN="0.0.0"
# Emitted once per run so the deliberate skip stays visible without repeating
# itself for every skill that declares a template_version.
TEMPLATE_VERSION_PIN_NOTICE_SHOWN="$FALSE"

# Batch-read frontmatter for the given SKILL.md paths. Results mirror the
# single-file protocol (line_count:has_version:template_version) and issues are
# stored verbatim so validate_skill_file prints exactly what it printed before.
load_skill_frontmatter() {
    local -a files=("$@")
    if [[ ${#files[@]} -eq 0 ]]; then
        return 0
    fi
    local kind path field_a field_b field_c
    while IFS=$'\t' read -r kind path field_a field_b field_c; do
        case "$kind" in
            R) SKILL_FRONTMATTER_CACHE["$path"]="${field_a}:${field_b}:${field_c}" ;;
            I)
                if [[ -n "${SKILL_FRONTMATTER_ISSUES[$path]:-}" ]]; then
                    SKILL_FRONTMATTER_ISSUES["$path"]+=$'\n'"$field_a"
                else
                    SKILL_FRONTMATTER_ISSUES["$path"]="$field_a"
                fi
                ;;
        esac
    done < <(printf '%s\n' "${files[@]}" | SKILL_FRONTMATTER_ROOT="$SKILLS_SRC" \
        python3 "$SKILL_VALIDATION_LIB_DIR/skill_frontmatter.py" --batch 2>/dev/null)
}

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

    # Parse only the delimited frontmatter, not similarly named body fields.
    # The dependency-free reader rejects YAML outside its documented subset;
    # this is not advertised as complete YAML validation.
    local frontmatter_result
    if [[ -n "${SKILL_FRONTMATTER_CACHE["$skill_file"]+cached}" ]]; then
        # Pre-read by load_skill_frontmatter: same reader, same messages, one
        # interpreter start for the whole run instead of one per skill.
        frontmatter_result="${SKILL_FRONTMATTER_CACHE[$skill_file]}"
        if [[ -n "${SKILL_FRONTMATTER_ISSUES[$skill_file]:-}" ]]; then
            local cached_issue
            while IFS= read -r cached_issue; do
                # Byte-identical to the reader's own stderr line. Colouring only
                # the cache-hit path would make one failure look different
                # depending on whether the file parsed, and the batched read is
                # a performance change, not an output change.
                printf "  ✗ %s: %s\n" "$skill_name" "$cached_issue" >&2
            done <<< "${SKILL_FRONTMATTER_ISSUES[$skill_file]}"
            errors=1
        fi
    elif ! frontmatter_result=$(SKILL_FRONTMATTER_ROOT="$SKILLS_SRC" \
        python3 "$SKILL_VALIDATION_LIB_DIR/skill_frontmatter.py" "$skill_file"); then
        errors=1
    fi
    local line_count has_version template_version
    IFS=':' read -r line_count has_version template_version <<< "$frontmatter_result"
    if [[ ! "$line_count" =~ ^[0-9]+$ ]]; then
        return 1
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
        if [[ -z "$current_version" ]]; then
            printf "  %b⚠%b %s: template_version %s set but VERSION is unreadable; staleness check skipped\n" "${YELLOW}" "${NC}" "$skill_name" "$template_version" >&2
        elif [[ "$current_version" == "$TEMPLATE_VERSION_PIN" ]]; then
            # Deliberate skip, not dead code. VERSION is the template placeholder
            # (TEMPLATE_VERSION_PIN), so the minor-version comparison below is
            # meaningless: it would report every skill as current forever. Announce
            # the skip once so a reader does not mistake it for a broken check.
            if [[ "$TEMPLATE_VERSION_PIN_NOTICE_SHOWN" -eq $FALSE ]]; then
                printf "  %b⚠%b template_version staleness check skipped: VERSION is the template pin %s (see agents-docs/SKILLS.md)\n" "${YELLOW}" "${NC}" "$TEMPLATE_VERSION_PIN" >&2
                TEMPLATE_VERSION_PIN_NOTICE_SHOWN=$TRUE
            fi
        else
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
