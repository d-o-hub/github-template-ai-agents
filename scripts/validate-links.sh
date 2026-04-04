#!/usr/bin/env bash
# Validates reference links in SKILL.md files.
# Checks that all markdown links point to existing files.
# Checks for consistent reference format: `references?/filename.md` - Description
# Exit 0 if all links valid, non-zero if broken links or format errors found.
# shellcheck disable=SC2094
set -uo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"

BROKEN_COUNT=0
FORMAT_ERRORS=0
FILES_CHECKED=0
LINKS_CHECKED=0

# Regex to match markdown links: [text](path)
LINK_REGEX='\[([^]]+)\]\(([^)]+)\)'

# Regex to match @references (deprecated format)
AT_REF_REGEX='@references?/[^[:space:]]+'

# Regex to match proper format: - `references?/filename.md` - description
# This is the REQUIRED format for references
# shellcheck disable=SC2016
PROPER_REF_REGEX='^\-[[:space:]]+\`(references?/[a-zA-Z0-9_-]+\.md)\`[[:space:]]*-[[:space:]]+.+$'

# Function to check if a line starts the References section
is_references_header() {
    [[ "$1" =~ ^##[[:space:]]+[Rr]eferences ]]
}

# Function to check if a line starts a new section (## header)
is_section_header() {
    [[ "$1" =~ ^##[[:space:]]+ ]] && ! [[ "$1" =~ ^##[[:space:]]+[Rr]eferences ]]
}

# Function to check if a path is a URL (http/https)
is_url() {
    [[ "$1" =~ ^https?:// ]] || [[ "$1" =~ ^ftp:// ]] || [[ "$1" =~ ^mailto: ]]
}

# Function to resolve a relative path from a base directory
resolve_path() {
    local base_dir="$1"
    local link_path="$2"

    # Handle absolute paths (shouldn't happen but be safe)
    if [[ "$link_path" == /* ]]; then
        echo "$link_path"
        return
    fi

    # Normalize path by removing redundant components
    if command -v realpath &> /dev/null; then
        realpath -m "$base_dir/$link_path"
    else
        echo "$base_dir/$link_path"
    fi
}

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

    # Resolve the full path
    local full_path
    full_path="$(resolve_path "$skill_dir" "$clean_path")"

    # Check if file or directory exists
    if [[ ! -e "$full_path" && ! -L "$full_path" ]]; then
        echo -e "  ${RED}✗${NC} Broken link at line $line_num: \`${clean_path}'" >&2
        echo -e "     in: $skill_file" >&2
        return 1
    fi

    return 0
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
        echo -e "  ${RED}✗${NC} Invalid reference format at line $line_num" >&2
        echo -e "     Found: $bad_ref" >&2
        echo -e "     Use: \`references?/filename.md\` - Description" >&2
        echo -e "     in: $skill_file" >&2
        return 1
    fi

    # Check for proper format: - `references?/filename.md` - description
    if [[ "$line" =~ ^-[[:space:]] ]]; then
        # This looks like a reference entry
            if ! [[ "$line" =~ $PROPER_REF_REGEX ]]; then
            # Check if it has markdown link format [text](path)
            if [[ "$line" =~ \[.+\]\((references?/.+)\) ]]; then
                local link_path="${BASH_REMATCH[1]}"
                echo -e "  ${RED}✗${NC} Invalid reference format at line $line_num" >&2
                echo -e "     Found: Markdown link [text]($link_path)" >&2
                echo -e "     Use: \`$link_path\` - Description" >&2
                echo -e "     in: $skill_file" >&2
                return 1
            fi
        fi
    fi

    return 0
}

# Function to process a single SKILL.md file
process_skill_file() {
    local skill_file="$1"
    local skill_dir
    skill_dir="$(dirname "$skill_file")"

    FILES_CHECKED=$((FILES_CHECKED + 1))

    local line_num=0
    local file_broken=0
    local file_format_errors=0
    local in_references=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Track if we're in the References section
        if is_references_header "$line"; then
            in_references=1
            continue
        elif is_section_header "$line"; then
            in_references=0
        fi

        # Check reference format (only in References section)
        if [[ $in_references -eq 1 ]]; then
            if ! check_reference_format "$line" "$line_num" "$skill_file" "$skill_dir"; then
                FORMAT_ERRORS=$((FORMAT_ERRORS + 1))
                file_format_errors=1
            fi
        fi

        # Find all markdown links in this line
        local temp_line="$line"
        while [[ "$temp_line" =~ $LINK_REGEX ]]; do
            local full_match="${BASH_REMATCH[0]}"
            local link_path="${BASH_REMATCH[2]}"

            # Remove this match from temp_line first (to continue loop)
            temp_line="${temp_line#*"$full_match"}"

            # Skip if this looks like an example (line contains "example:" or the link is in backticks)
            if [[ "$line" =~ example[[:space:]]*[:\(] ]] || [[ "$link_path" =~ \.(svg|png|jpg|jpeg|gif)$ ]]; then
                continue
            fi

            LINKS_CHECKED=$((LINKS_CHECKED + 1))

            # Check this link
            if ! check_link "$skill_dir" "$link_path" "$skill_file" "$line_num"; then
                BROKEN_COUNT=$((BROKEN_COUNT + 1))
                file_broken=1
            fi
        done

        # Also check for backtick-wrapped paths that look like references (only .md files in reference/)
        if [[ "$line" =~ \`(references?/[a-zA-Z0-9_-]+\.md)\` ]]; then
            local ref_path="${BASH_REMATCH[1]}"
            LINKS_CHECKED=$((LINKS_CHECKED + 1))

            if ! check_link "$skill_dir" "$ref_path" "$skill_file" "$line_num"; then
                BROKEN_COUNT=$((BROKEN_COUNT + 1))
                file_broken=1
            fi
        fi

        # Check for backtick-wrapped paths in docs/ - only .md files, skip .svg and others
        if [[ "$line" =~ \`(docs/[a-zA-Z0-9_/-]+\.md)\` ]]; then
            local docs_path="${BASH_REMATCH[1]}"
            LINKS_CHECKED=$((LINKS_CHECKED + 1))
            if ! check_link "$skill_dir" "$docs_path" "$skill_file" "$line_num"; then
                BROKEN_COUNT=$((BROKEN_COUNT + 1))
                file_broken=1
            fi
        fi

        # Check for @references (deprecated format pointing to non-existent files)
        if [[ "$line" =~ @(references?/[a-zA-Z0-9_-]+\.md) ]]; then
            local at_ref="${BASH_REMATCH[1]}"
            echo -e "  ${RED}✗${NC} Broken @reference at line $line_num: @$at_ref" >&2
            echo -e "     @ prefix is deprecated. Use: \`reference/filename.md\` or \`references/filename.md\`" >&2
            echo -e "     in: $skill_file" >&2
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    done < "$skill_file"

    if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
        echo -e "  ${GREEN}✓${NC} $(basename "$skill_dir"): All links valid"
    fi
}

echo "Validating reference links in SKILL.md files..."
echo ""

# Check if skills directory exists
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo -e "${YELLOW}⚠${NC} Skills directory not found: $SKILLS_DIR"
    exit 0
fi

# Find and process all SKILL.md files
for skill_path in "$SKILLS_DIR"/*/; do
    [[ -d "$skill_path" ]] || continue

    skill_name="$(basename "$skill_path")"

    # Skip consolidated/backup folders
    if [[ "$skill_name" == _* ]]; then
        continue
    fi

    skill_file="$skill_path/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
        echo -e "  ${YELLOW}⚠${NC} $skill_name: Missing SKILL.md"
        continue
    fi

    process_skill_file "$skill_file"
done

echo ""
echo "─────────────────────────────────────────────────────────────────"

TOTAL_ERRORS=$((BROKEN_COUNT + FORMAT_ERRORS))

if [[ $TOTAL_ERRORS -gt 0 ]]; then
    echo -e "│ ${RED}✗ Link Validation FAILED${NC}                                      │" >&2
    echo "─────────────────────────────────────────────────────────────────" >&2
    echo "" >&2
    echo "  Files checked: $FILES_CHECKED" >&2
    echo "  Links checked: $LINKS_CHECKED" >&2
    echo -e "  ${RED}Broken links: $BROKEN_COUNT${NC}" >&2
    echo -e "  ${RED}Format errors: $FORMAT_ERRORS${NC}" >&2
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
    echo -e "│ ${GREEN}✓ All reference links valid${NC}                                   │"
    echo "─────────────────────────────────────────────────────────────────"
    echo ""
    echo "  Files checked: $FILES_CHECKED"
    echo "  Links checked: $LINKS_CHECKED"
    echo "  Broken links: 0"
    exit 0
fi
