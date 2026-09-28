#!/usr/bin/env bash
# ============================================================================
# check-plan-numbering.sh — Verifies plan/ADR numbering consistency.
# ============================================================================
#
# Cross-checks the human-readable counters in plans/README.md against
# plans/_status.json.
#
# This check must never no-op silently. A counter that cannot be located or
# parsed is reported as a failure, not skipped, because an unreadable counter
# means the cross-check did not happen — a false green.
#
# Usage:
#   ./scripts/check-plan-numbering.sh
#
# Exit 0 = counters consistent, or the plan-numbering regime is not in use
# Exit 1 = mismatch, missing mirror, or unparseable counter
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
PLANS_DIR="$REPO_ROOT/plans"
STATUS_FILE="$PLANS_DIR/_status.json"
README_FILE="$PLANS_DIR/README.md"

EXIT_CODE=0

fail() {
    echo "  ✗ $1"
    EXIT_CODE=1
}

# --- Prerequisite: python3 drives both the JSON read and the regex extraction ---
if ! command -v python3 &>/dev/null; then
    echo "  ✗ python3 required but not found in PATH (cannot verify plan numbering)"
    exit 1
fi

# --- Regime detection ----------------------------------------------------------
# Both files absent: this template has no plan-numbering regime. That is a
# legitimate configuration for adopters who prune plans/, so report and pass.
# _status.json present but README.md absent (or vice versa): half-configured.
# The counters exist but have no counterpart to compare against, so the
# cross-check cannot run. That is a false green and must fail.
if [[ ! -f "$STATUS_FILE" ]] && [[ ! -f "$README_FILE" ]]; then
    echo "  (Plan numbering not in use: plans/_status.json and plans/README.md both absent)"
    exit 0
fi

if [[ ! -f "$STATUS_FILE" ]]; then
    fail "plans/README.md exists but plans/_status.json is missing — counters cannot be cross-checked"
    exit 1
fi

if [[ ! -f "$README_FILE" ]]; then
    fail "plans/_status.json exists but plans/README.md is missing — the counter mirror is absent, so this check would no-op"
    echo "    Expected lines: '**Next available plan number**: \`NNN\`' and '**Next available ADR number**: \`adr-NNN\`'"
    exit 1
fi

echo "→ Checking plan numbering..."

# Read both counters out of _status.json in a single pass.
if ! COUNTERS=$(python3 - "$STATUS_FILE" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        nxt = json.load(handle)["nextAvailable"]
    print(f"{nxt['plan']}\t{nxt['adr']}")
except (OSError, ValueError, KeyError, TypeError) as exc:
    print(f"unreadable nextAvailable counters: {exc}", file=sys.stderr)
    sys.exit(1)
PY
); then
    fail "could not read nextAvailable counters from plans/_status.json"
    exit 1
fi

NEXT_PLAN="${COUNTERS%%$'\t'*}"
NEXT_ADR="${COUNTERS##*$'\t'}"

# Extract the README mirror. A regex miss is a failure: it means the counter
# this check exists to verify is not there to be read.
if ! README_COUNTERS=$(python3 - "$README_FILE" <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    text = handle.read()

plan = re.search(r"Next available plan number.*?`(\d+)`", text)
adr = re.search(r"Next available ADR number.*?`(adr-\d+)`", text)

missing = [name for name, match in (("plan", plan), ("ADR", adr)) if match is None]
if missing:
    print(f"no counter line found for: {', '.join(missing)}", file=sys.stderr)
    sys.exit(1)

print(f"{plan.group(1)}\t{adr.group(1)}")
PY
); then
    fail "plans/README.md is missing a 'Next available plan number' or 'Next available ADR number' counter line — the check cannot read what it must verify"
    exit 1
fi

README_NEXT_PLAN="${README_COUNTERS%%$'\t'*}"
README_NEXT_ADR="${README_COUNTERS##*$'\t'}"

if [[ "$NEXT_PLAN" != "$README_NEXT_PLAN" ]]; then
    fail "Plan number mismatch: _status.json says $NEXT_PLAN, README says $README_NEXT_PLAN"
fi

if [[ "$NEXT_ADR" != "$README_NEXT_ADR" ]]; then
    fail "ADR number mismatch: _status.json says $NEXT_ADR, README says $README_NEXT_ADR"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "  ✓ Plan numbering consistent (next plan $NEXT_PLAN, next ADR $NEXT_ADR)"
fi

exit $EXIT_CODE
