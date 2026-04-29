#!/usr/bin/env bash
# Enforces WASM binary size limits.
set -euo pipefail

MAX_SIZE_BYTES=${MAX_WASM_SIZE_BYTES:-1048576} # Default 1MB
FAILED=0

echo "Checking WASM size limits (Max: $MAX_SIZE_BYTES bytes)..."

# Find all .wasm files in common build directories
# Using process substitution to handle filenames with spaces correctly
WASM_FOUND=0
while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -f "$file" ] || continue
    WASM_FOUND=1

    CURRENT_SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file")

    if [ "$CURRENT_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
        echo "ERROR: $file size $CURRENT_SIZE exceeds limit $MAX_SIZE_BYTES"
        FAILED=1
    else
        echo "OK: $file ($CURRENT_SIZE bytes)"
    fi
done < <(find . -name "*.wasm" -not -path "./.git/*" -not -path "*/node_modules/*" 2>/dev/null || true)

if [ "$WASM_FOUND" -eq 0 ]; then
    echo "No WASM files found to check."
    exit 0
fi

if [ $FAILED -ne 0 ]; then
    echo "WASM size check failed."
    exit 1
fi

echo "WASM size check passed."
exit 0
