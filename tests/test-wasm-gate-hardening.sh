#!/usr/bin/env bash
# tests/test-wasm-gate-hardening.sh - Verify wasm_size_gate.sh hardening

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WASM_GATE="$REPO_ROOT/scripts/wasm_size_gate.sh"

# Setup test environment
TEST_TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

echo "Running WASM Gate Hardening Tests..."

# Test 1: Malicious filename starting with hyphen (option injection)
echo "Test 1: Malicious filename starting with hyphen..."
# -e is a common echo flag. If wasm_size_gate.sh uses echo $file, it might trigger.
MALICIOUS_FILE="$TEST_TEMP_DIR/-e.wasm"
printf "dummy wasm content" > "$MALICIOUS_FILE"

# Run the gate script from the temp dir
(
    cd "$TEST_TEMP_DIR"
    if "$WASM_GATE" > output.log 2>&1; then
        echo "  ✓ Test 1 passed: Script handled -e.wasm safely"
        if grep -q "OK: ./-e.wasm" output.log; then
             echo "  ✓ Test 1 detail: Filename correctly reported in output"
        else
             echo "  ✗ Test 1 detail: Filename NOT correctly reported in output" >&2
             cat output.log >&2
             exit 1
        fi
    else
        echo "  ✗ Test 1 failed: Script crashed or failed on -e.wasm" >&2
        cat output.log >&2
        exit 1
    fi
)

# Test 2: Oversized WASM file
echo "Test 2: Oversized WASM file..."
LARGE_FILE="$TEST_TEMP_DIR/large.wasm"
# Create a 2MB file (default limit is 1MB)
dd if=/dev/zero of="$LARGE_FILE" bs=1024 count=2048 2>/dev/null

(
    cd "$TEST_TEMP_DIR"
    if "$WASM_GATE" > output.log 2>&1; then
        echo "  ✗ Test 2 failed: Script should have failed on oversized file" >&2
        cat output.log >&2
        exit 1
    else
        echo "  ✓ Test 2 passed: Script correctly identified oversized file"
        if grep -q "ERROR: ./large.wasm size 2097152 exceeds limit" output.log; then
             echo "  ✓ Test 2 detail: Correct error message shown"
        else
             echo "  ✗ Test 2 detail: Incorrect or missing error message" >&2
             cat output.log >&2
             exit 1
        fi
    fi
)

# Test 3: Structural injection attempt in MAX_WASM_SIZE_BYTES
echo "Test 3: MAX_WASM_SIZE_BYTES validation..."
# Attempting to inject commands or escapes via the environment variable
if MAX_WASM_SIZE_BYTES="1024\nGOTCHA" "$WASM_GATE" > output.log 2>&1; then
    echo "  ✗ Test 3 failed: Script should have rejected invalid MAX_WASM_SIZE_BYTES"
    exit 1
else
    echo "  ✓ Test 3 passed: Script rejected malicious MAX_WASM_SIZE_BYTES"
    if grep -q "Error: MAX_WASM_SIZE_BYTES must be numeric" output.log; then
         echo "  ✓ Test 3 detail: Correct validation error shown"
    else
         echo "  ✗ Test 3 detail: Incorrect validation error"
         cat output.log
         exit 1
    fi
fi

echo "All WASM gate hardening tests passed!"
