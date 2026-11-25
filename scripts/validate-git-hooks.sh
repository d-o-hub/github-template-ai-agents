#!/usr/bin/env bash
# Validate git hooks configuration: report global hooks, then report a configured
# core.hooksPath that resolves somewhere other than the hooks this repository ships.
# Exit 0 = usable or unset configuration (warning issued), Exit 1 = repository hooks bypassed.

set -euo pipefail

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    RED=''
    YELLOW=''
    GREEN=''
    NC=''
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# absolute_path - canonicalise a path, printing nothing when the directory is missing.
# Always called through a command substitution so the cd cannot leak into the caller.
absolute_path() {
    cd -- "$1" 2>/dev/null && pwd -P || true
}

# Check for global hooks path configuration
GLOBAL_HOOKS_PATH=$(git config --global core.hooksPath 2>/dev/null || true)
CONFIGURED_HOOKS_PATH=$(git config --get core.hooksPath 2>/dev/null || true)

# Resolve the hooks directory git would actually use, so a relative and an absolute
# core.hooksPath that point at the same place produce the same verdict. Computed before
# the global check because its remediation text is reused there.
EFFECTIVE_HOOKS_DIR=$(git rev-parse --git-path hooks 2>/dev/null || true)
EFFECTIVE_HOOKS_ABS=$(absolute_path "$EFFECTIVE_HOOKS_DIR")
GITHOOKS_ABS=$(absolute_path "$REPO_ROOT/.githooks")
GITDIR_HOOKS_ABS=$(absolute_path "$(git rev-parse --git-dir 2>/dev/null || true)/hooks")

if [[ -n "$GITHOOKS_ABS" ]]; then
    EXPECTED_HOOKS_ABS="$GITHOOKS_ABS"
    INSTALL_HINT="git config --local core.hooksPath .githooks"
    CONSEQUENCE="The tracked hooks in .githooks/ are not running, so the local quality gate
and the commit message checks are both inactive."
else
    EXPECTED_HOOKS_ABS="$GITDIR_HOOKS_ABS"
    INSTALL_HINT="git config --local core.hooksPath .git/hooks"
    CONSEQUENCE="This checkout has no .githooks/ directory, so core.hooksPath should resolve
back to the hooks directory inside .git/."
fi

if [[ -n "$GLOBAL_HOOKS_PATH" ]]; then
    printf "%b\n" "${YELLOW}⚠ WARNING: Global git hooks path is set${NC}"
    printf "   Global hooks path: ${YELLOW}%s${NC}\n" "$GLOBAL_HOOKS_PATH"
    echo ""
    echo "This can prevent local pre-commit hooks from running."
    echo ""
    echo "To fix this, choose one option:"
    echo ""
    echo "  Option 1 - Remove global hooks (recommended for this repo):"
    echo "    git config --global --unset core.hooksPath"
    echo ""
    echo "  Option 2 - Override the global path in this repository only:"
    echo "    $INSTALL_HINT"
    echo ""
    echo "  Option 3 - Skip this check (not recommended):"
    echo "    SKIP_GLOBAL_HOOKS_CHECK=true git commit ..."
    echo ""
    exit 0
fi

if [[ -z "$CONFIGURED_HOOKS_PATH" ]]; then
    # An un-bootstrapped checkout is a setup gap, not a misconfiguration: warn, but
    # keep the gate green for fresh clones and CI jobs that never install hooks.
    printf "%b\n" "${YELLOW}⚠ WARNING: no core.hooksPath configured${NC}"
    printf "   Hooks directory: %s\n" "${EFFECTIVE_HOOKS_DIR}"
    echo ""
    echo "Commit-time checks will not run. Install them with one option:"
    echo ""
    OPTION=1
    if [[ -n "$GITHOOKS_ABS" ]]; then
        echo "  Option $((OPTION++)) - Full setup (recommended):"
        echo "    ./scripts/bootstrap.sh"
        echo ""
        echo "  Option $((OPTION++)) - Hooks only:"
    else
        echo "  Option $((OPTION++)) - Track the git default hooks directory:"
    fi
    echo "    $INSTALL_HINT"
    echo ""
    exit 0
fi

if [[ "$EFFECTIVE_HOOKS_ABS" != "$EXPECTED_HOOKS_ABS" ]]; then
    printf "%b\n" "${RED}✗ ERROR: Configured hooks path bypasses the expected hooks directory!${NC}"
    printf "   Configured as:    ${YELLOW}%s${NC}\n" "$CONFIGURED_HOOKS_PATH"
    printf "   Resolves to:      ${YELLOW}%s${NC}\n" "${EFFECTIVE_HOOKS_ABS:-<missing directory>}"
    printf "   Expected:         ${GREEN}%s${NC}\n" "$EXPECTED_HOOKS_ABS"
    echo ""
    printf '%s\n' "$CONSEQUENCE"
    echo ""
    echo "To fix this, choose one option:"
    echo ""
    OPTION=1
    if [[ -n "$GITHOOKS_ABS" ]]; then
        echo "  Option $((OPTION++)) - Point git at the repository hooks (recommended):"
        echo "    $INSTALL_HINT"
        echo ""
    fi
    echo "  Option $((OPTION++)) - Drop the override and use the git defaults:"
    echo "    git config --local --unset core.hooksPath"
    echo ""
    echo "  Option $OPTION - Skip this check (not recommended):"
    echo "    SKIP_GLOBAL_HOOKS_CHECK=true git commit ..."
    echo ""
    exit 1
fi

printf "%b\n" "${GREEN}✓ Git hooks configuration validated${NC}"
if [[ -n "$GITHOOKS_ABS" ]] && [[ -z "$(find "$GITHOOKS_ABS" -maxdepth 1 -type f -perm -u+x -print -quit)" ]]; then
    printf "%b\n" "${YELLOW}⚠ WARNING: no executable hook found in .githooks/${NC}"
fi
exit 0
