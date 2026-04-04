#!/usr/bin/env bash
# Git pre-commit hook.
# Install: cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
set -euo pipefail

# Get repository root for portable paths
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source lint-cache library
# shellcheck source=scripts/lib/lint_cache.sh
if [ -f "$REPO_ROOT/scripts/lib/lint_cache.sh" ]; then
    # shellcheck source=scripts/lib/lint_cache.sh
    source "$REPO_ROOT/scripts/lib/lint_cache.sh"
fi

# Validate git hooks configuration (prevent global hooks from overriding local)
if [ "${SKIP_GLOBAL_HOOKS_CHECK:-false}" != "true" ]; then
    if ! "$REPO_ROOT/scripts/validate-git-hooks.sh"; then
        echo ""
        echo "Commit aborted. Fix the hooks configuration or use SKIP_GLOBAL_HOOKS_CHECK=true to skip."
        exit 1
    fi
fi

echo "Running pre-commit checks..."
"$REPO_ROOT/scripts/quality_gate.sh"

echo "Pre-commit checks passed."