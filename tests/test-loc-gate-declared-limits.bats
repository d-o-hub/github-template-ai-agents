#!/usr/bin/env bats
# BATS tests for loc_gate.sh: the line limits must come from a declaration, never from a
# hardcoded fallback. A literal 150 used to override the documented MAX_LINES_AGENTS_MD=200
# and failed valid AGENTS.md files, so an undeclared limit now warns and skips instead.
#
# Source/skill limits are passed as overrides except where a test asserts they are absent,
# because the copied loc_gate.sh lives inside the fixture and is itself LOC-scanned.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

setup() {
    cd "$REPO_ROOT" || exit 1
}

# Build a temp repo holding loc_gate.sh, with AGENTS.md sized to $1 lines plus an optional
# $2 header line (used to declare a limit inside AGENTS.md itself).
new_fixture() {
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/scripts" "$TEMP_DIR/.agents/skills" "$TEMP_DIR/src"
    cp scripts/loc_gate.sh "$TEMP_DIR/scripts/"
    chmod +x "$TEMP_DIR/scripts/loc_gate.sh"
    cd "$TEMP_DIR" || exit 1
    git init -q .
    write_agents_md "$@"
}

write_agents_md() {
    local lines="$1" extra="${2:-}"
    {
        [[ -n "$extra" ]] && printf '%s\n' "$extra"
        seq 1 "$lines" | sed 's/^/line /'
    } > AGENTS.md
}

declare_limits() {
    printf 'readonly MAX_LINES_AGENTS_MD=%s\n' "$1" > .agents/config.sh
}

teardown_fixture() {
    cd "$REPO_ROOT" || exit 1
    rm -rf -- "$TEMP_DIR"
}

@test "undeclared AGENTS.md limit warns and skips instead of failing at 150" {
    new_fixture 160
    run env MAX_SOURCE_OVERRIDE=500 MAX_SKILL_OVERRIDE=250 bash scripts/loc_gate.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping the AGENTS.md cap"* ]]
    [[ "$output" != *"max 150"* ]]
    teardown_fixture
}

@test "AGENTS.md limit falls back to the .agents/config.sh declaration" {
    new_fixture 160
    declare_limits 200
    run env MAX_SOURCE_OVERRIDE=500 MAX_SKILL_OVERRIDE=250 bash scripts/loc_gate.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" != *"skipping the AGENTS.md cap"* ]]
    teardown_fixture
}

@test "the config.sh declaration still enforces a real violation" {
    new_fixture 210
    declare_limits 200
    run env MAX_SOURCE_OVERRIDE=500 MAX_SKILL_OVERRIDE=250 bash scripts/loc_gate.sh
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"has 210 lines (max 200)"* ]]
    teardown_fixture
}

@test "AGENTS.md wins over .agents/config.sh when both declare the limit" {
    new_fixture 160 'readonly MAX_LINES_AGENTS_MD=120'
    declare_limits 200
    run env MAX_SOURCE_OVERRIDE=500 MAX_SKILL_OVERRIDE=250 bash scripts/loc_gate.sh
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"(max 120)"* ]]
    teardown_fixture
}

@test "source cap warns and skips when nothing declares it" {
    new_fixture 20
    seq 1 600 | sed 's/^/echo /' > src/big.sh
    run bash scripts/loc_gate.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping the source cap"* ]]
    [[ "$output" != *"ERROR"* ]]
    teardown_fixture
}
