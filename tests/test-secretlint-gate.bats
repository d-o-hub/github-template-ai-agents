#!/usr/bin/env bats
# BATS tests for secretlint_gate.sh: a missing npx must not read as a passing secret scan.
# The gate only applies when .secretlintrc.json is present, and SKIP_SECRETLINT=true is the
# single sanctioned way to skip it.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

setup() {
    cd "$REPO_ROOT" || exit 1
}

# A fixture dir holding the copied gate script; $1=true creates a .secretlintrc.json.
new_fixture() {
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/scripts"
    cp scripts/secretlint_gate.sh "$TEMP_DIR/scripts/"
    chmod +x "$TEMP_DIR/scripts/secretlint_gate.sh"
    if [[ "$1" == "with-config" ]]; then
        printf '{"rules":[{"id":"@secretlint/secretlint-rule-preset-recommend"}]}\n' \
            > "$TEMP_DIR/.secretlintrc.json"
    fi
    cd "$TEMP_DIR" || exit 1
}

teardown_fixture() {
    cd "$REPO_ROOT" || exit 1
    rm -rf -- "$TEMP_DIR"
}

# PATH=/nonexistent removes npx without removing the absolute bash used to run the gate.
run_without_npx() {
    run env -u SKIP_SECRETLINT PATH=/nonexistent /bin/bash scripts/secretlint_gate.sh
}

@test "missing npx fails the gate instead of skipping silently" {
    new_fixture with-config
    run_without_npx
    echo "$output"
    [ "$status" -eq 1 ]
    [[ "$output" == *"npx not found, secretlint cannot run"* ]]
    teardown_fixture
}

@test "SKIP_SECRETLINT=true is the only way to skip a missing npx" {
    new_fixture with-config
    run env SKIP_SECRETLINT=true PATH=/nonexistent /bin/bash scripts/secretlint_gate.sh
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skipping secretlint (SKIP_SECRETLINT=true)"* ]]
    teardown_fixture
}

@test "a repository without .secretlintrc.json is unaffected" {
    new_fixture no-config
    run_without_npx
    echo "$output"
    [ "$status" -eq 0 ]
    [[ "$output" != *"secretlint"* ]]
    teardown_fixture
}
