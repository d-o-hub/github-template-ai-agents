#!/usr/bin/env bash
# scripts/secretlint_gate.sh - Runs secretlint
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STATUS=0
if [[ -f ".secretlintrc.json" ]]; then
    printf "%bRunning Secretlint checks...%b\n" "$BLUE" "$NC"
    if command -v npx &> /dev/null; then
        if ! npx --ignore-scripts -p secretlint -p @secretlint/secretlint-rule-preset-recommend secretlint "**/*"; then # NOSONAR: developer gate bootstrap, scripts disabled
            printf "%b  ✗ secretlint failed%b\n" "$RED" "$NC"
            STATUS=1
        else
            printf "%b  ✓ secretlint passed%b\n" "$GREEN" "$NC"
        fi
    else
        # A scan that never ran is not a pass: the presence of .secretlintrc.json is an
        # opt-in, so a missing runtime fails closed unless explicitly skipped.
        if [[ "${SKIP_SECRETLINT:-}" == "true" ]]; then
            printf "%b  ! npx not found, skipping secretlint (SKIP_SECRETLINT=true)%b\n" "$YELLOW" "$NC"
        else
            printf "%b  ✗ npx not found, secretlint cannot run%b\n" "$RED" "$NC"
            printf "    Install Node.js (provides npx) or set SKIP_SECRETLINT=true to skip this check.\n" >&2
            STATUS=1
        fi
    fi
    printf "\n"
fi
[[ "$STATUS" -eq 0 ]]

