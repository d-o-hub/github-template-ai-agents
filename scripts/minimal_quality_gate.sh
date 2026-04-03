#!/bin/bash
# Minimal test script for CI debugging

set +e
set -uo pipefail

echo "Starting minimal quality gate..."

# Test 1: Validate skills
./scripts/validate-skills.sh
result=$?
echo "validate-skills.sh exit code: $result"

if [ $result -ne 0 ]; then
    echo "ERROR: validate-skills.sh failed"
    exit 2
fi

# Test 2: Check some files exist
if [ ! -d ".agents/skills" ]; then
    echo "ERROR: .agents/skills not found"
    exit 2
fi

echo "Minimal quality gate PASSED"
exit 0
