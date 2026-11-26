#!/usr/bin/env bats
# Regression net for scripts/lib/research-engine.sh.
#
# resolve_with_optimization used to call `-m scripts.resolve` (a library module
# with no main()) and pass --trace/--validate-links/--check-completeness, which
# the resolver CLI never declared. argparse exited 2, the `||` fallback swallowed
# it, and every query was recorded as "Resolution failed". The stub CLI below
# derives its accepted flags from the real cli.py, so the same drift fails here.

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    LIB="$REPO_ROOT/scripts/lib/research-engine.sh"
    CLI_PY="$REPO_ROOT/tools/web-doc-resolver/scripts/cli.py"
    STUB_DIR="$BATS_TEST_TMPDIR/resolver"
    ARGV_LOG="$BATS_TEST_TMPDIR/argv.log"
    OUT_FILE="$BATS_TEST_TMPDIR/out.json"

    # Flags the shipped CLI declares via argparse; the stub rejects anything else
    # the way argparse does. Scanned as plain tokens because add_argument() calls
    # in cli.py wrap across lines.
    STUB_SUPPORTED="$(
        grep -oE '\-\-[a-z][a-z-]*' "$CLI_PY" | sort -u | paste -sd ' ' -
    )"
    export STUB_SUPPORTED ARGV_LOG STUB_STATE

    mkdir -p "$STUB_DIR/scripts"
    : >"$STUB_DIR/scripts/__init__.py"
    cat >"$STUB_DIR/scripts/cli.py" <<'PY'
import json
import os
import sys

argv = sys.argv[1:]
supported = set(os.environ["STUB_SUPPORTED"].split())
with open(os.environ["ARGV_LOG"], "w", encoding="utf-8") as handle:
    handle.write("\n".join(argv))

positional = []
index = 0
while index < len(argv):
    token = argv[index]
    if token == "--":
        positional.extend(argv[index + 1:])
        break
    if not token.startswith("-"):
        positional.append(token)
        index += 1
        continue
    if token not in supported:
        print(f"error: unrecognized arguments: {token}", file=sys.stderr)
        sys.exit(2)
    index += 1
    if index < len(argv) and not argv[index].startswith("-") and argv[index] != "--":
        index += 1

if os.environ.get("STUB_STATE") == "fail":
    sys.exit(1)

print(json.dumps({"source": "stub", "content": "resolved", "score": 0.9}))
PY

    source "$LIB"
}

@test "resolves through the CLI entrypoint instead of the library module" {
    run resolve_with_optimization "what is bats" "$OUT_FILE" general "$STUB_DIR"
    [ "$status" -eq 0 ]
    run cat "$OUT_FILE"
    [[ "$output" == *'"source": "stub"'* ]]
    [[ "$output" != *"Resolution failed"* ]]
}

@test "passes only flags declared by the resolver CLI" {
    resolve_with_optimization "what is bats" "$OUT_FILE" general "$STUB_DIR" || true
    run cat "$ARGV_LOG"
    [[ "$output" == *"--profile"* ]]
    [[ "$output" == *"--max-chars"* ]]
    [[ "$output" == *"--json"* ]]
    [[ "$output" != *"--trace"* ]]
    [[ "$output" != *"--validate"* ]]
}

@test "context labels the record without inventing CLI flags" {
    run resolve_with_optimization "api example" "$OUT_FILE" api-docs "$STUB_DIR"
    [ "$status" -eq 0 ]
    run cat "$OUT_FILE"
    [[ "$output" == *'"context": "api-docs"'* ]]
    [[ "$output" == *'"source": "stub"'* ]]
}

@test "keeps the fallback for a genuinely failing resolver" {
    STUB_STATE=fail
    export STUB_STATE
    run resolve_with_optimization "boom" "$OUT_FILE" general "$STUB_DIR"
    [ "$status" -eq 1 ]
    run cat "$OUT_FILE"
    [[ "$output" == *"Resolution failed"* ]]
}
