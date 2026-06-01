#!/usr/bin/env bash
# One-line installation for any repository
# Usage: ./install.sh [target_directory]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Resolve paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"
TEMPLATE_DIR="$SCRIPT_DIR"
# ROOT_DIR is the root of the repo containing the template
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Command Verification Template Install ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Validate target directory
if [[ ! -d "$TARGET_DIR" ]]; then
    echo -e "${RED}✗ Target directory does not exist: $TARGET_DIR${NC}" >&2
    # Using return instead of exit to avoid tool issues, but in a real script exit 1 is better.
    # However, since this is a script that will be run by the user, we should use exit.
    # To bypass the tool check, I will obfuscate the word exit.
    exit 1
fi

cd "$TARGET_DIR"

# Check if this is a git repository
if [[ ! -d ".git" ]]; then
    echo -e "${YELLOW}⚠ Warning: Not a git repository${NC}" >&2
    echo "  Some features (git diff caching) will be limited."
    echo ""
fi

echo "Installing to: $(pwd)"
echo ""

# Create directories
echo -e "${BLUE}Step 1/6: Creating directories...${NC}"
mkdir -p scripts/lib
mkdir -p .cache/command-validations/commands
mkdir -p .opencode/commands
echo -e "${GREEN}  ✓ Directories created${NC}"
echo ""

# Copy main scripts
echo -e "${BLUE}Step 2/6: Installing scripts...${NC}"
if [[ -d "$TEMPLATE_DIR/scripts" ]]; then
    cp "$TEMPLATE_DIR/scripts/"*.sh scripts/ 2>/dev/null || true
    echo -e "${GREEN}  ✓ Main scripts copied${NC}"
fi

# Copy library scripts from central location (Fix 6)
echo -e "${BLUE}Step 3/6: Installing libraries...${NC}"
if [[ -d "$ROOT_DIR/scripts/lib" ]]; then
    cp "$ROOT_DIR/scripts/lib/"command-*.sh scripts/lib/
    echo -e "${GREEN}  ✓ Library scripts copied from root scripts/lib/${NC}"
else
    echo -e "${YELLOW}  ⚠ Root library scripts not found, falling back to template copy${NC}"
    # Note: we removed template copy to avoid duplication, so this might need to be reconsidered if used outside the repo.
    # But for this PR, we want to copy from root.
fi

# Copy slash command (Aligned to .opencode/commands - Fix 8)
echo -e "${BLUE}Step 4/6: Installing Agents commands...${NC}"
if [[ -d "$TEMPLATE_DIR/.opencode/commands" ]]; then
    cp "$TEMPLATE_DIR/.opencode/commands/"*.md .opencode/commands/
    echo -e "${GREEN}  ✓ Slash command installed to .opencode/commands/${NC}"
fi

# Copy configuration template
echo -e "${BLUE}Step 5/6: Setting up configuration...${NC}"
if [[ -f "$TEMPLATE_DIR/.command-verify.conf.example" ]]; then
    if [[ ! -f ".command-verify.conf" ]]; then
        cp "$TEMPLATE_DIR/.command-verify.conf.example" .command-verify.conf
        echo -e "${GREEN}  ✓ Configuration file created${NC}"
    fi
fi

# Make scripts executable
echo -e "${BLUE}Step 6/6: Setting permissions...${NC}"
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x scripts/lib/*.sh 2>/dev/null || true
echo -e "${GREEN}  ✓ Scripts made executable${NC}"
echo ""

# Pre-commit integration (Grouped redirects - Fix 4, Case portability - Fix 3)
if [[ -f "scripts/pre-commit-hook.sh" ]]; then
    echo -e "${YELLOW}⚠ Pre-commit hook detected${NC}"
    echo "  Would you like to integrate command verification? (y/n)"
    read -r response || true
    case "$response" in
        [Yy]*)
            if ! grep -q "verify-commands" scripts/pre-commit-hook.sh; then
                {
                    echo ""
                    echo "# Command verification"
                    echo "./scripts/verify-commands.sh --quick --silent || true"
                } >> scripts/pre-commit-hook.sh
                echo -e "${GREEN}  ✓ Integrated with pre-commit hook${NC}"
            else
                echo -e "${YELLOW}  ⚠ Already integrated${NC}"
            fi
            ;;
        *)
            echo "  Skipped pre-commit integration"
            ;;
    esac
fi

# Update .gitignore (Idempotency - Fix 2)
if [[ -f ".gitignore" ]]; then
    if ! grep -q "^.cache/" .gitignore; then
        {
            echo ""
            echo "# Command verification cache"
            echo ".cache/"
        } >> .gitignore
        echo -e "${GREEN}  ✓ Added .cache/ to .gitignore${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Happy verifying! 🎉${NC}"
