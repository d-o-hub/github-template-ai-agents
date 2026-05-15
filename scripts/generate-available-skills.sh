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
SKILL_DATA=$(find "$SKILLS_DIR" -maxdepth 2 -name "SKILL.md" -not -path "*/_*" | xargs awk '
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

    # Optimization: Use a single awk process to format and sort the entire table.
    # This eliminates a bash loop containing multiple piped external processes (grep, sed).
    printf "%s\n" "$SKILL_DATA" | sort -t'|' -k1,1 -k2,2 | awk -F'|' '
    function format_category(cat) {
        gsub(/-/, " ", cat)
        # Capitalize first letter of each word
        n = split(cat, words, " ")
        res = ""
        for (i = 1; i <= n; i++) {
            w = words[i]
            res = res (res==""?"":" ") toupper(substr(w,1,1)) substr(w,2)
        }
        return res
    }
    {
        if ($0 == "") next
        cat = $1
        name = $2
        # Reconstruct the remainder as description to handle internal pipes
        desc = $3
        for (i = 4; i <= NF; i++) {
            desc = desc "|" $i
        }

        if (cat != last_cat) {
            if (last_cat != "") {
                printf "\n"
            }
            printf "## %s\n\n", format_category(cat)
            printf "| Skill | Description |\n"
            printf "|-------|-------------|\n"
            last_cat = cat
        }
        printf "| `%s` | %s |\n", name, desc
    }
    END {
        if (last_cat != "") {
            printf "\n"
        }
    }'

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
