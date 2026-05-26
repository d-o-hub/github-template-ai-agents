#!/usr/bin/env bash
set -euo pipefail

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

printf "Verifying commitlint configuration syntax...\n"

# Since we don't have node_modules or a local commitlint setup easily testable without npm install,
# and we want to avoid environment changes, we'll do a basic JS syntax check on the config file.

if command -v node >/dev/null; then
    node --check commitlint.config.cjs
    printf "✓ commitlint.config.cjs syntax OK\n"
else
    printf "node not found, skipping syntax check.\n"
fi

# Also check for consistency with AGENTS.md
AGENTS_MD="AGENTS.md"
CONFIG_FILE="commitlint.config.cjs"

check_consistency() {
    local pattern="$1"
    local value="$2"
    local name="$3"

    if grep -q "$pattern" "$CONFIG_FILE"; then
        if grep -q "$value" "$CONFIG_FILE"; then
            printf "✓ %s matches: %s\n" "$name" "$value"
        else
            printf "✗ Error: %s does not match expected value: %s\n" "$name" "$value" >&2
            grep "$pattern" "$CONFIG_FILE"
            exit 1
        fi
    else
        printf "✗ Error: %s pattern not found in %s\n" "$name" "$CONFIG_FILE" >&2
        exit 1
    fi
}

printf "Checking consistency with AGENTS.md...\n"
check_consistency "'header-max-length'" "150" "Header max length"
check_consistency "'body-max-length'" "1000" "Body max length"
check_consistency "'body-max-line-length'" "100" "Body max line length"
check_consistency "'footer-max-length'" "1000" "Footer max length"
check_consistency "'footer-max-line-length'" "100" "Footer max line length"
check_consistency "'subject-case'" "'lower-case'" "Subject case"

exit 0
