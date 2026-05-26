#!/usr/bin/env bash
# Tests for GitHub Actions workflow injection detection logic.
# Use bash because exit in script blocks run_in_bash_session
VALIDATOR="./scripts/validate-workflows.sh"
WORKFLOW_DIR=".github/workflows"
TEST_WF="$WORKFLOW_DIR/test-sentinel-detection.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Running workflow validation tests..."

cleanup() {
    rm -f "$TEST_WF"
}
trap cleanup EXIT

run_test() {
    local name="$1"
    local content="$2"
    local expected_fail="$3"

    printf "Test: %s... " "$name"
    echo "$content" > "$TEST_WF"

    local output
    output=$("$VALIDATOR" "$TEST_WF" 2>&1)
    local status=$?

    if [[ "$expected_fail" == "true" ]]; then
        if [[ $status -ne 0 ]] && echo "$output" | grep -q "Potential script injection risk detected"; then
            printf "${GREEN}PASSED${NC}\n"
        else
            printf "${RED}FAILED${NC} (expected detection)\n"
            echo "$output"
            return 1
        fi
    else
        if [[ $status -eq 0 ]]; then
            printf "${GREEN}PASSED${NC}\n"
        else
            printf "${RED}FAILED${NC} (unexpected detection)\n"
            echo "$output"
            return 1
        fi
    fi
}

# Test 1: Identify unsafe interpolation in run block
run_test "Detected unsafe github.event in run block" "
name: Unsafe Workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Unsafe
        run: echo \"\${{ github.event.issue.title }}\"
" "true"

# Test 2: Identify unsafe interpolation in script block
run_test "Detected unsafe github.event in script block" "
name: Unsafe Script
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Unsafe Script
        uses: actions/github-script@v6
        with:
          script: console.log(\"\${{ github.event.comment.body }}\")
" "true"

# Test 3: Allow safe properties
run_test "Allowed safe properties" "
name: Safe Workflow
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Safe
        run: |
          echo \"Repo: \${{ github.repository }}\"
          echo \"Actor: \${{ github.actor }}\"
          echo \"SHA: \${{ github.sha }}\"
          echo \"Env: \${{ env.MY_VAR }}\"
          echo \"Secret: \${{ secrets.MY_SECRET }}\"
" "false"

# Test 4: Reject controllable refs (PR feedback)
run_test "Detected unsafe github.head_ref" "
name: Controllable Ref
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Unsafe Ref
        run: echo \"Branch: \${{ github.head_ref }}\"
" "true"

# Test 5: Single-line run statement
run_test "Detected unsafe interpolation in single-line run" "
name: Single Line Unsafe
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Single Line
        run: echo \"\${{ github.event.issue.title }}\"
" "true"

echo -e "\n${GREEN}All workflow validation tests passed!${NC}"
