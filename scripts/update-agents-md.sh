#!/usr/bin/env bash
# Auto-update AGENTS.md skill table from .agents/skills/
# Preserves all other content (header, sections, reference docs)
# Run manually or via git hook when skills change
# Usage: ./scripts/update-agents-md.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

AGENTS_FILE="$REPO_ROOT/AGENTS.md"
TEMP_FILE=$(mktemp /tmp/agents-md-XXXXXX)
UPDATE_AGENTS_TEMP_TABLE=$(mktemp /tmp/temp-table-XXXXXX)  # Define before trap

# Trap to clean up temp files on exit or error
trap 'rm -f "$TEMP_FILE" "$UPDATE_AGENTS_TEMP_TABLE"' EXIT ERR

# Check if AGENTS.md exists
if [[ ! -f "$AGENTS_FILE" ]]; then
    echo "Error: AGENTS.md not found at $AGENTS_FILE" >&2
    exit 1
fi

echo "Updating AGENTS.md skill table..."

# Find the line number of the skills section header
# Supports both "### Available Skills" (template) and "## Skills" (customized)
SKILLS_SECTION_LINE=$(grep -nE -e "^(### Available Skills|## Skills)" -- "$AGENTS_FILE" | head -n 1 | cut -d: -f1)

if [[ -z "$SKILLS_SECTION_LINE" ]]; then
    echo "Error: Could not find skills section header in AGENTS.md"
    exit 1
fi

# Find the line number of the next section (end of skills table)
# Supports both "### Context Discipline" and "## Security"
NEXT_SECTION_LINE=$(grep -nE -e "^(### Context Discipline|## Security)" -- "$AGENTS_FILE" | cut -d: -f1 | awk -v start="$SKILLS_SECTION_LINE" -- '$1 > start { print $1; exit }')

if [[ -z "$NEXT_SECTION_LINE" ]]; then
    # Fallback to end of file if no next section found
    NEXT_SECTION_LINE=$(wc -l < "$AGENTS_FILE")
    NEXT_SECTION_LINE=$((NEXT_SECTION_LINE + 1))
fi

# Extract everything before the table (including the header)
head -n "$SKILLS_SECTION_LINE" -- "$AGENTS_FILE" > "$TEMP_FILE"

# Add table header
cat >> "$TEMP_FILE" << 'TABLE_HEADER'

| Skill | Description | Category |
|-------|-------------|----------|
TABLE_HEADER

# Generate skill rows by scanning .agents/skills/
if [[ -d "$REPO_ROOT/.agents/skills" ]]; then
    # Use array to hold valid SKILL.md paths
    shopt -s nullglob
    SKILL_MD_FILES=("$REPO_ROOT/.agents/skills"/*/"SKILL.md")
    shopt -u nullglob

    if [[ ${#SKILL_MD_FILES[@]} -gt 0 ]]; then
        # Use a single awk process to parse all SKILL.md files, extract descriptions,
        # infer categories, and lookup existing categories from AGENTS.md.
        awk -v agents_file="$AGENTS_FILE" -v MAX_DESC_LEN=60 -- '
            BEGIN {
                # Pre-load categories from AGENTS.md
                while ((getline < agents_file) > 0) {
                    if ($0 ~ /^\| `.*` \|/) {
                        split($0, parts, "|");
                        skill = parts[2];
                        gsub(/^ `/, "", skill);
                        gsub(/` $/, "", skill);
                        gsub(/ /, "", skill);

                        cat = parts[4];
                        gsub(/^ */, "", cat);
                        gsub(/ *$/, "", cat);

                        if (skill != "" && cat != "") {
                            categories[skill] = cat;
                        }
                    }
                }
                close(agents_file);
            }

            function infer_category(name) {
                if (name ~ /security|privacy|audit/) return "Security";
                if (name ~ /test|quality|check/) return "Quality";
                if (name ~ /doc|readme/) return "Documentation";
                if (name ~ /api/) return "API Development";
                if (name ~ /coordination|parallel|goap|decomposition/) return "Coordination";
                if (name ~ /db|database|devops|cicd|pipeline/) return "DevOps";
                if (name ~ /ui|ux/) return "UI/UX";
                if (name ~ /skill/) return "Meta";
                if (name ~ /search|web/) return "Research";
                if (name ~ /migration|refactor/) return "Migration";
                if (name ~ /intent|classifier/) return "Coordination";
                if (name ~ /accessibility/) return "Accessibility";
                if (name ~ /shell|script/) return "Code Quality";
                return "General";
            }

            function print_desc() {
                if (skill_name != "") {
                    if (has_desc) {
                        gsub(/^[>-] */, "", desc);
                        gsub(/  */, " ", desc);
                        sub(/ *$/, "", desc);
                        if (desc == "") desc = "No description";
                        # MAX_DESC_LEN determines the maximum length of the description
                        desc_final = substr(desc, 1, MAX_DESC_LEN);
                        sub(/ $/, "", desc_final);
                    } else {
                        desc_final = "No description";
                    }

                    cat = categories[skill_name];
                    if (cat == "") cat = infer_category(skill_name);

                    printf "| `%s` | %s | %s |\n", skill_name, desc_final, cat;
                }
            }

            FNR == 1 {
                print_desc();
                n = split(FILENAME, parts, "/");
                skill_name = parts[n-1];
                in_desc = 0;
                has_desc = 0;
                desc = "";
            }

            /^description:/ { in_desc = 1; has_desc = 1; desc = $0; sub(/^description: */, "", desc); next }
            in_desc && /^[a-z-]*:/ { in_desc = 0 }
            in_desc { desc = desc " " $0 }

            END {
                print_desc();
            }
        ' "${SKILL_MD_FILES[@]}" >> "$TEMP_FILE"
    fi
fi

# Sort the table rows (excluding header) alphabetically by skill name
head -n $((SKILLS_SECTION_LINE + 3)) -- "$TEMP_FILE" > "$UPDATE_AGENTS_TEMP_TABLE"
tail -n +$((SKILLS_SECTION_LINE + 4)) -- "$TEMP_FILE" | sort >> "$UPDATE_AGENTS_TEMP_TABLE"
mv -- "$UPDATE_AGENTS_TEMP_TABLE" "$TEMP_FILE"

# Add empty line before next section
echo "" >> "$TEMP_FILE"

# Append everything after the table (from "### Context Discipline" onwards)
tail -n +"$NEXT_SECTION_LINE" -- "$AGENTS_FILE" >> "$TEMP_FILE"

# Replace original file
mv -- "$TEMP_FILE" "$AGENTS_FILE"

# Count skills
SKILL_COUNT=$(find "$REPO_ROOT/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)

echo ""
echo "✓ AGENTS.md updated successfully"
echo "  Skills in table: $SKILL_COUNT"
echo ""
echo "To commit changes:"
echo "  git add AGENTS.md"
echo "  git commit -m 'docs: update skill table'"
