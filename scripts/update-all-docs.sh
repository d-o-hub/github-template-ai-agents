#!/usr/bin/env bash
# Auto-update all documentation by verifying commands and syncing content
# Integrates with existing update-agents-md.sh and docs-sync.sh
# Usage: ./scripts/update-all-docs.sh [--dry-run|--verbose]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Parse arguments
DRY_RUN=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n) DRY_RUN=true; shift ;;
        --verbose|-v) VERBOSE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--dry-run|--verbose]"
            echo ""
            echo "Auto-update all documentation by verifying commands and syncing content."
            echo ""
            echo "Options:"
            echo "  --dry-run, -n    Show what would be done without making changes"
            echo "  --verbose, -v    Show detailed output"
            echo "  --help, -h       Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Colors for output
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

log_step() {
    if ! $DRY_RUN; then
        echo -e "${BLUE}$1${NC}"
    else
        echo -e "${YELLOW}[DRY-RUN] $1${NC}"
    fi
}

log_success() {
    if ! $DRY_RUN; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${GREEN}[DRY-RUN] ✓ $1${NC}"
    fi
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Documentation Auto-Update Runner     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

FAILED_STEPS=0
SUCCESSFUL_STEPS=0

# Step 1: Verify all commands
log_step "Step 1/4: Verifying commands in documentation..."
if [ -x "./scripts/verify-commands.sh" ]; then
    if $DRY_RUN; then
        log_success "Would run: ./scripts/verify-commands.sh --silent"
    else
        if $VERBOSE; then
            if ./scripts/verify-commands.sh; then
                log_success "Command verification passed"
                ((SUCCESSFUL_STEPS++))
            else
                log_warning "Command verification found issues (non-fatal)"
                ((FAILED_STEPS++))
            fi
        else
            if ./scripts/verify-commands.sh --silent; then
                log_success "Command verification passed"
                ((SUCCESSFUL_STEPS++))
            else
                log_warning "Command verification found issues (non-fatal)"
                ((FAILED_STEPS++))
            fi
        fi
    fi
else
    log_warning "verify-commands.sh not found - skipping"
fi
echo ""

# Step 2: Update AGENTS.md
log_step "Step 2/4: Updating AGENTS.md..."
if [ -x "./scripts/update-agents-md.sh" ]; then
    if $DRY_RUN; then
        log_success "Would run: ./scripts/update-agents-md.sh"
    else
        if OUTPUT=$(./scripts/update-agents-md.sh 2>&1); then
            log_success "AGENTS.md updated successfully"
            ((SUCCESSFUL_STEPS++))
            if $VERBOSE; then
                echo "$OUTPUT"
            fi
        else
            log_warning "AGENTS.md update failed (non-fatal)"
            echo "$OUTPUT" >&2
            ((FAILED_STEPS++))
        fi
    fi
else
    log_warning "update-agents-md.sh not found - skipping"
fi
echo ""

# Step 3: Sync documentation
log_step "Step 3/4: Syncing documentation..."
if [ -x "./scripts/docs-sync.sh" ]; then
    if $DRY_RUN; then
        log_success "Would run: ./scripts/docs-sync.sh"
    else
        if OUTPUT=$(./scripts/docs-sync.sh 2>&1); then
            log_success "Documentation synced successfully"
            ((SUCCESSFUL_STEPS++))
            if $VERBOSE; then
                echo "$OUTPUT"
            fi
        else
            log_warning "Documentation sync failed (non-fatal)"
            echo "$OUTPUT" >&2
            ((FAILED_STEPS++))
        fi
    fi
else
    log_warning "docs-sync.sh not found - skipping"
fi
echo ""

# Step 4: Validate links
log_step "Step 4/4: Validating internal links..."
if [ -x "./scripts/validate-links.sh" ]; then
    if $DRY_RUN; then
        log_success "Would run: ./scripts/validate-links.sh --silent"
    else
        if $VERBOSE; then
            if ./scripts/validate-links.sh; then
                log_success "Link validation passed"
                ((SUCCESSFUL_STEPS++))
            else
                log_warning "Link validation found issues (non-fatal)"
                ((FAILED_STEPS++))
            fi
        else
            if ./scripts/validate-links.sh --silent; then
                log_success "Link validation passed"
                ((SUCCESSFUL_STEPS++))
            else
                log_warning "Link validation found issues (non-fatal)"
                ((FAILED_STEPS++))
            fi
        fi
    fi
else
    log_warning "validate-links.sh not found - skipping"
fi
echo ""

# Summary
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}Summary:${NC}"
echo "  Successful steps: $SUCCESSFUL_STEPS"
echo "  Failed steps:     $FAILED_STEPS"
echo ""

if [ $FAILED_STEPS -eq 0 ]; then
    echo -e "${GREEN}✅ Documentation auto-update complete!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Documentation auto-update completed with warnings${NC}"
    echo ""
    echo "Review the warnings above. Some documentation may need manual updates."
    exit 0  # Non-fatal, always exit 0
fi
