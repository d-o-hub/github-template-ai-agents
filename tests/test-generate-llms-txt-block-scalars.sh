#!/usr/bin/env bash
# Test for generate-llms-txt.sh: Verify it correctly parses descriptions starting with block scalar modifiers like '>-' or '|+'.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Use a temporary directory for test artifacts
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

assert_contains() {
    if ! grep -F -q -- "$1" "$2"; then
        printf "%bFAILED: Expected '%s' in %s%b\n" "$RED" "$1" "$2" "$NC"
        exit 1
    fi
}

printf "Testing block scalar modifier parsing in generate-llms-txt.sh...\n\n"

# Test 1: Block scalar modifier '>-' (folded style)
printf "Test 1: Parsing '>-' block scalar modifier... "
MOCK_README="$TEST_DIR/README.md"
mkdir -p "$TEST_DIR/.agents/skills"
mkdir -p "$TEST_DIR/scripts"
mkdir -p "$TEST_DIR/agents-docs"
touch "$TEST_DIR/VERSION"
cp scripts/generate-llms-txt.sh "$TEST_DIR/scripts/"

cat > "$MOCK_README" <<'EOF'
# Test Project

>-
  This is a folded description
  that spans multiple lines
  and should be parsed correctly.

Content here.
EOF

export LLMS_TXT="$TEST_DIR/llms-1.txt"
export LLMS_FULL_TXT="$TEST_DIR/llms-full-1.txt"

(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null 2>&1
)

# The description should be parsed and included in the output
assert_contains "This is a folded description that spans multiple lines and should be parsed correctly." "$LLMS_TXT"
printf "%bPASSED%b\n" "$GREEN" "$NC"

# Test 2: Block scalar modifier '|+' (literal style)
printf "Test 2: Parsing '|+' block scalar modifier... "
MOCK_README="$TEST_DIR/README.md"
cat > "$MOCK_README" <<'EOF'
# Test Project 2

|+
  This is a literal description
  with   multiple   spaces
  that should be preserved.

Content here.
EOF

export LLMS_TXT="$TEST_DIR/llms-2.txt"
export LLMS_FULL_TXT="$TEST_DIR/llms-full-2.txt"

(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null 2>&1
)

# The description should be parsed with preserved spacing
assert_contains "This is a literal description" "$LLMS_TXT"
assert_contains "with   multiple   spaces" "$LLMS_TXT"
printf "%bPASSED%b\n" "$GREEN" "$NC"

# Test 3: Block scalar modifier with inline content
printf "Test 3: Parsing '>-' with inline content... "
MOCK_README="$TEST_DIR/README.md"
cat > "$MOCK_README" <<'EOF'
# Test Project 3

>-
This is a single-line folded description.

Content here.
EOF

export LLMS_TXT="$TEST_DIR/llms-3.txt"
export LLMS_FULL_TXT="$TEST_DIR/llms-full-3.txt"

(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null 2>&1
)

assert_contains "This is a single-line folded description." "$LLMS_TXT"
printf "%bPASSED%b\n" "$GREEN" "$NC"

# Test 4: Block scalar modifier with inline content
printf "Test 4: Parsing '|+' with inline content... "
MOCK_README="$TEST_DIR/README.md"
cat > "$MOCK_README" <<'EOF'
# Test Project 4

|+
This is a literal single-line description.

Content here.
EOF

export LLMS_TXT="$TEST_DIR/llms-4.txt"
export LLMS_FULL_TXT="$TEST_DIR/llms-full-4.txt"

(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null 2>&1
)

assert_contains "This is a literal single-line description." "$LLMS_TXT"
printf "%bPASSED%b\n" "$GREEN" "$NC"

printf "\nAll block scalar modifier tests %bPASSED%b\n" "$GREEN" "$NC"
