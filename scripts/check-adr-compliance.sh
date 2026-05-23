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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)"
EXIT_CODE=0

log_ok() { printf "  ✓ %s\n" "$1"; }
log_fail() { printf "  ✗ %s\n" "$1"; EXIT_CODE=1; }

# --- Phase 1: ADR File Inventory ---
printf "=== Phase 1: ADR File Inventory ===\n"
declare -a ADR_FILES=()
while IFS= read -r -d '' file; do
  ADR_FILES+=("$(basename "$file")")
done < <(find "$REPO_ROOT/plans" -maxdepth 1 -name 'adr-*.md' -print0 | sort -z)

for f in "${ADR_FILES[@]}"; do printf "  - %s\n" "$f"; done

# --- Phase 2: Status Registration ---
printf "\n=== Phase 2: _status.json Registration ===\n"
STATUS_FILE="$REPO_ROOT/plans/_status.json"
if [[ ! -f "$STATUS_FILE" ]]; then
  if [[ ${#ADR_FILES[@]} -eq 0 ]]; then
    printf "  (Skipping check: plans/_status.json not found and no ADR files exist)\n"
  else
    log_fail "plans/_status.json not found but ADR files exist!"
  fi
else
  for f in "${ADR_FILES[@]}"; do
    if grep -qF -- "\"$f\"" "$STATUS_FILE"; then :
    else log_fail "$f NOT registered in _status.json"; fi
  done
fi

# --- Phase 3: Pattern Compliance (Skeleton) ---
printf "\n=== Phase 3: Basic Pattern Compliance ===\n"
# Users should add project-specific checks here.
# Example:
# if grep -rq "pattern" "$REPO_ROOT/src/"; then log_ok "Pattern found"; else log_fail "Pattern missing"; fi
printf "  (No project-specific patterns defined in template)\n"

if [[ $EXIT_CODE -eq 0 ]]; then
  printf "\n✓ All ADR compliance checks passed.\n"
else
  printf "\n✗ ADR compliance issues found.\n"
fi

exit $EXIT_CODE
