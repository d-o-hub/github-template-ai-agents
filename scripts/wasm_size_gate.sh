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
# Optimization: Use xargs to batch stat calls and eliminate O(N) process forks and process substitution
WASM_FOUND=0

TMP_OUT=$(mktemp)
TMP_FIND=$(mktemp)
cleanup_wasm_gate() {
    rm -f -- "$TMP_OUT" "$TMP_FIND"
}
trap cleanup_wasm_gate EXIT

# Determine stat syntax based on OS outside the loop to avoid bad fallback
if stat -c "%s|%n" . >/dev/null 2>&1; then
    STAT_CMD='stat -c "%s|%n" -- "$@"'
else
    STAT_CMD='stat -f "%z|%N" -- "$@"'
fi

# Security: Use -- separator with stat to prevent option injection from malicious filenames
# Add -type f to ensure we only check files, not directories.
# Avoid using xargs -r (GNU extension) to maintain macOS compatibility.
# Avoid command substitution $() which strips null bytes.
find . -type f -name "*.wasm" -not -path "./.git/*" -not -path "*/node_modules/*" -print0 2>/dev/null > "$TMP_FIND" || true
if [[ -s "$TMP_FIND" ]]; then
    xargs -0 sh -c "$STAT_CMD" _ < "$TMP_FIND" > "$TMP_OUT" || true
fi

if [[ -s "$TMP_OUT" ]]; then
    WASM_FOUND=1
    while IFS="|" read -r size file; do
        if [[ "$size" -gt "$MAX_SIZE_BYTES" ]]; then
            printf "ERROR: %s size %s exceeds limit %s\n" "$file" "$size" "$MAX_SIZE_BYTES"
            FAILED=1
        else
            printf "OK: %s (%s bytes)\n" "$file" "$size"
        fi
    done < "$TMP_OUT"
fi

if [[ "$WASM_FOUND" -eq 0 ]]; then
    printf "No WASM files found to check.\n"
    exit 0
fi

if [[ $FAILED -ne 0 ]]; then
    printf "WASM size check failed.\n"
    exit 1
fi

printf "WASM size check passed.\n"
exit 0
