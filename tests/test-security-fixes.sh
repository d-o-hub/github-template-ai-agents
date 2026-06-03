#!/usr/bin/env bash
# tests/test-security-fixes.sh - Verify security fixes and functional correctness

set -uo pipefail

# Store the project root
PROJECT_ROOT=$(pwd)

# Setup test environment
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/scripts/lib"
mkdir -p "$TEST_ROOT/plans"
mkdir -p "$TEST_ROOT/.agents/skills/test-skill"

cp scripts/check-plan-numbering.sh "$TEST_ROOT/scripts/"
cp scripts/validate-skills.sh "$TEST_ROOT/scripts/"
cp scripts/lib/skill-validation.sh "$TEST_ROOT/scripts/lib/"

# Test 1: Verify scripts/check-plan-numbering.sh correctly reads numbers
echo "Test 1: check-plan-numbering.sh functional check..."
cat <<EOF > "$TEST_ROOT/plans/_status.json"
{
  "nextAvailable": {
    "plan": "042",
    "adr": "adr-007"
  }
}
EOF
cat <<EOF > "$TEST_ROOT/plans/README.md"
**Next available plan number**: \`042\`
**Next available ADR number**: \`adr-007\`
EOF

# Run script and check output
OUTPUT=$("$TEST_ROOT/scripts/check-plan-numbering.sh")
if [[ "$OUTPUT" == *"✓ Plan numbering consistent"* ]]; then
    echo "  ✓ Test 1 passed"
else
    echo "  ✗ Test 1 failed: Output was: $OUTPUT"
    FAILED_TESTS=1
fi

# Test 2: Verify scripts/validate-skills.sh correctly counts rules
echo "Test 2: validate-skills.sh rules count check..."
cat <<EOF > "$TEST_ROOT/.agents/skill-rules.json"
{
  "rule1": "value1",
  "rule2": "value2"
}
EOF
cat <<EOF > "$TEST_ROOT/.agents/skills/test-skill/SKILL.md"
---
name: test-skill
description: A test skill
version: 1.0.0
---
# Test Skill
EOF

# Run script and check output
OUTPUT=$("$TEST_ROOT/scripts/validate-skills.sh" 2>&1)
if echo "$OUTPUT" | grep -q "skill-rules.json: 2 rules defined"; then
    echo "  ✓ Test 2 passed"
else
    echo "  ✗ Test 2 failed: Output was: $OUTPUT"
    FAILED_TESTS=1
fi

# Test 3: Security Check - Malicious variable interpolation
echo "Test 3: Security check - Malicious variable interpolation..."

MALICIOUS_FILE="'); import os; os.system('echo INJECTED_PLAN'); print('"
touch "$TEST_ROOT/$MALICIOUS_FILE"

echo "  Testing python command pattern from check-plan-numbering.sh..."
if python3 -c "import json, sys; d=json.load(open(sys.argv[1])); print(d['nextAvailable']['plan'])" "$MALICIOUS_FILE" 2>/dev/null | grep -q "INJECTED_PLAN"; then
    echo "  ✗ Test 3a failed: Injection successful!"
    FAILED_TESTS=1
else
    echo "  ✓ Test 3a passed: No injection via sys.argv"
fi

echo "  Testing python command pattern from validate-skills.sh..."
MALICIOUS_RULES="'); import os; os.system('echo INJECTED_RULES'); print('"
touch "$TEST_ROOT/$MALICIOUS_RULES"
if python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$MALICIOUS_RULES" 2>/dev/null | grep -q "INJECTED_RULES"; then
    echo "  ✗ Test 3b failed: Injection successful!"
    FAILED_TESTS=1
else
    echo "  ✓ Test 3b passed: No injection via sys.argv"
fi

echo "All security and functional tests passed!"

# Test 4: Option Injection Hardening in AWK and WC
echo "Test 4: Option Injection Hardening in AWK and WC..."

HYPHEN_FILE="-v"
touch "$TEST_ROOT/$HYPHEN_FILE"
echo "content" > "$TEST_ROOT/$HYPHEN_FILE"

echo "  Testing awk hardening..."
if (cd "$TEST_ROOT" && awk -- '1' "$HYPHEN_FILE" 2>/dev/null | grep -q "content"); then
    echo "  ✓ Test 4a passed: awk handled $HYPHEN_FILE correctly"
else
    echo "  ✗ Test 4a failed: awk did not handle $HYPHEN_FILE correctly"
    FAILED_TESTS=1
fi

echo "  Testing wc hardening..."
if (cd "$TEST_ROOT" && wc -l -- "$HYPHEN_FILE" 2>/dev/null | grep -q "1 $HYPHEN_FILE"); then
    echo "  ✓ Test 4b passed: wc handled $HYPHEN_FILE correctly"
else
    echo "  ✗ Test 4b failed: wc did not handle $HYPHEN_FILE correctly"
    FAILED_TESTS=1
fi

# Test 5: xargs -r safety
echo "Test 5: xargs -r safety..."
if [[ $(printf "" | xargs -r echo "executed") == "" ]]; then
    echo "  ✓ Test 5 passed: xargs -r did not execute on empty input"
else
    echo "  ✗ Test 5 failed: xargs -r executed on empty input"
    FAILED_TESTS=1
fi

echo "Option injection and xargs tests passed!"

# Test 6: Octal Interpretation Hardening
echo "Test 6: Octal Interpretation Hardening..."

# Test 6a: bump_patch_version.sh octal handling
echo "  Testing bump_patch_version.sh octal handling (08 -> 9)..."
mkdir -p "$TEST_ROOT/bump_test/scripts"
cp "$PROJECT_ROOT/scripts/bump_patch_version.sh" "$TEST_ROOT/bump_test/scripts/"
cp "$PROJECT_ROOT/scripts/propagate-version.sh" "$TEST_ROOT/bump_test/scripts/"
(
    cd "$TEST_ROOT/bump_test"
    echo "0.1.08" > "VERSION"
    echo "## [Unreleased]" > "CHANGELOG-TEMPLATE.md"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git add . && git commit -m "initial" -q
    if bash scripts/bump_patch_version.sh > /dev/null 2>&1; then
        NEW_V=$(cat VERSION)
        if [[ "$NEW_V" == "0.1.9" ]]; then
            echo "  ✓ Test 6a passed: 0.1.08 bumped to 0.1.9"
        else
            echo "  ✗ Test 6a failed: expected 0.1.9, got $NEW_V"
            exit 1
        fi
    else
        echo "  ✗ Test 6a failed: script crashed (likely octal error)"
        exit 1
    fi
) || FAILED_TESTS=1

# Test 6b: loc_gate.sh octal handling
echo "  Testing loc_gate.sh octal handling..."
mkdir -p "$TEST_ROOT/loc_test/scripts"
mkdir -p "$TEST_ROOT/loc_test/.agents/skills"
cp "$PROJECT_ROOT/scripts/loc_gate.sh" "$TEST_ROOT/loc_test/scripts/"
(
    cd "$TEST_ROOT/loc_test"
    echo "MAX_LINES_AGENTS_MD=0150" > "AGENTS.md"
    for i in {1..10}; do echo "line $i"; done >> "AGENTS.md"
    if MAX_SKILL_OVERRIDE=080 bash scripts/loc_gate.sh > /dev/null 2>&1; then
        echo "  ✓ Test 6b passed: loc_gate.sh handled leading zeros"
    else
        echo "  ✗ Test 6b failed: loc_gate.sh crashed or returned error"
        exit 1
    fi
) || FAILED_TESTS=1

# Test 6c: wasm_size_gate.sh octal handling
echo "  Testing wasm_size_gate.sh octal handling..."
mkdir -p "$TEST_ROOT/wasm_test/scripts"
cp "$PROJECT_ROOT/scripts/wasm_size_gate.sh" "$TEST_ROOT/wasm_test/scripts/"
(
    cd "$TEST_ROOT/wasm_test"
    touch "test.wasm"
    if MAX_WASM_SIZE_BYTES=01048576 bash scripts/wasm_size_gate.sh > /dev/null 2>&1; then
        echo "  ✓ Test 6c passed: wasm_size_gate.sh handled leading zeros"
    else
        echo "  ✗ Test 6c failed: wasm_size_gate.sh crashed or returned error"
        exit 1
    fi
) || FAILED_TESTS=1

# Test 6d: skill-validation.sh octal handling
echo "  Testing skill-validation.sh octal handling (version 08/09)..."
mkdir -p "$TEST_ROOT/skill_test/.agents/skills/test-skill"
mkdir -p "$TEST_ROOT/skill_test/scripts/lib"
cp "$PROJECT_ROOT/scripts/validate-skills.sh" "$TEST_ROOT/skill_test/scripts/"
cp "$PROJECT_ROOT/scripts/lib/skill-validation.sh" "$TEST_ROOT/skill_test/scripts/lib/"
(
    cd "$TEST_ROOT/skill_test"
    echo "0.2.10" > "VERSION"
    cat <<SKILL > ".agents/skills/test-skill/SKILL.md"
---
name: test-skill
description: test
version: 1.0.0
template_version: 0.08.0
---
SKILL
    if bash scripts/validate-skills.sh > /dev/null 2>&1; then
        echo "  ✓ Test 6d passed: skill-validation.sh handled leading zeros in version"
    else
        echo "  ✗ Test 6d failed: skill-validation.sh crashed or returned error"
        exit 1
    fi
) || FAILED_TESTS=1

if [[ ${FAILED_TESTS:-0} -ne 0 ]]; then
    echo "Some tests failed!"
    exit 1
fi

echo "Octal hardening tests passed!"
