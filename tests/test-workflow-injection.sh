#!/usr/bin/env bash
# tests/test-workflow-injection.sh - Verify workflow injection detection

set -euo pipefail

# Setup test environment
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/.github/workflows"
mkdir -p "$TEST_ROOT/scripts"

cp scripts/validate-workflows.sh "$TEST_ROOT/scripts/"

# Mock colors for comparison
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

check_test() {
    local name="$1"
    local workflow_content="$2"
    local expected_fail="$3"

    echo "Running test: $name"
    printf "%s\n" "$workflow_content" > "$TEST_ROOT/.github/workflows/test.yml"

    # Run script and capture output
    set +e
    OUTPUT=$(cd "$TEST_ROOT" && ./scripts/validate-workflows.sh 2>&1)
    EXIT_CODE=$?
    set -e

    if [ "$expected_fail" = "true" ]; then
        if [ $EXIT_CODE -ne 0 ]; then
            echo "  ✓ Correctly failed"
        else
            echo "  ✗ Expected failure but passed"
            exit 1
        fi
    else
        if [ $EXIT_CODE -eq 0 ]; then
            echo "  ✓ Correctly passed"
        else
            echo "  ✗ Expected pass but failed"
            echo "Output: $OUTPUT"
            exit 1
        fi
    fi
}

# 1. Detect interpolation of untrusted 'github.event.issue.title' in a 'run' block
check_test "Untrusted github.event.issue.title in run block" "
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo \"\${{ github.event.issue.title }}\"
" "true"

# 2. Allow interpolation of whitelisted 'env.VARIABLE_NAME' in a 'run' block
check_test "Whitelisted env.VARIABLE_NAME in run block" "
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo \"\${{ env.FOO }}\"
" "false"

# 3. Detect interpolation of untrusted properties in a multiline 'script' block
check_test "Untrusted properties in multiline script block" "
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            console.log(\"\${{ github.event.issue.body }}\")
" "true"

# 4. Allow whitelisted 'github' properties (e.g., 'github.repository') in a 'run' block
check_test "Whitelisted github.repository in run block" "
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo \"\${{ github.repository }}\"
" "false"

# 5. Correctly parse and validate syntax for multiline 'script:' blocks after the injection check
check_test "Valid script syntax" "
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const x = 1;
            console.log(x);
" "false"

check_test "Invalid script syntax" "
name: Test
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const x = ; // syntax error
" "true"

echo "All workflow injection tests passed!"
