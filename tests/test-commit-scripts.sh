#!/usr/bin/env bash
# Test script for commit validation and helper scripts.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
VALIDATE_SCRIPT="$REPO_ROOT/scripts/validate-commit-message.sh"
AI_COMMIT_SCRIPT="$REPO_ROOT/scripts/ai-commit.sh"

echo "Running tests for commit scripts..."

# Create a temporary directory for test files
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Test 1: Valid commit message
echo "Test 1: Valid commit message..."
cat <<EOF > "$TEST_DIR/valid_msg.txt"
feat(core): add new feature

This is a valid body.
It has multiple lines.
EOF
"$VALIDATE_SCRIPT" "$TEST_DIR/valid_msg.txt"
echo "✓ Test 1 passed"

# Test 2: Invalid commit message (invalid type)
echo "Test 2: Invalid commit message (invalid type)..."
cat <<EOF > "$TEST_DIR/invalid_type.txt"
invalidtype(core): add new feature
EOF
if "$VALIDATE_SCRIPT" "$TEST_DIR/invalid_type.txt" 2>/dev/null; then
    echo "✗ Test 2 failed: Invalid type was accepted"
    exit 1
fi
echo "✓ Test 2 passed"

# Test 3: Invalid commit message (subject too long)
echo "Test 3: Invalid commit message (subject too long)..."
cat <<EOF > "$TEST_DIR/long_subject.txt"
feat(core): $(printf 'a%.0s' {1..80})
EOF
if "$VALIDATE_SCRIPT" "$TEST_DIR/long_subject.txt" 2>/dev/null; then
    echo "✗ Test 3 failed: Long subject was accepted"
    exit 1
fi
echo "✓ Test 3 passed"

# Test 4: Invalid commit message (body line too long)
# commitlint default for body-max-line-length is usually 100
echo "Test 4: Invalid commit message (body line too long)..."
cat <<EOF > "$TEST_DIR/long_body.txt"
feat(core): valid subject

$(printf 'b%.0s' {1..120})
EOF
if "$VALIDATE_SCRIPT" "$TEST_DIR/long_body.txt" 2>/dev/null; then
    echo "✗ Test 4 failed: Long body line was accepted"
    exit 1
fi
echo "✓ Test 4 passed"

# Test 5: AI commit script validation (subject too long)
echo "Test 5: AI commit script validation (subject too long)..."
LONG_SUBJECT=$(printf 'a%.0s' {1..80})
if "$AI_COMMIT_SCRIPT" --type feat --subject "$LONG_SUBJECT" 2>/dev/null; then
    echo "✗ Test 5 failed: AI commit script accepted long subject"
    exit 1
fi
echo "✓ Test 5 passed"

echo "All tests passed!"
