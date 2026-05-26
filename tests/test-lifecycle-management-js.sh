#!/usr/bin/env bash
set -euo pipefail

SKILL_FILE=".agents/skills/lifecycle-management/SKILL.md"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

printf "Extracting JS examples from %s...\n" "$SKILL_FILE"

# Extract JS code blocks and save to a temporary file
sed -n '/^```javascript$/,/^```$/p' "$SKILL_FILE" | grep -v '```' > "$TMP_DIR/extracted.js"

if [ ! -s "$TMP_DIR/extracted.js" ]; then
    printf "Error: No JS examples found in %s\n" "$SKILL_FILE"
    exit 1
fi

# Add a dummy handleResize definition to make it syntactically complete if called/referenced
printf "\nfunction handleResize() {}\n" >> "$TMP_DIR/extracted.js"

printf "Extracted JS content:\n"
cat "$TMP_DIR/extracted.js"

# Basic syntax check using node if available
if command -v node >/dev/null; then
    printf "Running node syntax check...\n"
    node --check "$TMP_DIR/extracted.js"
    printf "✓ JS syntax OK (node --check)\n"
else
    printf "node not found, skipping syntax check.\n"
fi

exit 0
