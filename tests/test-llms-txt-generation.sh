#!/usr/bin/env bash
# Tests for llms.txt and llms-full.txt generation script.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Use a temporary directory for test artifacts to avoid polluting the repo
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Mock environment setup
MOCK_README="$TEST_DIR/README.md"
MOCK_SKILLS_DIR="$TEST_DIR/.agents/skills"
mkdir -p "$MOCK_SKILLS_DIR/skill-a"
mkdir -p "$MOCK_SKILLS_DIR/skill-b"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
PASSED_MSG='%bPASSED%b\n'

assert_contains() {
    local expected="$1"
    local file="$2"
    if ! grep -F -q -- "$expected" "$file"; then
        printf "%bFAILED: Expected '%s' in %s%b\n" "$RED" "$expected" "$file" "$NC" >&2
        exit 1
    fi
}

assert_not_contains() {
    local pattern="$1"
    local file="$2"
    if grep -F -q -- "$pattern" "$file"; then
        printf "%bFAILED: Did NOT expect '%s' in %s%b\n" "$RED" "$pattern" "$file" "$NC" >&2
        exit 1
    fi
}

printf "Running llms.txt generation tests...\n"

# Test 1: Extraction of name/description from standard README.md
printf "Test 1: Extraction from README.md... "
cat > "$MOCK_README" <<EOF
# Mock Project Name

> Mock project description that spans
> multiple lines.

Some other content.
EOF

export LLMS_TXT="$TEST_DIR/llms.txt"
export LLMS_FULL_TXT="$TEST_DIR/llms-full.txt"

# Create a minimal scripts dir in TEST_DIR if the script expects to find it
mkdir -p "$TEST_DIR/scripts"
cp scripts/generate-llms-txt.sh "$TEST_DIR/scripts/"
mkdir -p "$TEST_DIR/agents-docs"
touch "$TEST_DIR/VERSION"

# Run generator in mock environment
(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null
)

assert_contains "# Mock Project Name" "$LLMS_TXT"
assert_contains "> Mock project description that spans multiple lines." "$LLMS_TXT"
printf "$PASSED_MSG" "$GREEN" "$NC"

# Test 2: Completeness of llms-full.txt skill index
printf "Test 2: Skill index completeness... "
cat > "$MOCK_SKILLS_DIR/skill-a/SKILL.md" <<EOF
---
name: skill-a
description: Description for skill A
---
# Skill A
EOF

cat > "$MOCK_SKILLS_DIR/skill-b/SKILL.md" <<EOF
---
name: skill-b
description: Description for skill B
---
# Skill B
EOF

(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null
)

assert_contains "- [skill-a](.agents/skills/skill-a/SKILL.md): Description for skill A" "$LLMS_FULL_TXT"
assert_contains "- [skill-b](.agents/skills/skill-b/SKILL.md): Description for skill B" "$LLMS_FULL_TXT"
printf "$PASSED_MSG" "$GREEN" "$NC"

# Test 3: Quality gate failure on manual modification
printf "Test 3: Quality gate divergence check... "
# Generate clean state
./scripts/generate-llms-txt.sh > /dev/null
# Manually modify
echo "Tampered" >> llms.txt

# Run quality gate LLM check part
FAILED=0
TMP_LLMS=$(mktemp)
TMP_LLMS_FULL=$(mktemp)
(
    export LLMS_TXT="$TMP_LLMS"
    export LLMS_FULL_TXT="$TMP_LLMS_FULL"
    ./scripts/generate-llms-txt.sh > /dev/null 2>&1
)
if ! diff -q llms.txt "$TMP_LLMS" > /dev/null; then
    FAILED=1
fi
rm -f "$TMP_LLMS" "$TMP_LLMS_FULL"

if [[ $FAILED -eq 1 ]]; then
    printf "$PASSED_MSG" "$GREEN" "$NC"
else
    printf "%bFAILED: Quality gate did not detect divergence%b\n" "$RED" "$NC"
    exit 1
fi
# Restore
./scripts/generate-llms-txt.sh > /dev/null

# Test 4: Handling of missing/malformed SKILL.md frontmatter
printf "Test 4: Malformed skill frontmatter... "
mkdir -p "$MOCK_SKILLS_DIR/skill-c"
cat > "$MOCK_SKILLS_DIR/skill-c/SKILL.md" <<EOF
# Malformed
No frontmatter here.
EOF

(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null
)
# Should fallback to directory name
assert_contains "- [skill-c](.agents/skills/skill-c/SKILL.md): No description available." "$LLMS_FULL_TXT"
printf "$PASSED_MSG" "$GREEN" "$NC"

# Test 5: Robustness against malformed README.md
printf "Test 5: Malformed README.md (no H1)... "
cat > "$MOCK_README" <<EOF
No H1 here.
> But description exists.
EOF

(
    cd "$TEST_DIR"
    ./scripts/generate-llms-txt.sh > /dev/null
)
# Should have fallback title
assert_contains "# Unnamed Project" "$LLMS_TXT"
assert_contains "> But description exists." "$LLMS_TXT"
printf "$PASSED_MSG" "$GREEN" "$NC"

printf "All llms.txt generation tests $PASSED_MSG" "$GREEN" "$NC"
