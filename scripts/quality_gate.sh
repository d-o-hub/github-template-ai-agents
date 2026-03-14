#!/usr/bin/env bash
# Full quality gate. Runs all checks. Exit 2 = surface errors to agent.
# TODO: Uncomment and adapt the block(s) for your tech stack.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."; pwd)"
cd "$REPO_ROOT"

FAILED=0

# --- Always: validate skill symlinks ---
if ! ./scripts/validate-skills.sh; then
  FAILED=1
fi

# --- Rust ---
# if [ -f Cargo.toml ]; then
#   OUTPUT=$(cargo fmt --check 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
#   OUTPUT=$(cargo clippy -- -D warnings 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
#   OUTPUT=$(cargo test 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
# fi

# --- TypeScript / Node ---
# if [ -f package.json ]; then
#   OUTPUT=$(pnpm lint 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
#   OUTPUT=$(pnpm typecheck 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
#   OUTPUT=$(pnpm test 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
# fi

# --- Python ---
# if [ -f requirements.txt ] || [ -f pyproject.toml ]; then
#   OUTPUT=$(ruff check . 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
#   OUTPUT=$(black --check . 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
#   OUTPUT=$(pytest tests/ -q 2>&1) || { echo "$OUTPUT" >&2; FAILED=1; }
# fi

if [ $FAILED -ne 0 ]; then
  exit 2
fi

echo "Quality gate passed."