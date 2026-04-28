#!/usr/bin/env bash
set -euo pipefail

# Provider verification — language-agnostic via pact-verifier CLI
# Reads pacts from contracts/pacts/, verifies against running provider

# Add path to find pact_verifier_cli if it's installed via cargo
export PATH="$HOME/.cargo/bin:$PATH"

PROVIDER_URL="${PROVIDER_URL:-http://localhost:8080}"
STATE_CHANGE_URL="${STATE_CHANGE_URL:-$PROVIDER_URL/_pact/provider_states}"
PACT_DIR="contracts/pacts"

if ! command -v pact_verifier_cli &> /dev/null; then
  echo "pact_verifier_cli not found. Install: cargo install pact_verifier_cli"
  echo "Or download from: https://github.com/pact-foundation/pact-reference/releases"
  exit 1
fi

if [ ! -d "$PACT_DIR" ]; then
  echo "Pact directory $PACT_DIR not found."
  exit 0
fi

# Use find -print0 for safe file iteration
while IFS= read -r -d '' pact; do
  echo "--- Verifying $pact against $PROVIDER_URL ---"
  pact_verifier_cli \
    --file "$pact" \
    --provider-base-url "$PROVIDER_URL" \
    --state-change-url "$STATE_CHANGE_URL" \
    --loglevel info
done < <(find "$PACT_DIR" -name "*.json" -print0)
