#!/usr/bin/env bats
# BATS tests for loc_gate.sh: verify git-ignored paths are excluded while
# non-ignored source files are still enforced.
#
# Limits stay at 500 (not lower) because the copied loc_gate.sh lives inside the
# fixture and is itself LOC-scanned; over-limit fixtures use 600 lines.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

setup() {
    cd "$REPO_ROOT" || exit 1
}

# Build a temp repo holding loc_gate.sh plus a .agents/skills dir for section 2.
new_fixture() {
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/scripts" "$TEMP_DIR/.agents/skills" "$TEMP_DIR/src"
    cp scripts/loc_gate.sh "$TEMP_DIR/scripts/"
    chmod +x "$TEMP_DIR/scripts/loc_gate.sh"
    cd "$TEMP_DIR" || exit 1
    git init -q .
    printf 'MAX_LINES_PER_SOURCE_FILE=500\n' > AGENTS.md
}

write_file_with_lines() {
    seq 1 "$2" | sed 's/^/line /' > "$1"
}

teardown_fixture() {
    cd "$REPO_ROOT" || exit 1
    rm -rf "$TEMP_DIR"
}

@test "loc_gate.sh skips an over-limit file inside a git-ignored directory" {
    new_fixture
    printf 'generated/\n' > .gitignore
    mkdir -p generated
    write_file_with_lines generated/huge.js 600
    echo "small" > src/normal.js

    run ./scripts/loc_gate.sh
    [ "$status" -eq 0 ]

    teardown_fixture
}

@test "loc_gate.sh still fails on a non-ignored over-limit file inside a git repo" {
    new_fixture
    printf 'generated/\n' > .gitignore
    mkdir -p generated
    write_file_with_lines generated/huge.js 600
    write_file_with_lines src/real.js 600

    run ./scripts/loc_gate.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"./src/real.js"* ]]
    [[ "$output" != *"generated/huge.js"* ]]

    teardown_fixture
}

@test "loc_gate.sh does not hide a real file behind an ignored filename prefix" {
    new_fixture
    printf 'src/skipme.py\n' > .gitignore
    write_file_with_lines src/skipme.py 600
    write_file_with_lines src/skipme.py.broken.js 600

    run ./scripts/loc_gate.sh
    # An ignored file is matched exactly, so the prefix collision is still caught.
    [ "$status" -eq 1 ]
    [[ "$output" == *"./src/skipme.py.broken.js"* ]]
    [[ "$output" != *"./src/skipme.py has"* ]]

    teardown_fixture
}

# Guards the empty-prune-list expansion: a repo with nothing ignored must neither
# error on the unset array nor lose enforcement.
@test "loc_gate.sh enforces limits when the repo has no ignored paths" {
    new_fixture
    write_file_with_lines src/huge.js 600

    run git ls-files --others --ignored --exclude-standard --directory
    [ -z "$output" ]

    run ./scripts/loc_gate.sh
    [ "$status" -eq 1 ]
    [[ "$output" == *"./src/huge.js"* ]]

    teardown_fixture
}

@test "loc_gate.sh passes a clean repo that has no ignored paths" {
    new_fixture
    echo "small" > src/ok.js

    run ./scripts/loc_gate.sh
    [ "$status" -eq 0 ]

    teardown_fixture
}
