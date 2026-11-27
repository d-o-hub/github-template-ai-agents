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

@test "npx invocation is non-interactive and version-pinned" {
    # An unpinned, prompt-driven `npx -p secretlint ...` asks for confirmation
    # when the package is absent. With no TTY that prompt never resolves, so the
    # gate hangs instead of failing -- observed as an ~8 minute stall locally.
    new_fixture with-config
    mkdir -p "$TEMP_DIR/bin"
    cat > "$TEMP_DIR/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$NPX_ARGS_FILE"
STUB
    chmod +x "$TEMP_DIR/bin/npx"
    run env NPX_ARGS_FILE="$TEMP_DIR/args.txt" PATH="$TEMP_DIR/bin:/usr/bin:/bin" \
        /bin/bash scripts/secretlint_gate.sh
    echo "$output"
    [ "$status" -eq 0 ]
    grep -qx -- '--yes' "$TEMP_DIR/args.txt"
    grep -qE '^secretlint@[0-9]+\.[0-9]+\.[0-9]+$' "$TEMP_DIR/args.txt"
    teardown_fixture
}

@test "a pinned version can be overridden without editing the gate" {
    new_fixture with-config
    mkdir -p "$TEMP_DIR/bin"
    cat > "$TEMP_DIR/bin/npx" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$NPX_ARGS_FILE"
STUB
    chmod +x "$TEMP_DIR/bin/npx"
    run env SECRETLINT_VERSION=99.0.0 NPX_ARGS_FILE="$TEMP_DIR/args.txt" \
        PATH="$TEMP_DIR/bin:/usr/bin:/bin" /bin/bash scripts/secretlint_gate.sh
    echo "$output"
    [ "$status" -eq 0 ]
    grep -qx -- 'secretlint@99.0.0' "$TEMP_DIR/args.txt"
    teardown_fixture
}
