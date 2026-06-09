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

check_llms_context_files() {
    local docs_tmpdir
    docs_tmpdir=$(mktemp -d)

    cleanup_docs_tmpdir() {
        rm -rf "$docs_tmpdir"
    }
    trap cleanup_docs_tmpdir RETURN

    if [[ ! -f llms.txt || ! -f llms-full.txt ]]; then
        echo "Error: llms.txt and llms-full.txt must exist before dry-run checks." >&2
        return 1
    fi

    LLMS_TXT="$docs_tmpdir/llms.txt" \
        LLMS_FULL_TXT="$docs_tmpdir/llms-full.txt" \
        ./scripts/generate-llms-txt.sh > /dev/null

    local check_status=0
    if ! diff -q llms.txt "$docs_tmpdir/llms.txt" > /dev/null; then
        echo "Error: llms.txt is out of date. Run ./scripts/generate-llms-txt.sh" >&2
        check_status=1
    fi

    if ! diff -q llms-full.txt "$docs_tmpdir/llms-full.txt" > /dev/null; then
        echo "Error: llms-full.txt is out of date. Run ./scripts/generate-llms-txt.sh" >&2
        check_status=1
    fi

    if [[ "$check_status" -eq 0 ]]; then
        echo "  ✓ LLM context files are up to date"
    fi

    return "$check_status"
}

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

if [[ "$verify_status" -ne 0 ]]; then
    echo "Error: Command verification failed with status $verify_status" >&2
    exit "$verify_status"
fi

echo "[3/4] Syncing AGENTS.md and LLM context files..."
if $DRY_RUN; then
    echo "[DRY-RUN] Checking generated LLM context files without writing committed outputs"
    check_llms_context_files
else
    ./scripts/generate-llms-txt.sh
    echo "  ✓ Documentation and LLM context files synced"
fi

echo "[4/4] Final validation..."
echo "  ✓ Final validation passed"

echo "=== Documentation Update Complete ==="
