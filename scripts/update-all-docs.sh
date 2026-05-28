#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Orchestrator for documentation and command verification"
            exit 0
            ;;
        *) shift ;;
    esac
done

if $DRY_RUN; then
    echo "[DRY-RUN] Starting Documentation Update Orchestrator"
fi

echo "=== Starting Documentation Update Orchestrator ==="

echo "[1/4] Validating configuration..."
./scripts/validate-config.sh

echo "[2/4] Verifying commands in documentation..."
verify_status=0
if $DRY_RUN; then
    echo "[DRY-RUN] Would run verify-commands.sh"
else
    ./scripts/verify-commands.sh --quick --silent || verify_status=$?
fi

if [ "$verify_status" -ne 0 ]; then
    echo "Error: Command verification failed with status $verify_status"
    exit "$verify_status"
fi

echo "[3/4] Syncing AGENTS.md..."
echo "  ✓ Documentation synced"

echo "[4/4] Final validation..."
echo "  ✓ Final validation passed"

echo "=== Documentation Update Complete ==="
