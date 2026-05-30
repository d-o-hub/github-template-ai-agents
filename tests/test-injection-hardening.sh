#!/usr/bin/env bash
# tests/test-injection-hardening.sh - Verify script hardening against injection

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Setup test environment
TEST_TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_TEMP_DIR"' EXIT

echo "Running Injection Hardening Tests..."

# Test 1: Hyphen-prefixed filenames
echo "Test 1: Hyphen-prefixed filenames..."
HYPHEN_SH="$TEST_TEMP_DIR/-n.sh"
printf "#!/bin/sh\necho hello\n" > "$HYPHEN_SH"

# We want to verify that shellcheck handles this file when called as in quality_gate.sh
# In quality_gate.sh: lint_if_changed "$script" "shellcheck" ".shellcheckrc" shellcheck --severity=error -f quiet -- "$script"
if command -v shellcheck &> /dev/null; then
    if shellcheck --severity=error -f quiet -- "$HYPHEN_SH" >/dev/null 2>&1; then
        echo "  ✓ Test 1a passed: shellcheck handled hyphenated filename with --"
    else
        echo "  ✗ Test 1a failed: shellcheck failed on hyphenated filename"
        exit 1
    fi
else
    echo "  - Test 1a skipped: shellcheck not installed"
fi

HYPHEN_MD="$TEST_TEMP_DIR/-n.md"
printf "# Test\n" > "$HYPHEN_MD"
# In quality_gate.sh: lint_if_changed "$md_file" "markdownlint" "markdownlint.toml" markdownlint -- "$md_file"
if command -v markdownlint &> /dev/null; then
    if markdownlint -- "$HYPHEN_MD" >/dev/null 2>&1; then
        echo "  ✓ Test 1b passed: markdownlint handled hyphenated filename with --"
    else
        echo "  ✗ Test 1b failed: markdownlint failed on hyphenated filename"
        exit 1
    fi
else
    echo "  - Test 1b skipped: markdownlint not installed"
fi

# Test 2: printf handles backslashes in data safely
echo "Test 2: printf handles backslashes in data safely..."
DATA="Line 1\nLine 2" # literal \n
# Using printf "%s" should print it literally
OUTPUT=$(printf "%s" "$DATA")
if [[ "$OUTPUT" == "Line 1\nLine 2" ]]; then
    echo "  ✓ Test 2 passed: printf %s preserved literal backslashes"
else
    echo "  ✗ Test 2 failed: printf %s interpreted backslashes: $OUTPUT"
    exit 1
fi

# Test 3: ANSI colors with printf %b
echo "Test 3: ANSI colors with printf %b..."
RED='\033[0;31m'
NC='\033[0m'
# Using printf %b should interpret the escape sequences in the variable
OUTPUT=$(printf "%bColor%b" "$RED" "$NC")
# Check if it contains the escape sequence
if [[ "$OUTPUT" == *$'\033[0;31m'* ]]; then
    echo "  ✓ Test 3 passed: printf %b correctly interpreted color escape sequences"
else
    echo "  ✗ Test 3 failed: printf %b did not interpret color escape sequences: $OUTPUT"
    exit 1
fi

# Test 4: Verify validate-github-actions-shas.sh handles malicious input in action names
echo "Test 4: validate-github-actions-shas.sh safety..."
# Create a dummy workflow file with a suspicious action reference
mkdir -p "$TEST_TEMP_DIR/.github/workflows"
BAD_WF="$TEST_TEMP_DIR/.github/workflows/bad.yml"
# Action name starting with - to test option injection if grep/awk were vulnerable
# and content with escape sequences to test structural injection if echo -e were used
printf "jobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: -bad-action-name\\\\nwith-newline@v1\n" > "$BAD_WF"

# Run the script against this directory
# We need to point it to the test directory.
(
    cd "$TEST_TEMP_DIR"
    # Copy the script and its dependencies
    mkdir scripts
    cp "$REPO_ROOT/scripts/validate-github-actions-shas.sh" scripts/

    # Run it. It should report failure but NOT execute anything or crash.
    # We use a subshell to avoid affecting the test environment
    # FORCE_COLOR=0 to avoid ANSI codes in grep check, OR handle them.
    if FORCE_COLOR=0 ./scripts/validate-github-actions-shas.sh > output.log 2>&1; then
        echo "  ✗ Test 4 failed: validate-github-actions-shas.sh should have failed on bad SHA"
        exit 1
    else
        # Verify it didn't interpret the newline or hyphen as an option
        # Note: awk already stripped the \n if it wasn't escaped correctly in the uses string
        # But we want to make sure it's printed literally if it was literal in the input
        if grep -q "with-newline" output.log; then
             echo "  ✓ Test 4 passed: validate-github-actions-shas.sh handled bad action name safely"
        else
             echo "  ✗ Test 4 failed: Output did not contain expected strings or handled incorrectly"
             cat output.log
             exit 1
        fi
    fi
)

echo "All injection hardening tests passed!"
