#!/usr/bin/env bash
# Validates reference links in SKILL.md files.
# Checks that all markdown links point to existing files.
# Exit 0 if all links valid, non-zero if broken links found.
set -uo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"

BROKEN_COUNT=0
FILES_CHECKED=0
LINKS_CHECKED=0

# Regex to match markdown links: [text](path)
# Captures the path portion which may contain letters, numbers, dots, slashes, hyphens, underscores
LINK_REGEX='\[([^]]+)\]\(([^)]+)\)'

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
    # Use realpath if available, otherwise manual resolution
    if command -v realpath &> /dev/null; then
        realpath -m "$base_dir/$link_path"
    else
        # Fallback: simple concatenation (won't resolve .. but sufficient for checking existence)
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

    # Remove any anchor from the path (file.md#section -> file.md)
    local clean_path="${link_path%%#*}"

    # Resolve the full path
    local full_path
    full_path="$(resolve_path "$skill_dir" "$clean_path")"

    # Check if file or directory exists
    if [[ ! -e "$full_path" && ! -L "$full_path" ]]; then
        echo -e "  ${RED}✗${NC} Broken link at line $line_num: \`${clean_path}'" >&2
        echo -e "     in: $skill_file" >&2
        echo -e "     resolved: $full_path" >&2
        return 1
    fi

    return 0
}

# Function to process a single SKILL.md file
# shellcheck disable=SC2094
process_skill_file() {
    local skill_file="$1"
    local skill_dir
    skill_dir="$(dirname "$skill_file")"

    FILES_CHECKED=$((FILES_CHECKED + 1))

    local line_num=0
    local file_broken=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Skip code blocks: remove text between backticks to avoid matching example code
        # Using bash parameter expansion to remove code in backticks
        local line_without_code="$line"
        while [[ "$line_without_code" == *\`*\`* ]]; do
            # Remove content between backticks (non-greedy-like behavior)
            line_without_code="${line_without_code//\`+([^\`])\`/}"
            # Fallback: if pattern doesn't match, just remove first code block
            if [[ "$line_without_code" == *\`*\`* ]]; then
                # Extract parts before and after first pair of backticks
                local prefix="${line_without_code%%\`*}"
                local suffix="${line_without_code#*\`}"
                suffix="${suffix#*\`}"
                line_without_code="$prefix$suffix"
            fi
        done

        # Find all markdown links in this line (after removing code)
        # Using grep to find matches, then processing each
        while [[ "$line_without_code" =~ $LINK_REGEX ]]; do
            local link_path="${BASH_REMATCH[2]}"

            LINKS_CHECKED=$((LINKS_CHECKED + 1))

            # Remove the matched portion to continue searching the same line
            line_without_code="${line_without_code#*"${BASH_REMATCH[0]}"}"

            # Check this link
            # shellcheck disable=SC2094
            if ! check_link "$skill_dir" "$link_path" "$skill_file" "$line_num"; then
                BROKEN_COUNT=$((BROKEN_COUNT + 1))
                file_broken=1
            fi
        done
    done < "$skill_file"

    if [[ $file_broken -eq 0 ]]; then
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

if [[ $BROKEN_COUNT -gt 0 ]]; then
    echo -e "│ ${RED}✗ Link Validation FAILED${NC}                                      │" >&2
    echo "─────────────────────────────────────────────────────────────────" >&2
    echo "" >&2
    echo "  Files checked: $FILES_CHECKED" >&2
    echo "  Links checked: $LINKS_CHECKED" >&2
    echo -e "  ${RED}Broken links: $BROKEN_COUNT${NC}" >&2
    echo "" >&2
    echo "  Fix broken links by:" >&2
    echo "    1. Creating missing reference files" >&2
    echo "    2. Updating link paths in SKILL.md" >&2
    echo "    3. Removing obsolete links" >&2
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
