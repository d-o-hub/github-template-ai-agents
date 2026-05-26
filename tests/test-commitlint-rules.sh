#!/usr/bin/env bash
set -euo pipefail

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Verifying commitlint configuration syntax..."

# Since we don't have node_modules or a local commitlint setup easily testable without npm install,
# and we want to avoid environment changes, we'll do a basic JS syntax check on the config file.

if command -v node >/dev/null; then
    node --check commitlint.config.cjs
    echo "✓ commitlint.config.cjs syntax OK"
else
    echo "node not found, skipping syntax check."
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
            echo "✓ $name matches: $value"
        else
            echo "✗ Error: $name does not match expected value: $value"
            grep "$pattern" "$CONFIG_FILE"
            exit 1
        fi
    else
        echo "✗ Error: $name pattern not found in $CONFIG_FILE"
        exit 1
    fi
}

echo "Checking consistency with AGENTS.md..."
check_consistency "'header-max-length'" "150" "Header max length"
check_consistency "'body-max-length'" "200" "Body max length"
check_consistency "'body-max-line-length'" "100" "Body max line length"
check_consistency "'footer-max-length'" "200" "Footer max length"
check_consistency "'subject-case'" "'lower-case'" "Subject case"

exit 0
