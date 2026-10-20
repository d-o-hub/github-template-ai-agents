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

log_ok() { local msg="$1"; printf "  ✓ %s\n" "$msg"; }
log_fail() { local msg="$1"; printf "  ✗ %s\n" "$msg"; EXIT_CODE=1; }

# --- Phase 1: ADR File Inventory ---
printf "=== Phase 1: ADR File Inventory ===\n"
declare -a ADR_FILES=()
for file in "$REPO_ROOT/plans"/adr-*.md; do
  [[ -f "$file" ]] && ADR_FILES+=("${file##*/}")
done

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
  # perf: read file contents once and use native bash matching to eliminate grep process fork overhead in loop
  STATUS_CONTENT=$(<"$STATUS_FILE")
  for f in "${ADR_FILES[@]}"; do
    if [[ "$STATUS_CONTENT" == *"\"$f\""* ]]; then :
    else log_fail "$f NOT registered in _status.json"; fi
  done
fi

# --- Phase 3: Executable Invariants Registry Validation ---
printf "\n=== Phase 3: Executable Invariants Registry Validation ===\n"
if [[ -f "$REPO_ROOT/scripts/check-invariants.sh" ]]; then
  if ! "$REPO_ROOT/scripts/check-invariants.sh"; then
    EXIT_CODE=1
  fi
else
  log_fail "scripts/check-invariants.sh missing!"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
  printf "\n✓ All ADR compliance checks passed.\n"
else
  printf "\n✗ ADR compliance issues found.\n"
fi

exit $EXIT_CODE
