#!/usr/bin/env bash
# generate-available-skills.sh - Auto-generate AVAILABLE_SKILLS.md from skill definitions
#
# Usage: ./scripts/generate-available-skills.sh
#
# Reads frontmatter from .agents/skills/*/SKILL.md and regenerates
# agents-docs/AVAILABLE_SKILLS.md. Run after adding/updating skills.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"
OUTPUT_FILE="$REPO_ROOT/agents-docs/AVAILABLE_SKILLS.md"

# Optimization: Use a single awk process to extract data from all SKILL.md files.
# This eliminates the O(N) process forks where N is the number of skills.
SKILL_DATA=$(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" -not -path "*/_*" | xargs awk -- '
    BEGINFILE {
        category = "general"
        description = ""
        name = ""
        # Get skill name from directory name
        split(FILENAME, parts, "/")
        skill_dir_name = parts[length(parts)-1]
        in_fm = 0
        fm_count = 0
    }
    /^---$/ {
        fm_count++
        if (fm_count == 1) in_fm = 1
        else in_fm = 0
        next
    }
    !in_fm { next }

    function clean(s) {
        sub(/^[^:]*: */, "", s)
        # Handle cases like description: "value" or description: '\''value'\''
        if (s ~ /^".*"$/ || s ~ /^\x27.*\x27$/) {
            s = substr(s, 2, length(s) - 2)
        }
        return s
    }

    /^name:/ { name = clean($0) }
    /^category:/ { category = clean($0) }
    /^description:/ {
        # Check if description uses multiline or is single line
        orig_val = $0
        sub(/^description: */, "", orig_val)

        if (orig_val ~ /^>[-|]?$/) {
            desc = ""
            while (getline > 0) {
                if ($0 ~ /^  /) {
                    line = $0
                    sub(/^  /, "", line)
                    desc = (desc == "" ? line : desc " " line)
                } else {
                    # Handle the line that broke the multiline loop
                    if ($0 ~ /^name:/) name = clean($0)
                    if ($0 ~ /^category:/) category = clean($0)
                    if ($0 ~ /^---$/) { fm_count++; in_fm = 0 }
                    break
                }
            }
            description = desc
        } else {
            description = clean($0)
        }
    }
    ENDFILE {
        if (name == "") name = skill_dir_name
        if (description == "") description = "No description available"
        print category "|" name "|" description
    }
')

# Generate output
{
    echo "# Available Skills Reference"
    echo ""
    echo "> Auto-generated from skill definitions in \`.agents/skills/\`"
    echo "> Do not edit manually. Run \`./scripts/generate-available-skills.sh\` to regenerate."
    echo ""

    # Get sorted categories first to match original script's outer loop
    # Use printf instead of echo to prevent option injection if SKILL_DATA starts with -
    CATEGORIES=$(printf "%s\n" "$SKILL_DATA" | cut -d'|' -f1 | sort -u)

    for category in $CATEGORIES; do
        # Capitalize category for display
        # Use printf to prevent option injection for categories starting with -
        category_display=$(printf "%s\n" "$category" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')

        printf "## %s\n" "$category_display"
        printf "\n"
        printf "| Skill | Description |\n"
        printf "|-------|-------------|\n"

        # Filter skills for this category and sort by name
        # Use -- separator with grep to prevent option injection if category starts with -
        printf "%s\n" "$SKILL_DATA" | grep -- "^$category|" | sort -t'|' -k2,2 | while IFS="|" read -r _ name description; do
            printf "| \`%s\` | %s |\n" "$name" "$description"
        done
        printf "\n"
    done

    echo "## Usage"
    echo ""
    echo "Skills are triggered automatically based on context or loaded explicitly."
    echo "See \`agents-docs/SKILLS.md\` for loading skills manually."
    echo ""
    echo "## See Also"
    echo ""
    echo "- \`agents-docs/SKILLS.md\` - Skill authoring guide"
    echo "- \`.agents/skills/skill-rules.json\` - Skill validation rules"
} > "$OUTPUT_FILE"

# Count skills processed
# Use printf to prevent option injection if SKILL_DATA starts with -
SKILL_COUNT=$(printf "%s\n" "$SKILL_DATA" | grep -c "^" || echo 0)
echo "Generated $OUTPUT_FILE with $SKILL_COUNT skills"
