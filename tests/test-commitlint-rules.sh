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
    local key="$1"
    local value="$2"
    local name="$3"

    # Strict: require key and value on the same line (not just anywhere in file)
    if grep -q "${key}.*${value}" "$CONFIG_FILE"; then
        printf "✓ %s matches: %s\n" "$name" "$value"
    else
        if grep -q "$key" "$CONFIG_FILE"; then
            printf "✗ Error: %s key found but value '%s' not on same line\n" "$name" "$value" >&2
            grep "$key" "$CONFIG_FILE"
        else
            printf "✗ Error: %s key not found in %s\n" "$name" "$CONFIG_FILE" >&2
        fi
        exit 1
    fi
}

printf "Checking consistency with AGENTS.md...\n"
check_consistency "'header-max-length'" "150" "Header max length"
check_consistency "'body-max-length'" "1000" "Body max length"
check_consistency "'body-max-line-length'" "100" "Body max line length"
check_consistency "'footer-max-length'" "1000" "Footer max length"
check_consistency "'footer-max-line-length'" "100" "Footer max line length"
# subject-case is intentionally disabled ([0]) because identifiers like
# LESSON-017, SKILL.md, and technical references are valid commit subjects
check_consistency "'subject-case'" "\\[0\\]" "Subject case (disabled)"

printf "Checking dependabot commitlint exemption...\n"
if grep -q "ignores" "$CONFIG_FILE"; then
    if grep -q "Signed-off-by: dependabot\[bot\]" "$CONFIG_FILE"; then
        printf "✓ commitlint ignores rule exists for dependabot commits\n"
    else
        printf "✗ Error: ignores array exists but doesn't target dependabot commits\n" >&2
        exit 1
    fi
else
    printf "✗ Error: commitlint ignores rule missing for dependabot commits\n" >&2
    exit 1
fi

exit 0
