#!/usr/bin/env bash
# Minimal test script for CI debugging

set +e
set -uo pipefail

# Get repository root for portable paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Starting minimal quality gate..."

# Test 1: Validate skills
"$REPO_ROOT/scripts/validate-skills.sh"
result=$?
echo "validate-skills.sh exit code: $result"

if [ $result -ne 0 ]; then
    echo "ERROR: validate-skills.sh failed"
    exit 2
fi

# Test 2: Check some files exist
if [ ! -d "$REPO_ROOT/.agents/skills" ]; then
    echo "ERROR: .agents/skills not found"
    exit 2
fi

echo "Minimal quality gate PASSED"
exit 0
