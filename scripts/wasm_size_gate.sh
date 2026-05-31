#!/usr/bin/env bash
# Enforces WASM binary size limits.
set -euo pipefail

MAX_SIZE_BYTES=${MAX_WASM_SIZE_BYTES:-1048576} # Default 1MB

# Security: Validate numeric configuration to prevent shell arithmetic injection
if [[ ! "$MAX_SIZE_BYTES" =~ ^[0-9]+$ ]]; then
    printf "Error: MAX_WASM_SIZE_BYTES must be numeric\n" >&2
    exit 1
fi

FAILED=0

printf "Checking WASM size limits (Max: %s bytes)...\n" "$MAX_SIZE_BYTES"

# Find all .wasm files in common build directories
# Using process substitution to handle filenames with spaces correctly
WASM_FOUND=0
while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -f "$file" ] || continue
    WASM_FOUND=1

    # Security: Use -- separator with stat to prevent option injection from malicious filenames
    CURRENT_SIZE=$(stat -c%s -- "$file" 2>/dev/null || stat -f%z -- "$file")

    if [ "$CURRENT_SIZE" -gt "$MAX_SIZE_BYTES" ]; then
        printf "ERROR: %s size %s exceeds limit %s\n" "$file" "$CURRENT_SIZE" "$MAX_SIZE_BYTES"
        FAILED=1
    else
        printf "OK: %s (%s bytes)\n" "$file" "$CURRENT_SIZE"
    fi
done < <(find . -name "*.wasm" -not -path "./.git/*" -not -path "*/node_modules/*" 2>/dev/null || true)

if [ "$WASM_FOUND" -eq 0 ]; then
    printf "No WASM files found to check.\n"
    exit 0
fi

if [ $FAILED -ne 0 ]; then
    printf "WASM size check failed.\n"
    exit 1
fi

printf "WASM size check passed.\n"
exit 0
