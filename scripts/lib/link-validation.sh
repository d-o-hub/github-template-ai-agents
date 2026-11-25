#!/usr/bin/env bash
# link-validation.sh - helpers for scripts/validate-links.sh
# shellcheck shell=bash
# Expects REPO_ROOT to be set by the caller before sourcing when used standalone.

# Color codes for output
RED="${RED:-[0;31m}"
GREEN="${GREEN:-[0;32m}"
YELLOW="${YELLOW:-[1;33m}"
NC="${NC:-[0m}"

# Shared patterns (used by this library and by scripts/validate-links.sh after source)
LINK_REGEX='\[([^]]+)\]\(([^)]+)\)'
AT_REF_REGEX='@references?/[^[:space:]]+'
# shellcheck disable=SC2016
PROPER_REF_REGEX='^\-[[:space:]]+\`(references?/[a-zA-Z0-9_-]+\.md)\`[[:space:]]*-[[:space:]]+.+$'
export LINK_REGEX AT_REF_REGEX PROPER_REF_REGEX

# Returns 0 if line contains a markdown link; populates BASH_REMATCH.
# Ensures LINK_REGEX is referenced in this file (Codacy/shellcheck unused-var).
match_markdown_link() {
    local line="$1"
    [[ "$line" =~ $LINK_REGEX ]]
    return $?
}

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

# _resolve_lexical - collapse `.` and `..` textually, with no filesystem call. A `..` that
# would pop past the first component is kept as a `..` in the result, so a path that climbs
# out of the repository stays visibly outside it instead of being clamped to the root.
_resolve_lexical() {
    local path="$1" comp
    local -a parts=() out=()
    IFS='/' read -r -a parts <<< "$path"
    for comp in "${parts[@]}"; do
        case "$comp" in
            '' | '.') ;;
            '..')
                if [[ ${#out[@]} -gt 0 && "${out[-1]}" != '..' ]]; then
                    unset 'out[-1]'
                else
                    out+=('..')
                fi
                ;;
            *) out+=("$comp") ;;
        esac
    done
    local IFS='/'
    printf '/%s' "${out[*]-}"
}

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

    # Resolve before judging. realpath is preferred because it also collapses symlinks, but it
    # cannot be the only route to a verdict: `command -v realpath` succeeds on BSD, where
    # `realpath -m` errors, so RESOLVED_ROOT came out empty and the traversal check was skipped
    # for every link — escaping links were accepted. Fall back to lexical resolution, compared
    # against the same REPO_ROOT the skill path was built from.
    local resolved_path=""
    local compare_root="$REPO_ROOT"
    if [[ "$HAS_REALPATH" -eq 1 ]]; then
        resolved_path=$(realpath -m "$full_path" 2>/dev/null || true)
        if [[ -n "$resolved_path" ]]; then
            compare_root="${RESOLVED_ROOT:-$REPO_ROOT}"
        fi
    fi
    if [[ -z "$resolved_path" ]]; then
        resolved_path=$(_resolve_lexical "$full_path")
    fi

    if [[ "$resolved_path/" != "$compare_root/"* ]]; then
        printf "  ${RED}✗${NC} Security Error: Path traversal detected at line %s: \`%s'\n" "$line_num" "$clean_path" >&2
        printf "     Link attempts to reference a file outside the repository boundary.\n" >&2
        printf "     in: %s\n" "$skill_file" >&2
        return 1
    fi
    if [[ -e "$resolved_path" || -L "$resolved_path" ]]; then
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
