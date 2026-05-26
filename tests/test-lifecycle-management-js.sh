#!/usr/bin/env bash
set -euo pipefail

SKILL_FILE=".agents/skills/lifecycle-management/SKILL.md"
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Extracting JS examples from $SKILL_FILE..."

# Extract JS code blocks and save to a temporary file
# Using a more robust sed pattern to extract code between ```javascript and ```
sed -n '/^```javascript$/,/^```$/p' "$SKILL_FILE" | grep -v '```' > "$TMP_DIR/extracted.js"

if [ ! -s "$TMP_DIR/extracted.js" ]; then
    echo "Error: No JS examples found in $SKILL_FILE"
    exit 1
fi

echo "Extracted JS content:"
cat "$TMP_DIR/extracted.js"

# Basic syntax check using node if available
if command -v node >/dev/null; then
    echo "Running node syntax check..."
    node --check "$TMP_DIR/extracted.js"
    echo "✓ JS syntax OK (node --check)"
else
    echo "node not found, skipping syntax check."
fi

exit 0
