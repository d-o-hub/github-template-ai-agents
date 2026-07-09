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
        if ! npx -p secretlint -p @secretlint/secretlint-rule-preset-recommend secretlint "**/*"; then
            printf "%b  ✗ secretlint failed%b\n" "$RED" "$NC"
            STATUS=1
        else
            printf "%b  ✓ secretlint passed%b\n" "$GREEN" "$NC"
        fi
    else
        printf "%b  ! npx not found, skipping secretlint%b\n" "$YELLOW" "$NC"
    fi
    printf "\n"
fi
[[ "$STATUS" -eq 0 ]]

# Added a comment to trigger CI retry.
