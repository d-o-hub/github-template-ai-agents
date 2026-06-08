#!/usr/bin/env bash
# Validates reference links in SKILL.md files.
# Checks that all markdown links point to existing files.
# Checks for consistent reference format: `references?/filename.md` - Description
# Exit 0 if all links valid, non-zero if broken links or format errors found.
# shellcheck disable=SC2094
set -uo pipefail

# Color codes for output
# These use ANSI escape sequences to provide visual feedback:
# - RED for errors (broken links, format violations)
# - GREEN for success (valid links)
# - YELLOW for warnings (missing files, skipped checks)
# - NC (No Color) resets formatting to prevent color bleeding
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Resolve repository root using BASH_SOURCE to handle being called from any directory
# This makes the script portable - works whether run from repo root or scripts folder
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"

# Performance optimization: Pre-resolve REPO_ROOT once
# This avoids hundreds of realpath/subshell calls during link validation
RESOLVED_ROOT=""
if command -v realpath &> /dev/null; then
    RESOLVED_ROOT=$(realpath -m "$REPO_ROOT")
fi

# Counters for the final summary report
# We track these across all files to provide actionable statistics
BROKEN_COUNT=0
FORMAT_ERRORS=0
FILES_CHECKED=0
LINKS_CHECKED=0

# Regex to match markdown links: [text](path)
# Captures two groups: [1]=link text, [2]=link destination
# Example: [SKILLS.md](agents-docs/SKILLS.md) -> BASH_REMATCH[1]=SKILLS.md, BASH_REMATCH[2]=agents-docs/SKILLS.md
LINK_REGEX='\[([^]]+)\]\(([^)]+)\)'

# Regex to detect deprecated @references format
# The @ prefix was replaced with backtick format to avoid shell interpretation issues
# This pattern catches @reference/filename.md or @references/filename.md
# Why deprecated? @ looks like a mention, backticks clearly indicate code/ reference format
AT_REF_REGEX='@references?/[^[:space:]]+'

# Regex to validate proper reference format: - `references?/filename.md` - description
# Breakdown of this pattern:
#   ^\-              - Line must START with a dash (bullet point)
#   [[:space:]]+     - One or more spaces after dash
#   \`               - Opening backtick
#   (references?/    - Capture group: "reference/" or "references/" (singular/plural both valid)
#     [a-zA-Z0-9_-]+ - Filename: alphanumeric, underscores, hyphens
#     \.md)          - Must end with .md extension
#   \`               - Closing backtick
#   [[:space:]]*     - Optional spaces
#   -                - Literal dash separator
#   [[:space:]]+     - One or more spaces
#   .+               - Description text (anything)
#   $                - End of line
# shellcheck disable=SC2016
PROPER_REF_REGEX='^\-[[:space:]]+\`(references?/[a-zA-Z0-9_-]+\.md)\`[[:space:]]*-[[:space:]]+.+$'

# Function to check if a line starts the References section
is_references_header() {
    local line="$1"
    [[ "$line" =~ ^##[[:space:]]+[Rr]eferences ]]
    return $?
}

# Function to check if a line starts a new section (## header)
is_section_header() {
    local line="$1"
    [[ "$line" =~ ^##[[:space:]]+ ]] && ! [[ "$line" =~ ^##[[:space:]]+[Rr]eferences ]]
    return $?
}

# Function to check if a path is a URL (http/https)
is_url() {
    local url="$1"
    [[ "$url" =~ ^https?:// ]] || [[ "$url" =~ ^ftp:// ]] || [[ "$url" =~ ^mailto: ]]
    return $?
}

# Cache for realpath existence check
HAS_REALPATH=""

# Function to check if a link target exists
check_link() {
    local skill_dir="$1"
    local link_path="$2"
    local skill_file="$3"
    local line_num="$4"

    # Skip URLs (external links)
    if is_url "$link_path"; then
        return 0
    fi

    # Skip anchor-only links (like #section-name)
    if [[ "$link_path" == \#* ]]; then
        return 0
    fi

    # Skip placeholder/example paths (like image-url, example-file, etc.)
    if [[ "$link_path" =~ ^(image-url|example|placeholder|your-file|path/to) ]]; then
        return 0
    fi

    # Remove any anchor from the path (file.md#section -> file.md)
    local clean_path="${link_path%%#*}"

    # Security check: Reject absolute paths (Path Traversal prevention)
    if [[ "$clean_path" == /* ]]; then
        printf "  ${RED}✗${NC} Security Error: Absolute path detected at line %s: \`%s'\n" "$line_num" "$clean_path" >&2
        printf "     Links must be relative to the skill directory or repository root.\n" >&2
        printf "     in: %s\n" "$skill_file" >&2
        return 1
    fi

    # Resolve the full path
    local full_path="$skill_dir/$clean_path"

    # Security check: Ensure the path is within REPO_ROOT (Path Traversal prevention)
    if [[ -z "$HAS_REALPATH" ]]; then
        if command -v realpath &> /dev/null; then HAS_REALPATH=1; else HAS_REALPATH=0; fi
    fi

    # Performance optimization: skip realpath subshell if path has no '..'
    # Absolute paths are already rejected, and simple relative paths can't escape
    if [[ "$clean_path" != *".."* ]]; then
        if [[ -e "$full_path" || -L "$full_path" ]]; then
            return 0
        fi
    elif [[ "$HAS_REALPATH" -eq 0 ]]; then
        # Security: Fail-closed if realpath is missing and path contains '..'
        printf "  ${RED}✗${NC} Security Error: Cannot validate path with '..' (realpath missing) at line %s: \`%s'\n" "$line_num" "$clean_path" >&2
        printf "     in: %s\n" "$skill_file" >&2
        return 1
    fi

    if [[ "$HAS_REALPATH" -eq 1 ]] && [[ -n "$RESOLVED_ROOT" ]]; then
        # Performance optimization: Use pre-resolved root to avoid subshell
        local resolved_path
        # Security: Use -- to prevent option injection
        resolved_path=$(realpath -m -- "$full_path" 2>/dev/null)

        # Ensure trailing slash for robust prefix matching
        if [[ "$resolved_path/" != "$RESOLVED_ROOT/"* ]]; then
            printf "  ${RED}✗${NC} Security Error: Path traversal detected at line %s: \`%s'\n" "$line_num" "$clean_path" >&2
            printf "     Link attempts to reference a file outside the repository boundary.\n" >&2
            printf "     in: %s\n" "$skill_file" >&2
            return 1
        fi

        # Check if file or directory exists within the boundary
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

# Function to check reference format in References section
check_reference_format() {
    local line="$1"
    local line_num="$2"
    local skill_file="$3"
    local skill_dir="$4"

    # Skip empty lines and headers
    [[ -z "$line" ]] && return 0
    [[ "$line" =~ ^## ]] && return 0
    [[ "$line" =~ ^\| ]] && return 0  # Table rows

    # Check for @references (deprecated format)
    if [[ "$line" =~ $AT_REF_REGEX ]]; then
        local bad_ref="${BASH_REMATCH[0]}"
        printf "  ${RED}✗${NC} Invalid reference format at line %s\n" "$line_num" >&2
        printf "     Found: %s\n" "$bad_ref" >&2
        printf "     Use: \`references?/filename.md\` - Description\n" >&2
        printf "     in: %s\n" "$skill_file" >&2
        return 1
    fi

    # Check for proper format: - `references?/filename.md` - description
    if [[ "$line" =~ ^-[[:space:]] ]] && ! [[ "$line" =~ $PROPER_REF_REGEX ]]; then
        # Check if it has markdown link format [text](path)
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

# Main entry point: discover and process all skill files
# Uses a batched awk process to filter relevant lines across all SKILL.md files.
# This eliminates per-file process forks, providing significant speedup.

if [[ ! -d "$SKILLS_DIR" ]]; then
    printf "${YELLOW}⚠${NC} Skills directory not found: %s\n" "$SKILLS_DIR"
    exit 0
fi

# Collect all SKILL.md files, skipping backup folders (underscore prefix)
# Performance optimization: use native bash globbing instead of find/sort subshells
SKILL_FILES=()
shopt -s nullglob
for skill_dir in "$SKILLS_DIR"/*/; do
    skill_file="${skill_dir}SKILL.md"
    skill_name="${skill_dir%/}"
    skill_name="${skill_name##*/}"
    [[ "$skill_name" == _* ]] && continue
    if [[ -f "$skill_file" ]]; then
        SKILL_FILES+=("$skill_file")
    fi
done
shopt -u nullglob

if [[ ${#SKILL_FILES[@]} -eq 0 ]]; then
    echo "No skills found to validate."
    exit 0
fi

current_file=""
file_broken=0
file_format_errors=0

# Process all files with a single awk call.
# Format: FILENAME:LINE_NUM:IN_REF:CONTENT
while IFS=: read -r skill_file line_num in_references line; do
    # Handle file transition and reporting
    if [[ "$skill_file" != "$current_file" ]]; then
        if [[ -n "$current_file" ]]; then
            if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
                skill_dir="${current_file%/*}"
                printf "  ${GREEN}✓${NC} %s: All links valid\n" "${skill_dir##*/}"
            fi
        fi
        current_file="$skill_file"
        file_broken=0
        file_format_errors=0
        FILES_CHECKED=$((FILES_CHECKED + 1))
        skill_dir="${skill_file%/*}"
        # Skip processing for the start-of-file marker
        [[ "$line_num" == "0" ]] && continue
    fi

    # Track if we're in the References section
    if is_references_header "$line"; then
        continue
    elif is_section_header "$line"; then
        continue
    fi

    # Check reference format (only in References section)
    if [[ "$in_references" -eq 1 ]]; then
        if ! check_reference_format "$line" "$line_num" "$skill_file" "$skill_dir"; then
            FORMAT_ERRORS=$((FORMAT_ERRORS + 1))
            file_format_errors=1
        fi
    fi

    # Find all markdown links in this line
    temp_line="$line"
    while [[ "$temp_line" =~ $LINK_REGEX ]]; do
        full_match="${BASH_REMATCH[0]}"
        link_path="${BASH_REMATCH[2]}"
        temp_line="${temp_line#*"$full_match"}"

        if [[ "$line" =~ example[[:space:]]*[:\(] ]] || [[ "$link_path" =~ \.(svg|png|jpg|jpeg|gif)$ ]]; then
            continue
        fi

        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$link_path" "$skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    done

    # Check for backtick-wrapped paths that look like references
    if [[ "$line" =~ \`(references?/[a-zA-Z0-9_-]+\.md)\` ]]; then
        ref_path="${BASH_REMATCH[1]}"
        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$ref_path" "$skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    fi

    # Check for backtick-wrapped paths in docs/
    if [[ "$line" =~ \`(docs/[a-zA-Z0-9_/-]+\.md)\` ]]; then
        docs_path="${BASH_REMATCH[1]}"
        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$docs_path" "$skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    fi

    # Check for deprecated @references
    if [[ "$line" =~ @(references?/[a-zA-Z0-9_-]+\.md) ]]; then
        at_ref="${BASH_REMATCH[1]}"
        printf "  ${RED}✗${NC} Broken @reference at line %s: @%s\n" "$line_num" "$at_ref" >&2
        printf "     @ prefix is deprecated. Use: \`reference/filename.md\` or \`references/filename.md\`\n" >&2
        printf "     in: %s\n" "$skill_file" >&2
        BROKEN_COUNT=$((BROKEN_COUNT + 1))
        file_broken=1
    fi
done < <(awk -- '
    BEGIN { in_ref = 0 }
    FNR == 1 { in_ref = 0; print FILENAME ":0:0:__START__" }
    /^##[[:space:]]+[Rr]eferences/ { in_ref = 1; print FILENAME ":" FNR ":" in_ref ":" $0; next }
    /^##[[:space:]]+/ { in_ref = 0; print FILENAME ":" FNR ":" in_ref ":" $0; next }
    /\[[^]]+\]\([^)]+\)/ || /`(references?\/|docs\/)[^`]+`/ || /@references?/ || (in_ref && /^- /) {
        print FILENAME ":" FNR ":" in_ref ":" $0
    }
' "${SKILL_FILES[@]}")

# Final report for the last file
if [[ -n "$current_file" ]]; then
    if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
        skill_dir="${current_file%/*}"
        printf "  ${GREEN}✓${NC} %s: All links valid\n" "${skill_dir##*/}"
    fi
fi

printf "\n"
printf "─────────────────────────────────────────────────────────────────\n"

TOTAL_ERRORS=$((BROKEN_COUNT + FORMAT_ERRORS))

if [[ $TOTAL_ERRORS -gt 0 ]]; then
    printf "│ ${RED}✗ Link Validation FAILED${NC}                                      │\n" >&2
    printf "─────────────────────────────────────────────────────────────────\n" >&2
    printf "\n" >&2
    printf "  Files checked: %s\n" "$FILES_CHECKED" >&2
    printf "  Links checked: %s\n" "$LINKS_CHECKED" >&2
    printf "  ${RED}Broken links: %s${NC}\n" "$BROKEN_COUNT" >&2
    printf "  ${RED}Format errors: %s${NC}\n" "$FORMAT_ERRORS" >&2
    echo "" >&2
    echo "  Fix broken links by:" >&2
    echo "    1. Creating missing reference files" >&2
    echo "    2. Updating link paths in SKILL.md" >&2
    echo "    3. Removing obsolete links" >&2
    echo "" >&2
    echo "  Reference format should be:" >&2
    echo "    - \`references?/filename.md\` - Description" >&2
    exit 1
else
    printf "│ ${GREEN}✓ All reference links valid${NC}                                   │\n"
    printf "─────────────────────────────────────────────────────────────────\n"
    printf "\n"
    printf "  Files checked: %s\n" "$FILES_CHECKED"
    printf "  Links checked: %s\n" "$LINKS_CHECKED"
    printf "  Broken links: 0\n"
    exit 0
fi
