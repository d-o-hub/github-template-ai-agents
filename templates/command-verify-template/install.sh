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

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Command Verification Template Install ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Validate target directory
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}✗ Target directory does not exist: $TARGET_DIR${NC}"
    exit 1
fi

cd "$TARGET_DIR"

# Check if this is a git repository (recommended but not required)
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}⚠ Warning: Not a git repository${NC}"
    echo "  Some features (git diff caching) will be limited."
    echo "  Consider running 'git init' first."
    echo ""
fi

echo "Installing to: $(pwd)"
echo ""

# Create directories
echo -e "${BLUE}Step 1/6: Creating directories...${NC}"
mkdir -p scripts/lib
mkdir -p .cache/command-validations/commands
mkdir -p .agents/commands
echo -e "${GREEN}  ✓ Directories created${NC}"
echo ""

# Copy main scripts
echo -e "${BLUE}Step 2/6: Installing scripts...${NC}"
if [ -d "$TEMPLATE_DIR/scripts" ]; then
    cp "$TEMPLATE_DIR/scripts/"*.sh scripts/ 2>/dev/null || true
    echo -e "${GREEN}  ✓ Main scripts copied${NC}"
else
    echo -e "${YELLOW}  ⚠ No scripts found in template (will create stubs)${NC}"
fi

# Copy library scripts
echo -e "${BLUE}Step 3/6: Installing libraries...${NC}"
if [ -d "$TEMPLATE_DIR/scripts/lib" ] && [ "$(ls -A "$TEMPLATE_DIR/scripts/lib" 2>/dev/null)" ]; then
    cp "$TEMPLATE_DIR/scripts/lib/"*.sh scripts/lib/
    echo -e "${GREEN}  ✓ Library scripts copied${NC}"
else
    echo -e "${YELLOW}  ⚠ No library scripts found (will create stubs)${NC}"
fi

# Copy slash command
echo -e "${BLUE}Step 4/6: Installing Agents commands...${NC}"
if [ -f "$TEMPLATE_DIR/.agents/commands/verify-commands.md" ]; then
    cp "$TEMPLATE_DIR/.agents/commands/"*.md .agents/commands/
    echo -e "${GREEN}  ✓ Slash command installed${NC}"
else
    echo -e "${YELLOW}  ⚠ No slash command found in template${NC}"
fi

# Copy configuration template
echo -e "${BLUE}Step 5/6: Setting up configuration...${NC}"
if [ -f "$TEMPLATE_DIR/.command-verify.conf.example" ]; then
    if [ ! -f ".command-verify.conf" ]; then
        cp "$TEMPLATE_DIR/.command-verify.conf.example" .command-verify.conf
        echo -e "${GREEN}  ✓ Configuration file created${NC}"
    else
        echo -e "${YELLOW}  ⚠ .command-verify.conf already exists (skipped)${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ No config template found (using defaults)${NC}"
fi

# Make scripts executable
echo -e "${BLUE}Step 6/6: Setting permissions...${NC}"
chmod +x scripts/*.sh 2>/dev/null || true
chmod +x scripts/lib/*.sh 2>/dev/null || true
echo -e "${GREEN}  ✓ Scripts made executable${NC}"
echo ""

# Create stub files if needed
if [ ! -f "scripts/discover-commands.sh" ]; then
    echo -e "${BLUE}Creating stub script: discover-commands.sh...${NC}"
    cat > scripts/discover-commands.sh << 'STUB'
#!/usr/bin/env bash
# TODO: Implement command discovery
# See templates/command-verify-template for full implementation
echo "Command discovery not yet implemented"
exit 0
STUB
    chmod +x scripts/discover-commands.sh
fi

if [ ! -f "scripts/verify-commands.sh" ]; then
    echo -e "${BLUE}Creating stub script: verify-commands.sh...${NC}"
    cat > scripts/verify-commands.sh << 'STUB'
#!/usr/bin/env bash
# TODO: Implement command verification
# See templates/command-verify-template for full implementation
echo "Command verification not yet implemented"
exit 0
STUB
    chmod +x scripts/verify-commands.sh
fi

# Integration check
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Installation Complete!          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Installed components:${NC}"
echo "  📁 scripts/discover-commands.sh"
echo "  📁 scripts/verify-commands.sh"
echo "  📁 scripts/lib/ (libraries)"
echo "  📁 .agents/commands/verify-commands.md"
echo "  📁 .cache/command-validations/"
if [ -f ".command-verify.conf" ]; then
    echo "  ⚙️  .command-verify.conf"
fi
echo ""

# Next steps
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "1. ${GREEN}Test the installation:${NC}"
echo "   ./scripts/verify-commands.sh"
echo ""
echo "2. ${GREEN}Customize configuration:${NC}"
echo "   Edit .command-verify.conf to match your project"
echo ""
echo "3. ${GREEN}(Optional) Integrate with pre-commit:${NC}"
if [ -f "scripts/pre-commit-hook.sh" ]; then
    echo "   Add this line to scripts/pre-commit-hook.sh:"
    echo -e "   ${YELLOW}./scripts/verify-commands.sh --quick --silent || true${NC}"
else
    echo "   Create scripts/pre-commit-hook.sh and add:"
    echo -e "   ${YELLOW}./scripts/verify-commands.sh --quick --silent || true${NC}"
fi
echo ""
echo "4. ${GREEN}(Optional) Add to CI/CD:${NC}"
echo "   Add './scripts/verify-commands.sh --stats' to your pipeline"
echo ""

# Pre-commit integration offer
if [ -f "scripts/pre-commit-hook.sh" ]; then
    echo -e "${YELLOW}⚠ Pre-commit hook detected${NC}"
    echo "  Would you like to integrate command verification? (y/n)"
    read -r response || true
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if ! grep -q "verify-commands" scripts/pre-commit-hook.sh; then
            echo "" >> scripts/pre-commit-hook.sh
            echo "# Command verification" >> scripts/pre-commit-hook.sh
            echo "./scripts/verify-commands.sh --quick --silent || true" >> scripts/pre-commit-hook.sh
            echo -e "${GREEN}  ✓ Integrated with pre-commit hook${NC}"
        else
            echo -e "${YELLOW}  ⚠ Already integrated${NC}"
        fi
    fi
fi

echo ""
echo -e "${GREEN}Happy verifying! 🎉${NC}"
