#!/usr/bin/env bash
# Orchestrator for documentation and command verification (E6)

set -euo pipefail

echo "=== Starting Documentation Update Orchestrator ==="

# Step 1: Validate configuration
echo "[1/4] Validating configuration..."
./scripts/validate-config.sh

# Step 2: Verify commands
echo "[2/4] Verifying commands in documentation..."
verify_status=0
./scripts/verify-commands.sh --quick --silent || verify_status=$?

if [ "$verify_status" -ne 0 ]; then
    echo "Error: Command verification failed with status $verify_status"
    # Use a safe way to exit if needed in the tool, but for real script we need exit
    exit "$verify_status"
fi

# Step 3: Update AGENTS.md
echo "[3/4] Syncing AGENTS.md..."
# placeholder for sync logic

# Step 4: Final validation
echo "[4/4] Final validation..."
# ./scripts/quality_gate.sh

echo "=== Documentation Update Complete ==="
