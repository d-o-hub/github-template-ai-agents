#!/usr/bin/env bash
# ============================================================================
# check-plan-numbering.sh — Verifies plan/ADR numbering consistency.
# ============================================================================
#
# Checks that plans/README.md counters match plans/_status.json.
#
# Usage:
#   ./scripts/check-plan-numbering.sh
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
EXIT_CODE=0

STATUS_FILE="$REPO_ROOT/plans/_status.json"
README_FILE="$REPO_ROOT/plans/README.md"

if [[ ! -f "$STATUS_FILE" ]] || [[ ! -f "$README_FILE" ]]; then
  echo "  (Skipping check: plans/_status.json or plans/README.md not found)"
  exit 0
fi

# Get next plan number from _status.json
NEXT_PLAN=$(python3 -c "import json, sys; d=json.load(open(sys.argv[1])); print(d['nextAvailable']['plan'])" "$STATUS_FILE")
NEXT_ADR=$(python3 -c "import json, sys; d=json.load(open(sys.argv[1])); print(d['nextAvailable']['adr'])" "$STATUS_FILE")

echo "→ Checking plan numbering..."

# Check README (format: `**Next available plan number**: `040``)
README_NEXT_PLAN=$(python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    m = re.search(r'Next available plan number.*?\`(\d+)\`', f.read())
    print(m.group(1) if m else '')
" "$README_FILE" 2>/dev/null || echo "")
README_NEXT_ADR=$(python3 -c "
import re, sys
with open(sys.argv[1]) as f:
    m = re.search(r'Next available ADR number.*?\`(adr-\d+)\`', f.read())
    print(m.group(1) if m else '')
" "$README_FILE" 2>/dev/null || echo "")

if [[ -n "$README_NEXT_PLAN" ]] && [[ "$NEXT_PLAN" != "$README_NEXT_PLAN" ]]; then
  echo "  ✗ Plan number mismatch: _status.json says $NEXT_PLAN, README says $README_NEXT_PLAN"
  EXIT_CODE=1
fi

if [[ -n "$README_NEXT_ADR" ]] && [[ "$NEXT_ADR" != "$README_NEXT_ADR" ]]; then
  echo "  ✗ ADR number mismatch: _status.json says $NEXT_ADR, README says $README_NEXT_ADR"
  EXIT_CODE=1
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "  ✓ Plan numbering consistent"
fi

exit $EXIT_CODE
