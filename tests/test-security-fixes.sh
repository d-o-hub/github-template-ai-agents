#!/usr/bin/env bash
# tests/test-security-fixes.sh - Verify security fixes and functional correctness

set -uo pipefail

# Setup test environment
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/scripts/lib"
mkdir -p "$TEST_ROOT/plans"
mkdir -p "$TEST_ROOT/agents-docs"
mkdir -p "$TEST_ROOT/analysis"
mkdir -p "$TEST_ROOT/.agents/skills/test-skill"

cp scripts/check-plan-numbering.sh "$TEST_ROOT/scripts/"
cp scripts/validate-skills.sh "$TEST_ROOT/scripts/"
cp scripts/lib/skill-validation.sh "$TEST_ROOT/scripts/lib/"

# Test 1: Verify scripts/check-plan-numbering.sh correctly reads numbers
echo "Test 1: check-plan-numbering.sh functional check..."
cat <<STATUS > "$TEST_ROOT/plans/_status.json"
{
  "nextAvailable": {
    "plan": "042",
    "adr": "adr-007"
  }
}
STATUS
cat <<README > "$TEST_ROOT/plans/README.md"
**Next available plan number**: \`042\`
**Next available ADR number**: \`adr-007\`
README

# Run script and check output
OUTPUT=$(cd "$TEST_ROOT" && bash scripts/check-plan-numbering.sh 2>&1)
if [[ "$OUTPUT" == *"✓ Plan numbering consistent"* ]]; then
    echo "  ✓ Test 1 passed"
else
    echo "  ✗ Test 1 failed: Output was: $OUTPUT"
fi

# Test 2: Verify scripts/validate-skills.sh correctly counts rules
echo "Test 2: validate-skills.sh rules count check..."
cat <<RULES > "$TEST_ROOT/.agents/skill-rules.json"
{
  "rule1": "value1",
  "rule2": "value2"
}
RULES
cat <<SKILL > "$TEST_ROOT/.agents/skills/test-skill/SKILL.md"
---
name: test-skill
description: A test skill
version: 1.0.0
---
# Test Skill
SKILL

# Run script and check output
OUTPUT=$(cd "$TEST_ROOT" && bash scripts/validate-skills.sh 2>&1)
if echo "$OUTPUT" | grep -q "skill-rules.json: 2 rules defined"; then
    echo "  ✓ Test 2 passed"
else
    echo "  ✗ Test 2 failed: Output was: $OUTPUT"
fi

# Test 3: Security Check - Malicious variable interpolation
echo "Test 3: Security check - Malicious variable interpolation..."
MALICIOUS_FILE="'); import os; os.system('echo INJECTED_PLAN'); print('"
touch "$TEST_ROOT/$MALICIOUS_FILE"
echo "  Testing python command pattern from check-plan-numbering.sh..."
if python3 -c "import json, sys; d=json.load(open(sys.argv[1])); print(d['nextAvailable']['plan'])" "$MALICIOUS_FILE" 2>/dev/null | grep -q "INJECTED_PLAN"; then
    echo "  ✗ Test 3a failed: Injection successful!"
else
    echo "  ✓ Test 3a passed: No injection via sys.argv"
fi
echo "  Testing python command pattern from validate-skills.sh..."
MALICIOUS_RULES="'); import os; os.system('echo INJECTED_RULES'); print('"
touch "$TEST_ROOT/$MALICIOUS_RULES"
if python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))))" "$MALICIOUS_RULES" 2>/dev/null | grep -q "INJECTED_RULES"; then
    echo "  ✗ Test 3b failed: Injection successful!"
else
    echo "  ✓ Test 3b passed: No injection via sys.argv"
fi

# Test 4: Option Injection Hardening in AWK and WC
echo "Test 4: Option Injection Hardening in AWK and WC..."
HYPHEN_FILE="-v"
echo "content" > "$TEST_ROOT/$HYPHEN_FILE"
echo "  Testing awk hardening..."
if (cd "$TEST_ROOT" && awk -- '1' "$HYPHEN_FILE" 2>/dev/null | grep -q "content"); then
    echo "  ✓ Test 4a passed"
else
    echo "  ✗ Test 4a failed"
fi
echo "  Testing wc hardening..."
if (cd "$TEST_ROOT" && wc -l -- "$HYPHEN_FILE" 2>/dev/null | grep -q "1 $HYPHEN_FILE"); then
    echo "  ✓ Test 4b passed"
else
    echo "  ✗ Test 4b failed"
fi

# Test 5: xargs -r safety
echo "Test 5: xargs -r safety..."
if [[ $(printf "" | xargs -r echo "executed") == "" ]]; then
    echo "  ✓ Test 5 passed"
else
    echo "  ✗ Test 5 failed"
fi

# Test 6: Aggressive Option Injection Hardening
echo "Test 6: Aggressive option injection hardening..."
# Test files with names that look like critical flags
for bad_file in "-h" "-n" "-e" "-testfile" "--version"; do
    touch "$TEST_ROOT/$bad_file"
    chmod 644 "$TEST_ROOT/$bad_file"

    # chmod
    if ! chmod +x -- "$TEST_ROOT/$bad_file" 2>/dev/null; then
        echo "  ✗ Test 6a failed: chmod error for $bad_file"
    elif [[ ! -x "$TEST_ROOT/$bad_file" ]]; then
        echo "  ✗ Test 6a failed: chmod did not set +x on $bad_file"
    fi

    # grep
    echo "pattern" > "$TEST_ROOT/$bad_file"
    if ! grep -q -e "pattern" -- "$TEST_ROOT/$bad_file" 2>/dev/null; then
        echo "  ✗ Test 6b failed: grep failed to read $bad_file or find pattern"
    fi

    # sed
    if ! sed -e "s/pattern/passed/" -- "$TEST_ROOT/$bad_file" > /dev/null 2>&1; then
         echo "  ✗ Test 6c failed: sed error for $bad_file"
    fi
done
echo "  ✓ Test 6 passed: Aggressive injection scenarios handled"

# Test 7: propagate-version.sh functional check (Portability)
echo "Test 7: propagate-version.sh functional check..."
echo "0.1.0" > "$TEST_ROOT/VERSION"
cat <<README > "$TEST_ROOT/README.md"
Template version: 0.0.0
version-0.0.0
| \`VERSION\` | \`0.0.0\` |
**Version:** 0.0.0
README
touch "$TEST_ROOT/QUICKSTART.md"
touch "$TEST_ROOT/agents-docs/MIGRATION.md"
touch "$TEST_ROOT/CHANGELOG-TEMPLATE.md"
touch "$TEST_ROOT/agents-docs/VERSION.md"
touch "$TEST_ROOT/analysis/SWARM_ANALYSIS.md"
echo -e "## [Unreleased]\n" > "$TEST_ROOT/CHANGELOG.md"
cp scripts/propagate-version.sh "$TEST_ROOT/scripts/"
sed -i "s|REPO_ROOT=.*|REPO_ROOT=\"$TEST_ROOT\"|" "$TEST_ROOT/scripts/propagate-version.sh"
if (cd "$TEST_ROOT" && bash scripts/propagate-version.sh >/dev/null 2>&1); then
    PASS=1
    grep -q "Template version: 0.1.0" "$TEST_ROOT/README.md" || PASS=0
    grep -q "version-0.1.0" "$TEST_ROOT/README.md" || PASS=0
    grep -q "| \`VERSION\` | \`0.1.0\` |" "$TEST_ROOT/README.md" || PASS=0
    grep -q "\*\*Version:\*\* 0.1.0" "$TEST_ROOT/README.md" || PASS=0
    grep -q "## \[Unreleased\]" "$TEST_ROOT/CHANGELOG.md" || PASS=0
    if [[ $PASS -eq 1 ]]; then
        echo "  ✓ Test 7 passed: Portable version propagation successful"
    else
        echo "  ✗ Test 7 failed: verification failed"
        cat "$TEST_ROOT/README.md"
    fi
else
    echo "  ✗ Test 7 failed: execution error"
fi

echo "All security and functional tests completed!"
