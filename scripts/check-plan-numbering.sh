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
  printf "  (Skipping check: plans/_status.json or plans/README.md not found)\n"
  exit 0
fi

# Get next plan and ADR numbers from _status.json and README in a single pass to minimize process forks.
# Security: Pass filenames via sys.argv to prevent Python command injection.
# Performance: One python3 call instead of four.
PYTHON_CHECK=$(python3 -c "
import json, re, sys

status_file = sys.argv[1]
readme_file = sys.argv[2]

try:
    with open(status_file) as f:
        d = json.load(f)
        status_plan = d['nextAvailable']['plan']
        status_adr = d['nextAvailable']['adr']
except Exception:
    status_plan = ''
    status_adr = ''

try:
    with open(readme_file) as f:
        content = f.read()
        m_plan = re.search(r'Next available plan number.*?\`(\d+)\`', content)
        readme_plan = m_plan.group(1) if m_plan else ''
        m_adr = re.search(r'Next available ADR number.*?\`(adr-\d+)\`', content)
        readme_adr = m_adr.group(1) if m_adr else ''
except Exception:
    readme_plan = ''
    readme_adr = ''

print(f'{status_plan}:{status_adr}:{readme_plan}:{readme_adr}')
" "$STATUS_FILE" "$README_FILE")

IFS=':' read -r NEXT_PLAN NEXT_ADR README_NEXT_PLAN README_NEXT_ADR <<< "$PYTHON_CHECK"

printf "→ Checking plan numbering...\n"

if [[ -n "$README_NEXT_PLAN" ]] && [[ "$NEXT_PLAN" != "$README_NEXT_PLAN" ]]; then
  printf "  ✗ Plan number mismatch: _status.json says %s, README says %s\n" "$NEXT_PLAN" "$README_NEXT_PLAN"
  EXIT_CODE=1
fi

if [[ -n "$README_NEXT_ADR" ]] && [[ "$NEXT_ADR" != "$README_NEXT_ADR" ]]; then
  printf "  ✗ ADR number mismatch: _status.json says %s, README says %s\n" "$NEXT_ADR" "$README_NEXT_ADR"
  EXIT_CODE=1
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  printf "  ✓ Plan numbering consistent\n"
fi

exit $EXIT_CODE
