#!/usr/bin/env bash
# tests/test-sentinel-hardening.sh - Verify Sentinel's security hardening fixes
#
# This test suite verifies:
# 1. 'print_category_badge' output is reachable and correctly formatted.
# 2. 'execute_swarm_analysis' prevents shell expansion in topics.
# 3. 'cleanup_worktrees' matches literal paths correctly (regex safety).
# 4. 'mkdir' and 'grep' handle hyphenated variables correctly using '--'.

set -euo pipefail

# Setup test environment
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

# Mock generate_research_queries for swarm-analysis testing
generate_research_queries() {
    echo "Mocked queries" > "$2"
}
export -f generate_research_queries

# Source libraries
source scripts/lib/swarm-analysis.sh
source scripts/lib/command-categories.sh

echo "Running Sentinel hardening tests..."

# Test 1: Verify 'print_category_badge' reachability and format
echo "Test 1: 'print_category_badge' reachability..."
OUTPUT=$(print_category_badge "safe")
if [[ "$OUTPUT" == *"[safe]"* ]]; then
    echo "  ✓ Passed: Output is reachable and contains category"
else
    echo "  ✗ Failed: Output not found or unreachable"
    exit 1
fi

# Test 2: Verify 'execute_swarm_analysis' prevents shell expansion
echo "Test 2: 'execute_swarm_analysis' expansion prevention..."
MALICIOUS_TOPIC='$(touch '"$TEST_ROOT"'/pwned)'
execute_swarm_analysis "$TEST_ROOT" "$MALICIOUS_TOPIC" "analysis" "reports" > /dev/null

if [[ -f "$TEST_ROOT/pwned" ]]; then
    echo "  ✗ Failed: Command substitution occurred!"
    exit 1
else
    echo "  ✓ Passed: No command substitution detected"
fi

# Test 3: Verify 'cleanup_worktrees' literal string matching
echo "Test 3: 'cleanup_worktrees' literal matching..."
# Mock git to verify arguments passed to worktree remove
git() {
    if [[ "$1" == "worktree" && "$2" == "list" ]]; then
        echo "worktree $TEST_ROOT/wt.fixed"
        echo "worktree $TEST_ROOT/wt*regex"
    elif [[ "$1" == "worktree" && "$2" == "remove" ]]; then
        # Expecting: git worktree remove --force -- "$wt"
        # Arguments: $1=worktree $2=remove $3=--force $4=-- $5=PATH
        printf "Removing %s\n" "$5"
    else
        command git "$@"
    fi
}

# We need to source worktree-manager.sh first, then set the array
export WORKTREE_BASE="$TEST_ROOT/worktrees"
source scripts/lib/worktree-manager.sh
# Override the empty array initialized in the script
CREATED_WORKTREES=("$TEST_ROOT/wt.fixed" "$TEST_ROOT/wt*regex")

OUTPUT=$(cleanup_worktrees 2>&1)
if echo "$OUTPUT" | grep -F -q "$TEST_ROOT/wt.fixed" && echo "$OUTPUT" | grep -F -q "$TEST_ROOT/wt*regex"; then
    echo "  ✓ Passed: Literal matching confirmed (regex characters ignored)"
else
    echo "  ✗ Failed: Literal matching failed or path misinterpretation"
    echo "  Output: $OUTPUT"
    exit 1
fi

# Test 4: Verify 'setup_worktree' handles hyphenated branch names (option injection)
echo "Test 4: 'setup_worktree' option injection protection..."
HYPHEN_BRANCH="-v-branch"

# Re-define git for this specific test
git() {
    if [[ "$1" == "worktree" ]]; then
        printf "git worktree called with: %s\n" "$*"
    else
        command git "$@"
    fi
}

mkdir -p -- "$WORKTREE_BASE"
OUTPUT=$(setup_worktree "$HYPHEN_BRANCH" 2>&1)
if [[ "$OUTPUT" == *"git worktree called with: worktree add"* && "$OUTPUT" == *"-- $WORKTREE_BASE/$HYPHEN_BRANCH"* ]]; then
    echo "  ✓ Passed: setup_worktree correctly used '--' separator"
else
    echo "  ✗ Failed: setup_worktree might be vulnerable to option injection"
    echo "  Output: $OUTPUT"
    exit 1
fi

echo "All Sentinel hardening tests PASSED successfully."
