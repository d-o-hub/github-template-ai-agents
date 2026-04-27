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
        echo -e "  ${RED}✗${NC} Security Error: Absolute path detected at line $line_num: \`${clean_path}'" >&2
        echo -e "     Links must be relative to the skill directory or repository root." >&2
        echo -e "     in: $skill_file" >&2
        return 1
    fi

    # Resolve the full path
    local full_path="$skill_dir/$clean_path"

    # Security check: Ensure the path is within REPO_ROOT (Path Traversal prevention)
    if [ -z "$HAS_REALPATH" ]; then
        if command -v realpath &> /dev/null; then HAS_REALPATH=1; else HAS_REALPATH=0; fi
    fi

    # Performance optimization: skip realpath subshell if path has no '..'
    # Absolute paths are already rejected, and simple relative paths can't escape
    if [[ "$clean_path" != *".."* ]]; then
        if [[ -e "$full_path" || -L "$full_path" ]]; then
            return 0
        fi
    fi

    if [ "$HAS_REALPATH" -eq 1 ] && [ -n "$RESOLVED_ROOT" ]; then
        # Performance optimization: Use pre-resolved root to avoid subshell
        local resolved_path
        resolved_path=$(realpath -m "$full_path" 2>/dev/null)

        # Ensure trailing slash for robust prefix matching
        if [[ "$resolved_path/" != "$RESOLVED_ROOT/"* ]]; then
            echo -e "  ${RED}✗${NC} Security Error: Path traversal detected at line $line_num: \`${clean_path}'" >&2
            echo -e "     Link attempts to reference a file outside the repository boundary." >&2
            echo -e "     in: $skill_file" >&2
            return 1
        fi

        # Check if file or directory exists within the boundary
        if [[ -e "$resolved_path" || -L "$resolved_path" ]]; then
            return 0
        fi
    else
        # Fallback if realpath not available: basic existence check
        if [[ -e "$full_path" || -L "$full_path" ]]; then
            return 0
        fi
    fi

    echo -e "  ${RED}✗${NC} Broken link at line $line_num: \`${clean_path}'" >&2
    echo -e "     in: $skill_file" >&2
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

echo "Validating reference links in SKILL.md files..."
echo ""

# Main entry point: discover and process all skill files
# We process all files in a single pass to minimize process spawning overhead.

# Check if skills directory exists
if [[ ! -d "$SKILLS_DIR" ]]; then
    echo -e "${YELLOW}⚠${NC} Skills directory not found: $SKILLS_DIR"
    exit 0
fi

# Gather all SKILL.md files, while maintaining the same warnings as before
SKILL_FILES=()
for skill_path in "$SKILLS_DIR"/*/; do
    [[ -d "$skill_path" ]] || continue
    skill_name="${skill_path%/}"
    skill_name="${skill_name##*/}"
    if [[ "$skill_name" == _* ]]; then continue; fi

    skill_file="$skill_path/SKILL.md"
    if [[ ! -f "$skill_file" ]]; then
        echo -e "  ${YELLOW}⚠${NC} $skill_name: Missing SKILL.md"
        continue
    fi
    SKILL_FILES+=("$skill_file")
done

if [ ${#SKILL_FILES[@]} -eq 0 ]; then
    echo "No SKILL.md files found to validate."
    exit 0
fi

last_skill_file=""
file_broken=0
file_format_errors=0

# Single pass to process all files:
# 1. awk filters relevant lines and tracks in_references state per file
# 2. Bash loop processes the filtered stream, handling file transitions
# Format: FILENAME:LINE_NUM:IN_REFERENCES:CONTENT
while IFS=: read -r current_skill_file line_num in_references line; do
    # Handle file transition: report success for the previous file
    if [[ "$current_skill_file" != "$last_skill_file" ]]; then
        if [[ -n "$last_skill_file" ]]; then
            if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
                # Performance optimization: Use Bash parameter expansion instead of basename
                last_skill_dir="${last_skill_file%/*}"
                last_skill_dir="${last_skill_dir%/}"
                echo -e "  ${GREEN}✓${NC} ${last_skill_dir##*/}: All links valid"
            fi
        fi
        last_skill_file="$current_skill_file"
        file_broken=0
        file_format_errors=0
        FILES_CHECKED=$((FILES_CHECKED + 1))
    fi

    skill_dir="${current_skill_file%/*}"

    # Track if we are in the References section (awk passes this state in)
    # We still need to check headers here if we want to skip them in further processing
    if [[ "$line" == "---" ]]; then
        continue
    fi
    if is_references_header "$line" || is_section_header "$line"; then
        continue
    fi

    # Check reference format (only in References section)
    if [[ $in_references -eq 1 ]]; then
        if ! check_reference_format "$line" "$line_num" "$current_skill_file" "$skill_dir"; then
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
        if ! check_link "$skill_dir" "$link_path" "$current_skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    done

    # Also check for backtick-wrapped paths that look like references
    if [[ "$line" =~ \`(references?/[a-zA-Z0-9_-]+\.md)\` ]]; then
        ref_path="${BASH_REMATCH[1]}"
        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$ref_path" "$current_skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    fi

    # Check for backtick-wrapped paths in docs/
    if [[ "$line" =~ \`(docs/[a-zA-Z0-9_/-]+\.md)\` ]]; then
        docs_path="${BASH_REMATCH[1]}"
        LINKS_CHECKED=$((LINKS_CHECKED + 1))
        if ! check_link "$skill_dir" "$docs_path" "$current_skill_file" "$line_num"; then
            BROKEN_COUNT=$((BROKEN_COUNT + 1))
            file_broken=1
        fi
    fi

    # Check for @references (deprecated format)
    if [[ "$line" =~ @(references?/[a-zA-Z0-9_-]+\.md) ]]; then
        at_ref="${BASH_REMATCH[1]}"
        echo -e "  ${RED}✗${NC} Broken @reference at line $line_num: @$at_ref" >&2
        echo -e "     @ prefix is deprecated. Use: \`reference/filename.md\` or \`references/filename.md\`" >&2
        echo -e "     in: $current_skill_file" >&2
        BROKEN_COUNT=$((BROKEN_COUNT + 1))
        file_broken=1
    fi

done < <(awk -v in_ref=0 '
    FNR == 1 { in_ref = 0; print FILENAME ":" FNR ":" in_ref ":---" }
    /^##[[:space:]]+[Rr]eferences/ { in_ref = 1; print FILENAME ":" FNR ":" in_ref ":" $0; next }
    /^##[[:space:]]+/ { in_ref = 0; print FILENAME ":" FNR ":" in_ref ":" $0; next }
    /\[[^]]+\]\([^)]+\)/ || /`(references?\/|docs\/)[^`]+`/ || /@references?/ || (in_ref && /^- /) {
        print FILENAME ":" FNR ":" in_ref ":" $0
    }
' "${SKILL_FILES[@]}")

# Report success for the final file
if [[ -n "$last_skill_file" ]]; then
    if [[ $file_broken -eq 0 && $file_format_errors -eq 0 ]]; then
        last_skill_dir="${last_skill_file%/*}"
        last_skill_dir="${last_skill_dir%/}"
        echo -e "  ${GREEN}✓${NC} ${last_skill_dir##*/}: All links valid"
    fi
fi

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
