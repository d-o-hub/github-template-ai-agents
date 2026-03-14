#!/usr/bin/env bash
# Git pre-commit hook.
# Install: cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
set -euo pipefail

echo "Running pre-commit checks..."
./scripts/quality_gate.sh

echo "Pre-commit checks passed."