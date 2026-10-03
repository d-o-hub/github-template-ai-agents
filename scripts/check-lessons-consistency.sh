#!/usr/bin/env bash
# ============================================================================
# check-lessons-consistency.sh — Verify the lesson catalog and its two indexes
# describe the same set of lessons.
#
#   agents-docs/LESSONS.md              the verbose catalog
#   agents-docs/lessons.jsonl            the machine index
#   agents-docs/self-learning-rules.md   the runtime index
#   agents-docs/lessons-archive.md       superseded lessons, kept for history
#
# These four drifted apart with nothing watching: LESSON-029..035, 037 and
# 043..045 were referenced by the rules index but absent from the catalog, and
# `rg -l lessons.jsonl scripts/ tests/ .github/` returned nothing, so no check
# existed. LESSONS.md even documented the gap as a known issue while it grew.
#
# An unreadable input is reported as a failure, never skipped: a check that
# could not read what it must verify is a false green.
#
# Exit 0 = consistent. Exit 1 = drift, or an input could not be read.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LESSONS_MD="$REPO_ROOT/agents-docs/LESSONS.md"
readonly LESSONS_JSONL="$REPO_ROOT/agents-docs/lessons.jsonl"
readonly RULES_MD="$REPO_ROOT/agents-docs/self-learning-rules.md"
readonly ARCHIVE_MD="$REPO_ROOT/agents-docs/lessons-archive.md"

EXIT_CODE=0

fail() {
    echo "  ✗ $1"
    EXIT_CODE=1
}

for required in "$LESSONS_MD" "$LESSONS_JSONL" "$RULES_MD"; do
    if [[ ! -f "$required" ]]; then
        echo "Error: required lesson file not found: ${required#"$REPO_ROOT/"}" >&2
        exit 1
    fi
done

# --- Catalog ids -------------------------------------------------------------
# Both heading styles exist in this file: "### LESSON-020: T" and
# "### LESSON-029 — T". Missing either would silently shrink the catalog.
# `|| true` is load-bearing: under pipefail a grep with no match aborts the whole
# script here, which would turn "nothing recorded" into a silent exit 1 with no
# message -- the very failure mode this check exists to make visible.
CATALOG_IDS=$(grep -oE '^### LESSON-[0-9]+' "$LESSONS_MD" | grep -oE '[0-9]+' | sort -u || true)

if [[ -z "$CATALOG_IDS" ]]; then
    echo "Error: no lesson headings found in ${LESSONS_MD#"$REPO_ROOT/"}" >&2
    exit 1
fi

CATALOG_COUNT=$(printf '%s\n' "$CATALOG_IDS" | wc -l)

# --- Index ids ---------------------------------------------------------------
# Each row must be valid JSON with an id and a title; a row that cannot be
# parsed means the index is not readable, not that it is empty.
INDEX_IDS=$(python3 - "$LESSONS_JSONL" <<'PY'
import json
import re
import sys

ids = []
try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        for lineno, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except ValueError as exc:
                raise SystemExit(f"lessons.jsonl:{lineno}: invalid JSON: {exc}")
            if "id" not in row or "title" not in row:
                raise SystemExit(f"lessons.jsonl:{lineno}: row needs 'id' and 'title'")
            match = re.search(r"(\d+)", str(row["id"]))
            if not match:
                raise SystemExit(f"lessons.jsonl:{lineno}: unparsable id {row['id']!r}")
            ids.append(match.group(1))
except OSError as exc:
    raise SystemExit(f"cannot read lessons.jsonl: {exc}")

print("\n".join(sorted(set(ids), key=int)))
PY
) || { echo "Error: lessons.jsonl is not readable as a machine index" >&2; exit 1; }

if [[ -z "$INDEX_IDS" ]]; then
    echo "Error: lessons.jsonl contains no lesson ids" >&2
    exit 1
fi

# --- Runtime index ids -------------------------------------------------------
RULES_IDS=$(grep -oE 'LESSON-[0-9]+' "$RULES_MD" | grep -oE '[0-9]+' | sort -u || true)

if [[ -z "$RULES_IDS" ]]; then
    echo "Error: no lesson references found in ${RULES_MD#"$REPO_ROOT/"}" >&2
    exit 1
fi

echo "=== Lesson consistency ==="
printf "  catalog: %s, jsonl: %s, rules index: %s\n" \
    "$CATALOG_COUNT" "$(printf '%s\n' "$INDEX_IDS" | wc -l)" "$(printf '%s\n' "$RULES_IDS" | wc -l)"

# --- Cross-checks ------------------------------------------------------------
while IFS= read -r id; do
    printf '%s\n' "$INDEX_IDS" | grep -qx -- "$id" || \
        fail "LESSON-$id is in LESSONS.md but has no lessons.jsonl row"
done <<< "$CATALOG_IDS"

while IFS= read -r id; do
    printf '%s\n' "$CATALOG_IDS" | grep -qx -- "$id" || \
        fail "LESSON-$id has a lessons.jsonl row but no LESSONS.md entry"
done <<< "$INDEX_IDS"

while IFS= read -r id; do
    printf '%s\n' "$CATALOG_IDS" | grep -qx -- "$id" && continue
    # A lesson may legitimately live only in the archive, if it was superseded.
    if [[ -f "$ARCHIVE_MD" ]] && grep -qE "LESSON-0?$id" "$ARCHIVE_MD"; then
        continue
    fi
    fail "self-learning-rules.md references LESSON-$id, which is in neither LESSONS.md nor lessons-archive.md"
done <<< "$RULES_IDS"

# --- Verdict -----------------------------------------------------------------
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✓ Lesson catalog, machine index, and runtime index agree"
    exit 0
fi

echo ""
echo "✗ Lesson records have drifted"
echo "  Record a new lesson in all three files, or remove the reference that"
echo "  no longer has a record."
exit 1
