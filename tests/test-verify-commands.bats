#!/usr/bin/env bats
# verify-commands.sh must fail when it verified nothing, and must complete when it did.
# Every case runs against a throwaway repository holding a stub discoverer, so the script's
# own exit status is decided by the discovery output rather than by this repo's real commands.

setup_file() {
    SRC_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SRC_ROOT
    BASE=$(mktemp -d)
    export BASE
}

teardown_file() {
    rm -rf "$BASE"
}

# make_repo builds $BASE/<name> as a git repo containing the real script and its libs, plus a
# discoverer that replays $repo/commands.jsonl and honours STUB_DISCOVER_RC. The stub cannot
# reuse the parent's DISCOVER_RC name: the script assigns that variable before invoking the
# discoverer, so an exported value set by the test would be reset to 0 by the time it runs.
make_repo() {
    local repo="$BASE/$1"
    mkdir -p "$repo/scripts/lib"
    cp "$SRC_ROOT/scripts/verify-commands.sh" "$repo/scripts/"
    cp "$SRC_ROOT/scripts/lib/command-cache.sh" "$repo/scripts/lib/"
    cp "$SRC_ROOT/scripts/lib/command-categories.sh" "$repo/scripts/lib/"
    cp "$SRC_ROOT/scripts/lib/command-invalidation.sh" "$repo/scripts/lib/"
    cat > "$repo/scripts/discover-commands.sh" <<'STUB'
#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/commands.jsonl" ]] && cat "$ROOT/commands.jsonl"
exit "${STUB_DISCOVER_RC:-0}"
STUB
    chmod +x "$repo/scripts/discover-commands.sh"
    :> "$repo/commands.jsonl"
    (cd "$repo" && git init -q . && git -c user.email=t@example.test -c user.name=t \
        commit -q --allow-empty -m fixture)
    printf '%s' "$repo"
}

write_discovery() {
    printf '%s\n' "$2" > "$1/commands.jsonl"
}

SAFE_COMMANDS='{"file":"README.md","line":7,"command":"ls -la"}
{"file":"README.md","line":9,"command":"echo hello"}'

@test "fails when the discoverer is missing" {
    repo=$(make_repo missing)
    rm -f "$repo/scripts/discover-commands.sh"
    run bash "$repo/scripts/verify-commands.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"is missing or not executable; nothing was verified"* ]]
}

@test "fails when the discoverer is not executable" {
    repo=$(make_repo notexec)
    chmod -x "$repo/scripts/discover-commands.sh"
    run bash "$repo/scripts/verify-commands.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"is missing or not executable; nothing was verified"* ]]
}

@test "fails when the discoverer exits non-zero" {
    repo=$(make_repo failing)
    write_discovery "$repo" "$SAFE_COMMANDS"
    run env STUB_DISCOVER_RC=3 bash "$repo/scripts/verify-commands.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"exited 3; nothing was verified"* ]]
}

@test "fails when discovery lists no commands" {
    repo=$(make_repo empty)
    run bash "$repo/scripts/verify-commands.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"discovery returned no commands to verify"* ]]
    [[ "$output" != *"All commands validated successfully"* ]]
}

@test "fails when discovery is not parseable as JSON" {
    repo=$(make_repo garbage)
    write_discovery "$repo" 'this is not json {'
    run bash "$repo/scripts/verify-commands.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"could not parse the discovered command list"* ]]
}

@test "fails when every discovered record lacks a command field" {
    repo=$(make_repo nocommand)
    write_discovery "$repo" '{"file":"README.md","line":7}
{"file":"README.md","line":9}'
    run bash "$repo/scripts/verify-commands.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"none with a .command field; nothing was verified"* ]]
}

@test "--quick treats an empty discovery as advisory, not a failure" {
    repo=$(make_repo quick)
    run bash "$repo/scripts/verify-commands.sh" --quick
    [ "$status" -eq 0 ]
}

@test "validates every discovered command and reports the count" {
    repo=$(make_repo happy)
    write_discovery "$repo" "$SAFE_COMMANDS"
    run bash "$repo/scripts/verify-commands.sh" --force --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"validated": 2'* ]]
    [[ "$output" == *'"cache_hits": 0'* ]]
}

@test "a warm run reports cache hits instead of validating again" {
    repo=$(make_repo warm)
    write_discovery "$repo" "$SAFE_COMMANDS"
    bash "$repo/scripts/verify-commands.sh" --force --json > /dev/null
    run bash "$repo/scripts/verify-commands.sh" --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"validated": 0'* ]]
    [[ "$output" == *'"cache_hits": 2'* ]]
}
