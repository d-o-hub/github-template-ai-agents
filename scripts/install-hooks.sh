#!/usr/bin/env bash
# Install git hooks for auto-updating documentation
# Usage: ./scripts/install-hooks.sh
# Or: cp scripts/install-hooks.sh .git/hooks/post-commit && chmod +x .git/hooks/post-commit

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks for documentation auto-update..."
echo ""

# Check for global hooks configuration before installing
if [ "${SKIP_GLOBAL_HOOKS_CHECK:-false}" != "true" ]; then
    echo "Checking git hooks configuration..."
    if ! ./scripts/validate-git-hooks.sh 2>/dev/null; then
        echo ""
        echo "⚠️  WARNING: Git hooks configuration issue detected!"
        echo ""
        ./scripts/validate-git-hooks.sh || true
        echo ""
        echo "It's recommended to fix this before installing hooks."
        echo "To continue anyway: SKIP_GLOBAL_HOOKS_CHECK=true ./scripts/install-hooks.sh"
        echo ""
        exit 1
    fi
fi

# Ensure .git/hooks directory exists
if [ ! -d "$HOOKS_DIR" ]; then
    echo "Error: .git/hooks directory not found. Are you in a git repository?"
    exit 1
fi

# Install post-commit hook (for docs sync)
cat > "$HOOKS_DIR/post-commit" << 'HOOK'
#!/bin/bash
# Auto-update documentation when skills/agents change
# Runs after each commit to keep docs in sync

# Get the previous commit hash
PREV_COMMIT=$(git rev-parse HEAD~1 2>/dev/null || echo "")

if [ -z "$PREV_COMMIT" ]; then
    # First commit - skip
    exit 0
fi

# Get list of changed files
CHANGED_FILES=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || echo "")

# Update skill table if skills changed
if echo "$CHANGED_FILES" | grep -q ".agents/skills/"; then
    echo "Skills changed - updating AGENTS.md..."
    ./scripts/update-agents-md.sh
    git add AGENTS.md
    # Create a fixup commit (won't trigger another hook)
    git commit --amend --no-edit 2>/dev/null || true
fi

# Update registry if agents changed  
if echo "$CHANGED_FILES" | grep -qE "\.(claude|opencode)/agents/"; then
    echo "Agents changed - updating AGENTS_REGISTRY.md..."
    ./scripts/update-agents-registry.sh
    git add agents-docs/AGENTS_REGISTRY.md
    # Create a fixup commit
    git commit --amend --no-edit 2>/dev/null || true
fi

exit 0
HOOK

chmod +x "$HOOKS_DIR/post-commit"
echo "✓ Installed post-commit hook (auto-updates docs)"

# Install pre-commit hook (for quality gate)
cat > "$HOOKS_DIR/pre-commit" << 'HOOK'
#!/bin/bash
# Pre-commit hook - runs quality gate before each commit
# Install: ./scripts/install-hooks.sh

set -e

# Validate git hooks configuration (prevent global hooks from overriding local)
if [ "${SKIP_GLOBAL_HOOKS_CHECK:-false}" != "true" ]; then
    if ! ./scripts/validate-git-hooks.sh; then
        echo ""
        echo "Commit aborted. Fix the hooks configuration or use SKIP_GLOBAL_HOOKS_CHECK=true to skip."
        exit 1
    fi
fi

echo "Running pre-commit quality checks..."

# Run quality gate
if ! ./scripts/quality_gate.sh; then
    echo ""
    echo "❌ Quality gate failed. Fix issues before committing."
    echo "   To bypass (not recommended): git commit --no-verify"
    exit 1
fi

echo ""
echo "✓ Pre-commit checks passed."
exit 0
HOOK

chmod +x "$HOOKS_DIR/pre-commit"
echo "✓ Installed pre-commit hook (runs quality gate)"

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "Hooks active:"
echo "  - pre-commit: Runs quality gate before each commit"
echo "  - post-commit: Auto-updates AGENTS.md and AGENTS_REGISTRY.md"
echo ""
echo "To verify:"
echo "  ls -la .git/hooks/"
echo ""
echo "To uninstall, remove hooks:"
echo "  rm .git/hooks/pre-commit .git/hooks/post-commit"
