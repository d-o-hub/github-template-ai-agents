#!/usr/bin/env bash
# Git pre-commit hook.
# Install: cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
set -euo pipefail

# Validate git hooks configuration (prevent global hooks from overriding local)
if [ "${SKIP_GLOBAL_HOOKS_CHECK:-false}" != "true" ]; then
    if ! ./scripts/validate-git-hooks.sh; then
        echo ""
        echo "Commit aborted. Fix the hooks configuration or use SKIP_GLOBAL_HOOKS_CHECK=true to skip."
        exit 1
    fi
fi

echo "Running pre-commit checks..."
./scripts/quality_gate.sh

echo "Pre-commit checks passed."