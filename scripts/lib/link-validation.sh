#!/usr/bin/env bash
# link-validation.sh - helpers for scripts/validate-links.sh
# shellcheck shell=bash
# Expects REPO_ROOT to be set by the caller before sourcing when used standalone.

# Color codes for output
RED="${RED:-[0;31m}"
GREEN="${GREEN:-[0;32m}"
YELLOW="${YELLOW:-[1;33m}"
NC="${NC:-[0m}"

LINK_REGEX='\[([^]]+)\]\(([^)]+)\)'
AT_REF_REGEX='@references?/[^[:space:]]+'
# shellcheck disable=SC2016
PROPER_REF_REGEX='^\-[[:space:]]+\`(references?/[a-zA-Z0-9_-]+\.md)\`[[:space:]]*-[[:space:]]+.+$'

is_references_header() {
    local line="$1"
    [[ "$line" =~ ^##[[:space:]]+[Rr]eferences ]]
    return $?
}

is_section_header() {
    local line="$1"
    [[ "$line" =~ ^##[[:space:]]+ ]] && ! [[ "$line" =~ ^##[[:space:]]+[Rr]eferences ]]
    return $?
}

is_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]] || [[ "$url" =~ ^ftp:// ]] || [[ "$url" =~ ^mailto: ]]
    return $?
}

HAS_REALPATH=""

check_link() {
    local skill_dir="$1"
    local link_path="$2"
    local skill_file="$3"
    local line_num="$4"

    if is_url "$link_path"; then
        return 0
    fi
    if [[ "$link_path" == \#* ]]; then
        return 0
    fi
    if [[ "$link_path" =~ ^(image-url|example|placeholder|your-file|path/to) ]]; then
        return 0
    fi

    local clean_path="${link_path%%#*}"
    if [[ "$clean_path" == /* ]]; then
        printf "  ${RED}✗${NC} Security Error: Absolute path detected at line %s: \`%s'\n" "$line_num" "$clean_path" >&2
        printf "     Links must be relative to the skill directory or repository root.\n" >&2
        printf "     in: %s\n" "$skill_file" >&2
        return 1
    fi

    local full_path="$skill_dir/$clean_path"
    if [[ -z "$HAS_REALPATH" ]]; then
        if command -v realpath &> /dev/null; then HAS_REALPATH=1; else HAS_REALPATH=0; fi
    fi

    if [[ "$clean_path" != *".."* ]]; then
        if [[ -e "$full_path" || -L "$full_path" ]]; then
            return 0
        fi
    fi

    if [[ "$HAS_REALPATH" -eq 1 ]] && [[ -n "${RESOLVED_ROOT:-}" ]]; then
        local resolved_path
        resolved_path=$(realpath -m "$full_path" 2>/dev/null)
        if [[ "$resolved_path/" != "$RESOLVED_ROOT/"* ]]; then
            printf "  ${RED}✗${NC} Security Error: Path traversal detected at line %s: \`%s'\n" "$line_num" "$clean_path" >&2
            printf "     Link attempts to reference a file outside the repository boundary.\n" >&2
            printf "     in: %s\n" "$skill_file" >&2
            return 1
        fi
        if [[ -e "$resolved_path" || -L "$resolved_path" ]]; then
            return 0
        fi
    elif [[ -e "$full_path" || -L "$full_path" ]]; then
        return 0
    fi

    printf "  ${RED}✗${NC} Broken link at line %s: \`%s'\n" "$line_num" "$clean_path" >&2
    printf "     in: %s\n" "$skill_file" >&2
    return 1
}

check_reference_format() {
    local line="$1"
    local line_num="$2"
    local skill_file="$3"
    local skill_dir="$4"

    [[ -z "$line" ]] && return 0
    [[ "$line" =~ ^## ]] && return 0
    [[ "$line" =~ ^\| ]] && return 0

    if [[ "$line" =~ $AT_REF_REGEX ]]; then
        local bad_ref="${BASH_REMATCH[0]}"
        printf "  ${RED}✗${NC} Invalid reference format at line %s\n" "$line_num" >&2
        printf "     Found: %s\n" "$bad_ref" >&2
        printf "     Use: \`references?/filename.md\` - Description\n" >&2
        printf "     in: %s\n" "$skill_file" >&2
        return 1
    fi

    if [[ "$line" =~ ^-[[:space:]] ]] && ! [[ "$line" =~ $PROPER_REF_REGEX ]]; then
        if [[ "$line" =~ \[.+\]\((references?/.+)\) ]]; then
            local link_path="${BASH_REMATCH[1]}"
            printf "  ${RED}✗${NC} Invalid reference format at line %s\n" "$line_num" >&2
            printf "     Found: Markdown link [text](%s)\n" "$link_path" >&2
            printf "     Use: \`%s\` - Description\n" "$link_path" >&2
            printf "     in: %s\n" "$skill_file" >&2
            return 1
        fi
    fi
    return 0
}
