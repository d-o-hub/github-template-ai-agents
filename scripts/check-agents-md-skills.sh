#!/usr/bin/env bash
# ============================================================================
# check-agents-md-skills.sh — Verify the AGENTS.md skill table matches the
# canonical skill catalog (.agents/skills/).
#
# The table is hand-curated by category and is deliberately NOT generated:
# a generator cannot infer that triz-solver belongs under both Analysis and
# Innovation Problem Solving, and its heuristic categories produce a different
# taxonomy than the one adopters read. What must be guaranteed is not the
# grouping but the inventory, so this checks names and never edits AGENTS.md.
#
# Three drift classes are reported:
#   1. a skill in the catalog that the table does not mention
#   2. a name in the table that no longer exists in the catalog
#   3. a name listed in more than one row
#
# Exit 0 = no drift. Exit 1 = drift, or the table could not be read.
# A check that cannot read what it must verify is a false green, so a missing
# skills section or an unparsable table fails rather than passes.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_FILE="$REPO_ROOT/AGENTS.md"
SKILLS_DIR="$REPO_ROOT/.agents/skills"
MAX_SKILLS_SECTION_LINE=200

EXIT_CODE=0

fail() {
    echo "  ✗ $1"
    EXIT_CODE=1
}

# --- Prerequisites -----------------------------------------------------------
if [[ ! -f "$AGENTS_FILE" ]]; then
    echo "Error: AGENTS.md not found at $AGENTS_FILE" >&2
    exit 1
fi

if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "Error: skills directory not found at $SKILLS_DIR" >&2
    exit 1
fi

# --- Canonical inventory -----------------------------------------------------
# Directory name is canonical: validate-skills.sh already requires it to match
# the frontmatter `name:`, so reading the directory avoids a second parse.
declare -a CATALOG=()
shopt -s nullglob
for skill_dir in "$SKILLS_DIR"/*/; do
    if [[ -f "${skill_dir}SKILL.md" ]]; then
        CATALOG+=("$(basename -- "$skill_dir")")
    fi
done
shopt -u nullglob

if [[ ${#CATALOG[@]} -eq 0 ]]; then
    echo "Error: no skills found in $SKILLS_DIR" >&2
    exit 1
fi

# --- Table extraction --------------------------------------------------------
SKILLS_SECTION_LINE=$(grep -nE -e '^(### Available Skills|## Skills)$' -- "$AGENTS_FILE" | head -n 1 | cut -d: -f1 || true)

if [[ -z "$SKILLS_SECTION_LINE" ]]; then
    echo "Error: could not find a '## Skills' section in AGENTS.md" >&2
    exit 1
fi

# The table ends at the next heading, or at end of file.
NEXT_SECTION_LINE=$(awk -v start="$SKILLS_SECTION_LINE" '
    NR > start && /^#{1,3} / { print NR; exit }
' "$AGENTS_FILE" || true)

if [[ -z "$NEXT_SECTION_LINE" ]]; then
    NEXT_SECTION_LINE=$(( $(wc -l < "$AGENTS_FILE") + 1 ))
fi

TABLE_BODY=$(sed -n "$((10#$SKILLS_SECTION_LINE + 1)),$((10#$NEXT_SECTION_LINE - 1))p" "$AGENTS_FILE")

if [[ -z "$TABLE_BODY" ]]; then
    echo "Error: the '## Skills' section in AGENTS.md contains no table rows" >&2
    exit 1
fi

# --- Comparison --------------------------------------------------------------
TABLE_LIST=$(printf '%s\n' "$TABLE_BODY" | grep -oE '`[a-z0-9][a-z0-9-]*`' | tr -d '`' || true)

if [[ -z "$TABLE_LIST" ]]; then
    echo "Error: found no skill names in the AGENTS.md table" >&2
    exit 1
fi

echo "=== AGENTS.md skill table ==="
printf "  catalog: %s skills, table: %s names\n" "${#CATALOG[@]}" "$(printf '%s\n' "$TABLE_LIST" | wc -l)"

# perf: replace subshells and external pipelines with native bash associative arrays
declare -A CATALOG_MAP=()
for skill in "${CATALOG[@]}"; do
    CATALOG_MAP["$skill"]=1
done

declare -A TABLE_COUNTS=()
# $TABLE_LIST is guaranteed to not contain spaces per the regex
for skill in $TABLE_LIST; do
    TABLE_COUNTS["$skill"]=$(( ${TABLE_COUNTS["$skill"]:-0} + 1 ))
done

# 1. Missing from the table.
for skill in "${CATALOG[@]}"; do
    if [[ -z "${TABLE_COUNTS["$skill"]:-}" ]]; then
        fail "$skill exists in .agents/skills/ but is absent from the AGENTS.md table"
    fi
done

# 2. Stale in the table, and 3. listed more than once.
for skill in "${!TABLE_COUNTS[@]}"; do
    occurrences="${TABLE_COUNTS["$skill"]}"
    if [[ "$occurrences" -gt 1 ]]; then
        fail "$skill is listed $occurrences times in the AGENTS.md table (expected once)"
    fi
    if [[ -z "${CATALOG_MAP["$skill"]:-}" ]]; then
        fail "$skill is listed in AGENTS.md but no longer exists in .agents/skills/"
    fi
done

# --- Verdict -----------------------------------------------------------------
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✓ AGENTS.md skill table matches the catalog (${#CATALOG[@]} skills)"
    exit 0
fi

echo ""
echo "✗ AGENTS.md skill table has drifted from .agents/skills/"
echo "  The table is hand-curated: add the missing skill to the right category"
echo "  row in AGENTS.md, or remove the name if the skill is gone."
exit 1
