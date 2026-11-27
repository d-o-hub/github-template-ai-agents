#!/usr/bin/env bash
# scripts/secretlint_gate.sh - Runs secretlint
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Pinned so a new upstream release cannot silently change what the gate scans,
# and overridable so an adopter can bump without editing this file. secretlint
# v14 bundles the recommended preset that `.secretlintrc.json` names, so the
# separately published preset package -- deprecated upstream -- is not installed.
readonly SECRETLINT_VERSION="${SECRETLINT_VERSION:-14.1.0}"
# A bounded run, because an npm fetch that stalls must not hang the gate.
readonly SECRETLINT_TIMEOUT_SECONDS="${SECRETLINT_TIMEOUT_SECONDS:-600}"

# `npx` asks for confirmation before installing a package it does not have. With
# no TTY that prompt never resolves and the gate hangs instead of failing, which
# is what `--yes` prevents. The timeout is applied only where the binary exists,
# since macOS ships without it.
run_secretlint() {
    local -a cmd=(
        npx --yes --ignore-scripts
        -p "secretlint@${SECRETLINT_VERSION}"
        secretlint "**/*"
    )
    if command -v timeout >/dev/null 2>&1; then
        timeout "$SECRETLINT_TIMEOUT_SECONDS" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

STATUS=0
if [[ -f ".secretlintrc.json" ]]; then
    printf "%bRunning Secretlint checks...%b\n" "$BLUE" "$NC"
    if command -v npx &> /dev/null; then
        if ! run_secretlint; then # NOSONAR: developer gate bootstrap, scripts disabled
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

