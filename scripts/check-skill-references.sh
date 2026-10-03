#!/usr/bin/env bash
# ============================================================================
# check-skill-references.sh — No live instruction may name a folded skill.
#
# LESSON-036 lists the documentation locations a skill merge has to touch, but
# nothing verified them, so Round 8's consolidation left live references behind:
# `.gemini/commands/planning.toml` still told agents to invoke
# `task-decomposition`, `.opencode/agents/implementer.md` still invoked
# `triz-analysis`, and `testing-strategy`'s own `Not for` line still deferred to
# `testdata-builders`, which had been folded *into* it.
#
# Scope is the live routing surfaces: agent and command configs, SKILL.md
# routing clauses, skill references, and eval fixtures. Historical prose that
# documents a fold ("absorbed from X", "superseded by X") is exempt, because a
# record of the fold is the opposite of drift.
#
# Exit 0 = no dead skill references. Exit 1 = one or more found.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$REPO_ROOT/scripts/lib/folded-skills.tsv"

# Directories whose contents are history or third-party vocabulary rather than
# routing instructions this repository controls.
readonly SKIP_DIRS=(
    "plans"
    "agents-docs/metrics-archive"
    ".git"
    "node_modules"
)

EXIT_CODE=0
REFERENCES_FOUND=0

fail() {
    echo "  ✗ $1"
    EXIT_CODE=1
}

if [[ ! -f "$REGISTRY" ]]; then
    echo "Error: folded-skill registry not found at $REGISTRY" >&2
    exit 1
fi

# --- Registry ---------------------------------------------------------------
declare -a FOLDED_NAMES=()
declare -a SUCCESSORS=()
while IFS=$'\t' read -r name successor _origin; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    FOLDED_NAMES+=("$name")
    SUCCESSORS+=("$successor")
done < "$REGISTRY"

if [[ ${#FOLDED_NAMES[@]} -eq 0 ]]; then
    echo "Error: folded-skill registry is empty at $REGISTRY" >&2
    exit 1
fi

# --- Scan targets -----------------------------------------------------------
# Live surfaces only. Anything a user is told to load or invoke.
declare -a TARGETS=()
while IFS= read -r file; do
    TARGETS+=("$file")
done < <(
    find "$REPO_ROOT/.claude/agents" \
         "$REPO_ROOT/.opencode/agents" \
         "$REPO_ROOT/.opencode/commands" \
         "$REPO_ROOT/.gemini/commands" \
         "$REPO_ROOT/.agents/skills" \
         -type f \
         \( -name '*.md' -o -name '*.toml' -o -name '*.json' \) \
         2>/dev/null | sort
)

if [[ ${#TARGETS[@]} -eq 0 ]]; then
    echo "Error: no agent or skill files found to scan" >&2
    exit 1
fi

echo "=== Folded skill references ==="
printf "  %s folded names, %s files scanned\n" "${#FOLDED_NAMES[@]}" "${#TARGETS[@]}"

should_skip() {
    local path="$1"
    local rel="${path#"$REPO_ROOT/"}"
    local skip_dir
    for skip_dir in "${SKIP_DIRS[@]}"; do
        [[ "$rel" == "$skip_dir" || "$rel" == "$skip_dir"/* ]] && return 0
    done
    return 1
}

# A line that explains the fold is history, not routing.
is_provenance() {
    local line="$1"
    [[ "$line" =~ (absorbed|superseded|folded|consolidat|merged|renamed|deprecated) ]]
}

for target in "${TARGETS[@]}"; do
    should_skip "$target" && continue
    for i in "${!FOLDED_NAMES[@]}"; do
        name="${FOLDED_NAMES[$i]}"
        successor="${SUCCESSORS[$i]}"
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            is_provenance "$line" && continue
            # Require a word boundary so `docs-hook`-style prefixes cannot false-positive.
            [[ "$line" =~ (^|[^a-z0-9-])${name}([^a-z0-9-]|$) ]] || continue
            rel="${target#"$REPO_ROOT/"}"
            fail "${rel}: references folded skill '${name}' (use '${successor}')"
            REFERENCES_FOUND=$((REFERENCES_FOUND + 1))
        done < <(grep -n -F -- "$name" "$target" 2>/dev/null | cut -d: -f2- || true)
    done
done

# --- Verdict ----------------------------------------------------------------
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✓ No folded skill names in live routing surfaces"
    exit 0
fi

echo ""
echo "✗ Found $REFERENCES_FOUND reference(s) to folded skills"
echo "  Update each to the successor listed above, or -- if the line is"
echo "  documenting the fold -- phrase it as history (e.g. 'absorbed from X')."
exit 1