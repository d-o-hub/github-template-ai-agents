#!/usr/bin/env bash
# Test script to verify hardening against option injection.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$REPO_ROOT/tests/option-injection-test"

# Cleanup on exit
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

echo "Running option injection tests..."

# Test 1: chmod with hyphenated filename
echo "Testing chmod..."
touch -- "-v"
chmod +x -- "-v"
if [[ ! -x "-v" ]]; then
    echo "FAILED: chmod -v failed"
    (exit 1)
fi
echo "✓ chmod test passed"

# Test 2: readlink with hyphenated filename
echo "Testing readlink..."
ln -s -- "-v" "-link"
if ! readlink -f -- "-link" >/dev/null; then
    echo "FAILED: readlink -link failed"
    (exit 1)
fi
echo "✓ readlink test passed"

# Test 3: head/tail with hyphenated filename
echo "Testing head/tail..."
printf "test content\n" > "-v"
if ! head -n 1 -- "-v" >/dev/null; then
    echo "FAILED: head -v failed"
    (exit 1)
fi
if ! tail -n 1 -- "-v" >/dev/null; then
    echo "FAILED: tail -v failed"
    (exit 1)
fi
echo "✓ head/tail test passed"

# Test 4: mv with hyphenated filename
echo "Testing mv..."
mv -- "-v" "new-v"
if [[ ! -f "new-v" ]]; then
    echo "FAILED: mv -v failed"
    (exit 1)
fi
echo "✓ mv test passed"

# Test 5: grep with hyphenated filename or pattern
echo "Testing grep..."
printf "match\n" > "-file"
if ! grep -e "match" -- "-file" >/dev/null; then
    echo "FAILED: grep -e match -- -file failed"
    (exit 1)
fi
printf -- "-pattern\n" > "normal-file"
if ! grep -e "-pattern" -- "normal-file" >/dev/null; then
    echo "FAILED: grep -e -pattern -- normal-file failed"
    (exit 1)
fi
echo "✓ grep test passed"

# Test 6: printf with hyphenated variable
echo "Testing printf..."
VAR="-n"
OUTPUT=$(printf "%s\n" "$VAR")
if [[ "$OUTPUT" != "-n" ]]; then
    echo "FAILED: printf %s failed to handle -n"
    (exit 1)
fi
echo "✓ printf test passed"

echo "All option injection hardening tests PASSED"
