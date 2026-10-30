#!/usr/bin/env bash
# scripts/secretlint_gate.sh - Runs secretlint.
#
# Exit codes are a contract with scripts/quality_gate.sh:
#   0 = secretlint ran and passed
#   1 = secretlint ran and failed
#   3 = secretlint could not run (no npx); the caller must record a skipped check
#       rather than report a pass. See agents-docs/SCRIPTS.md.
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

STATUS=0
SKIPPED=0
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
        printf "%b  - skipped secret:secretlint: npx is not installed%b\n" "$YELLOW" "$NC"
        SKIPPED=1
    fi
    printf "\n"
fi

# A missing npx is not a pass: signal the caller so it can report the skip.
[[ "$SKIPPED" -eq 1 ]] && exit 3
[[ "$STATUS" -eq 0 ]]

# Added a comment to trigger CI retry.
