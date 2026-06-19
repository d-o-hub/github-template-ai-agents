#!/usr/bin/env bash
# generate-skills-reference.sh - Auto-generate agents-docs/skills-reference.md
# from skill frontmatter in .agents/skills/*/SKILL.md.
#
# Single-table format (skill | description | category) for quick scanning.
# The richer categorized catalog lives in agents-docs/AVAILABLE_SKILLS.md.
#
# Usage:
#   ./scripts/generate-skills-reference.sh            # write the file
#   ./scripts/generate-skills-reference.sh --check    # exit 1 if drift

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BATS_SOURCE[0]:-${0}}")/.." 2>/dev/null && pwd)}"
if [[ -z "${REPO_ROOT}" || ! -d "$REPO_ROOT/.agents/skills" ]]; then
    REPO_ROOT="$(pwd)"
fi

SKILLS_DIR="${SKILLS_DIR:-$REPO_ROOT/.agents/skills}"
OUTPUT_FILE="${OUTPUT_FILE:-$REPO_ROOT/agents-docs/skills-reference.md}"
CHECK_MODE=false

usage() {
    cat <<'EOF'
Usage: ./scripts/generate-skills-reference.sh [--check]

Generates agents-docs/skills-reference.md from skill frontmatter.

Options:
  --check  Generate into a temp file and compare with the committed output.
           Exits 1 on drift, 0 on match. Used by CI.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_MODE=true; shift ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

if "$CHECK_MODE"; then
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        printf 'Error: %s must exist before running --check.\n' "$OUTPUT_FILE" >&2
        exit 1
    fi
    check_tmp=$(mktemp)
    cleanup_check() { rm -f -- "$check_tmp"; }
    trap cleanup_check EXIT

    SKILLS_DIR="$SKILLS_DIR" OUTPUT_FILE="$check_tmp" "$0" > /dev/null

    if diff -q "$OUTPUT_FILE" "$check_tmp" > /dev/null; then
        printf '%s is up to date.\n' "$OUTPUT_FILE"
        exit 0
    fi
    printf 'Error: %s is out of date. Run ./scripts/generate-skills-reference.sh\n' "$OUTPUT_FILE" >&2
    diff "$OUTPUT_FILE" "$check_tmp" >&2 || true
    exit 1
fi

# Avoid option-injection: pass paths via env, not as command args starting with '-'
if [[ "$SKILLS_DIR" == -* || "$OUTPUT_FILE" == -* ]]; then
    printf 'Refusing to proceed: path starts with a dash.\n' >&2
    exit 2
fi

shopt -s nullglob extglob
skill_files=("$SKILLS_DIR"/!(_*)/SKILL.md)
shopt -u nullglob extglob

if [[ ${#skill_files[@]} -eq 0 ]]; then
    printf 'No skill files found in %s\n' "$SKILLS_DIR" >&2
    exit 1
fi

# Build pipe-delimited records: name|description|category
SKILL_DATA=$(printf '%s\0' "${skill_files[@]}" | xargs -0 awk -- '
function clean(s) {
    sub(/^[^:]*: */, "", s)
    if (s ~ /^".*"$/ || s ~ /^\x27.*\x27$/) {
        s = substr(s, 2, length(s) - 2)
    }
    return s
}
function flush_entry() {
    if (prev_file != "") {
        if (name == "") name = skill_dir_name
        if (description == "") description = "No description available"
        gsub(/\|/, "\\|", description)
        gsub(/[\r\n]+/, " ", description)
        gsub(/  +/, " ", description)
        sub(/^ +| +$/, "", description)
        print name "|" description "|" category
    }
}
FILENAME != prev_file {
    flush_entry()
    prev_file = FILENAME
    category = "general"
    description = ""
    name = ""
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
/^name:/ { name = clean($0) }
/^category:/ { category = clean($0) }
/^description:/ {
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
END { flush_entry() }
')

if [[ -z "$SKILL_DATA" ]]; then
    printf 'No skills parsed.\n' >&2
    exit 1
fi

mkdir -p "$(dirname -- "$OUTPUT_FILE")"

{
    printf '# Skills Reference\n\n'
    printf 'Full catalog of available skills in this repository.\n\n'
    printf '> Auto-generated from skill frontmatter in `.agents/skills/*/SKILL.md`.\n'
    printf '> Do not edit manually. Run `./scripts/generate-skills-reference.sh` to regenerate.\n'
    printf '> For a categorized narrative catalog, see `agents-docs/AVAILABLE_SKILLS.md`.\n\n'
    printf '| Skill | Description | Category |\n'
    printf '|-------|-------------|----------|\n'

    printf '%s\n' "$SKILL_DATA" | LC_ALL=C sort -t'|' -k1,1 | while IFS='|' read -r name description category; do
        category_display=$(printf '%s' "$category" | sed 's/-/ /g')
        printf '| `%s` | %s | %s |\n' "$name" "$description" "$category_display"
    done
} > "$OUTPUT_FILE"

# perf: Use wc -l instead of grep -c to eliminate regex parsing overhead
if [[ -z "$SKILL_DATA" ]]; then
    SKILL_COUNT=0
else
    SKILL_COUNT=$(printf '%s\n' "$SKILL_DATA" | wc -l)
fi
printf 'Generated %s with %s skills\n' "$OUTPUT_FILE" "$SKILL_COUNT"
