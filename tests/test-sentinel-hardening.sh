#!/usr/bin/env bash
# tests/test-sentinel-hardening.sh - Verify Sentinel's security enhancements

set -euo pipefail

# Setup test environment
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/scripts/lib"
mkdir -p "$TEST_ROOT/.agents/skills/test-skill/evals"

# Copy scripts and library to test environment
cp scripts/eval-skills.sh "$TEST_ROOT/scripts/"
cp scripts/lib/lint_cache.sh "$TEST_ROOT/scripts/lib/"

# Mock REPO_ROOT for scripts
export REPO_ROOT="$TEST_ROOT"

# Test 1: Verify lint_cache.sh fails closed when no hashing tool is available
echo "Test 1: lint_cache.sh fail-closed check..."

# Create a mock PATH without sha256sum or shasum
MOCK_BIN="$TEST_ROOT/mock_bin"
mkdir -p "$MOCK_BIN"
# Copy basic tools needed for the test to mock_bin
for tool in bash cat mkdir realpath ls grep awk tr touch; do
    if command -v "$tool" >/dev/null; then
        cp "$(command -v "$tool")" "$MOCK_BIN/"
    fi
done

(
    export PATH="$MOCK_BIN"
    # Source the library and attempt to hash a file
    touch "$TEST_ROOT/test_file"
    # We expect this to exit 1
    if bash -c "source $TEST_ROOT/scripts/lib/lint_cache.sh; _get_hash_internal $TEST_ROOT/test_file" 2>"$TEST_ROOT/error_log"; then
        echo "  ✗ Test 1 failed: Script did not exit with error"
        exit 1
    fi
    if grep -q "Error: Neither sha256sum nor shasum is available" "$TEST_ROOT/error_log"; then
        echo "  ✓ Test 1 passed: Failed closed with expected error message"
    else
        echo "  ✗ Test 1 failed: Unexpected error message: $(cat "$TEST_ROOT/error_log")"
        exit 1
    fi
)

# Test 2: Verify eval-skills.sh uses printf for output hardening
echo "Test 2: eval-skills.sh printf hardening check..."

# Create a skill with an empty evals.json and a name that would be problematic for echo
DANGEROUS_SKILL_NAME="-e"
mkdir -p "$TEST_ROOT/.agents/skills/$DANGEROUS_SKILL_NAME/evals"
touch "$TEST_ROOT/.agents/skills/$DANGEROUS_SKILL_NAME/evals/evals.json"

# Mock the structure evaluator script since eval-skills.sh expects it
mkdir -p "$TEST_ROOT/.agents/skills/skill-evaluator/scripts"
echo "import sys; sys.exit(0)" > "$TEST_ROOT/.agents/skills/skill-evaluator/scripts/check_structure.py"

# Run eval-skills.sh and check if it correctly handles the name
# We mock python3 to avoid actual execution but let the shell logic run
(
    cd "$TEST_ROOT"
    # Mock find and awk to only return our dangerous skill for the specific empty file check
    # But for simplicity, we'll just run the script and check output
    # We use a subshell to avoid affecting the main test environment's PATH
    OUTPUT=$(bash scripts/eval-skills.sh 2>&1 || true)
    if echo "$OUTPUT" | grep -F " [FAIL] $DANGEROUS_SKILL_NAME: evals missing 'expected_output' field"; then
        echo "  ✓ Test 2 passed: Correctly output failure message for dangerous filename"
    else
        echo "  ✗ Test 2 failed: Could not find expected failure message in output"
        exit 1
    fi
)

# Test 3: Verify lint_cache.sh succeeds when sha256sum is available
echo "Test 3: lint_cache.sh sha256sum success check..."
(
    # Ensure sha256sum is in path (it should be in our normal environment)
    if ! command -v sha256sum &>/dev/null; then
        echo "  - Skipping Test 3: sha256sum not available in environment"
    else
        touch "$TEST_ROOT/success_file"
        HASH=$(bash -c "source $TEST_ROOT/scripts/lib/lint_cache.sh; _get_hash_internal $TEST_ROOT/success_file")
        if [[ "$HASH" =~ ^[a-f0-9]{64}$ ]]; then
            echo "  ✓ Test 3 passed: Successfully generated SHA256 hash"
        else
            echo "  ✗ Test 3 failed: Generated invalid hash: $HASH"
            exit 1
        fi
    fi
)

echo "All Sentinel hardening tests passed!"
