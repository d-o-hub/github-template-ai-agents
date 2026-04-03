#!/bin/bash
# Minimal quality gate for CI - runs actual checks

set -euo pipefail

echo "Starting minimal quality gate..."

# Test 1: Validate skills structure
./scripts/validate-skills.sh
result=$?
if [ $result -ne 0 ]; then
    echo "ERROR: validate-skills.sh failed"
    exit 2
fi

# Test 2: Validate skill format
./scripts/validate-skill-format.sh
result=$?
if [ $result -ne 0 ]; then
    echo "ERROR: validate-skill-format.sh failed"
    exit 2
fi

# Test 3: Check some critical files exist
if [ ! -d ".agents/skills" ]; then
    echo "ERROR: .agents/skills not found"
    exit 2
fi

# Test 4: Run shellcheck on key scripts
if command -v shellcheck >/dev/null 2>&1; then
    echo "Running shellcheck..."
    shellcheck scripts/setup-skills.sh scripts/validate-skills.sh || {
        echo "WARNING: shellcheck found issues in key scripts"
    }
else
    echo "WARNING: shellcheck not installed, skipping"
fi

# Test 5: Run markdownlint on key docs
if command -v markdownlint >/dev/null 2>&1; then
    echo "Running markdownlint..."
    markdownlint AGENTS.md README.md || {
        echo "WARNING: markdownlint found issues"
    }
else
    echo "WARNING: markdownlint not installed, skipping"
fi

# Test 6: Verify all skills have SKILL.md
errors=0
for skill_dir in .agents/skills/*/; do
    if [ -d "$skill_dir" ] && [ ! -f "${skill_dir}SKILL.md" ]; then
        echo "ERROR: Missing SKILL.md in $skill_dir"
        errors=$((errors + 1))
    fi
done

if [ $errors -gt 0 ]; then
    echo "ERROR: $errors skills missing SKILL.md"
    exit 2
fi

echo "Minimal quality gate PASSED"
exit 0
