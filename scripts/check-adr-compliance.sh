#!/usr/bin/env bash
# ============================================================================
# check-adr-compliance.sh — Automated ADR Compliance Check (Template Version)
# ============================================================================
#
# Verifies that all ADR files in plans/ are:
# 1. Present on disk
# 2. Registered in plans/_status.json
# 3. Have compliance notes matching codebase patterns (customizable)
#
# Usage:
#   ./scripts/check-adr-compliance.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXIT_CODE=0

log_ok() { echo "  ✓ $1"; }
log_fail() { echo "  ✗ $1"; EXIT_CODE=1; }

# --- Phase 1: ADR File Inventory ---
echo "=== Phase 1: ADR File Inventory ==="
declare -a ADR_FILES=()
while IFS= read -r -d '' file; do
  ADR_FILES+=("$(basename "$file")")
done < <(find "$SCRIPT_DIR/plans" -maxdepth 1 -name 'adr-*.md' -print0 | sort -z)

for f in "${ADR_FILES[@]}"; do echo "  - $f"; done

# --- Phase 2: Status Registration ---
echo -e "\n=== Phase 2: _status.json Registration ==="
STATUS_FILE="$SCRIPT_DIR/plans/_status.json"
if [[ ! -f "$STATUS_FILE" ]]; then
  log_fail "plans/_status.json not found!"
else
  for f in "${ADR_FILES[@]}"; do
    if grep -q "\"$f\"" "$STATUS_FILE"; then :
    else log_fail "$f NOT registered in _status.json"; fi
  done
fi

# --- Phase 3: Pattern Compliance (Skeleton) ---
echo -e "\n=== Phase 3: Basic Pattern Compliance ==="
# Users should add project-specific checks here.
# Example:
# if grep -rq "pattern" "$SCRIPT_DIR/src/"; then log_ok "Pattern found"; else log_fail "Pattern missing"; fi
echo "  (No project-specific patterns defined in template)"

if [[ $EXIT_CODE -eq 0 ]]; then
  echo -e "\n✓ All ADR compliance checks passed."
else
  echo -e "\n✗ ADR compliance issues found."
fi

exit $EXIT_CODE
