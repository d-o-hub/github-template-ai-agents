#!/usr/bin/env bats
# Tests for scripts/bootstrap.sh and scripts/doctor.sh

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    cd "$REPO_ROOT"
}

# ---------- bootstrap.sh ----------

@test "bootstrap.sh exists and is executable" {
    [ -x "./scripts/bootstrap.sh" ]
}

@test "bootstrap.sh has bash shebang" {
    head -1 ./scripts/bootstrap.sh | grep -q "^#!/usr/bin/env bash$"
}

@test "bootstrap.sh passes shellcheck" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    run shellcheck ./scripts/bootstrap.sh
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh has set -euo pipefail" {
    grep -q '^set -euo pipefail$' ./scripts/bootstrap.sh
}

@test "bootstrap.sh references doctor.sh on failure" {
    grep -q 'doctor.sh' ./scripts/bootstrap.sh
}

@test "bootstrap.sh uses REPO_ROOT detection pattern" {
    grep -q 'REPO_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE\[0\]}")/.." && pwd)"' \
        ./scripts/bootstrap.sh
}

# ---------- doctor.sh ----------

@test "doctor.sh exists and is executable" {
    [ -x "./scripts/doctor.sh" ]
}

@test "doctor.sh has bash shebang" {
    head -1 ./scripts/doctor.sh | grep -q "^#!/usr/bin/env bash$"
}

@test "doctor.sh passes shellcheck" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    run shellcheck ./scripts/doctor.sh
    [ "$status" -eq 0 ]
}

@test "doctor.sh uses REPO_ROOT detection pattern" {
    grep -q 'REPO_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE\[0\]}")/.." && pwd)"' \
        ./scripts/doctor.sh
}

@test "doctor.sh checks for required tools" {
    grep -q 'Required tools' ./scripts/doctor.sh
    grep -q 'for cmd in git bash' ./scripts/doctor.sh
}

@test "doctor.sh checks symlink support" {
    grep -q 'Symlink support' ./scripts/doctor.sh
}

@test "doctor.sh checks for .agents/skills directory" {
    grep -q '.agents/skills' ./scripts/doctor.sh
}

@test "doctor.sh checks for pre-commit hook" {
    grep -q 'git config core.hooksPath' ./scripts/doctor.sh
}

@test "doctor.sh detects missing pre-commit hook with non-zero exit" {
    HOOKS_DIR=$(git config core.hooksPath || echo ".git/hooks")
    HOOK="$HOOKS_DIR/pre-commit"
    BACKUP=""
    if [ -f "$HOOK" ]; then
        BACKUP="$(mktemp)"
        cp "$HOOK" "$BACKUP"
        rm -f "$HOOK"
    fi

    run ./scripts/doctor.sh

    if [ -n "$BACKUP" ]; then
        cp "$BACKUP" "$HOOK"
        chmod +x "$HOOK"
        rm -f "$BACKUP"
    fi

    [ "$status" -ne 0 ]
}

@test "doctor.sh prints structured pass/fail messages" {
    run ./scripts/doctor.sh
    # Either pass or fail, output should include section headers
    [[ "$output" == *"==>"* ]]
}

# doctor.sh must agree with the gate about what "healthy" means. A PATH holding
# only the commands doctor itself needs makes every optional tool absent, so the
# check is deterministic instead of depending on what the host happens to have.
make_doctor_bin() {
    DOCTOR_BIN="$(mktemp -d)"
    local tool path
    for tool in bash git mktemp ln rm sed readlink; do
        path="$(command -v "$tool")" || continue
        ln -s "$path" "$DOCTOR_BIN/$tool"
    done
}

@test "doctor.sh warns instead of passing when a gate tool is missing" {
    make_doctor_bin
    run env PATH="$DOCTOR_BIN" "$DOCTOR_BIN/bash" ./scripts/doctor.sh
    rm -rf "$DOCTOR_BIN"

    [[ "$output" == *"! shellcheck not found"* ]]
    [[ "$output" == *"quality_gate.sh will report it as a skip"* ]]
    [[ "$output" != *"✓ shellcheck available"* ]]
}

@test "doctor.sh fails when a gate tool exists but cannot run" {
    make_doctor_bin
    # A broken install the gate would find and then fail on, with no hint why.
    printf '#!%s\nprintf "boom\\n" >&2\nexit 1\n' "$(command -v bash)" > "$DOCTOR_BIN/shellcheck"
    chmod +x "$DOCTOR_BIN/shellcheck"

    run env PATH="$DOCTOR_BIN" "$DOCTOR_BIN/bash" ./scripts/doctor.sh
    rm -rf "$DOCTOR_BIN"

    [ "$status" -ne 0 ]
    [[ "$output" == *"✗ shellcheck at"*"does not run"* ]]
    [[ "$output" != *"✓ shellcheck available"* ]]
}

@test "doctor.sh fails on a missing gate tool under QUALITY_GATE_STRICT_SKIPS" {
    make_doctor_bin
    run env PATH="$DOCTOR_BIN" QUALITY_GATE_STRICT_SKIPS=true "$DOCTOR_BIN/bash" ./scripts/doctor.sh
    rm -rf "$DOCTOR_BIN"

    # Same environment as the test above: only strict mode differs.
    [ "$status" -ne 0 ]
    [[ "$output" == *"✗ shellcheck not found"* ]]
    [[ "$output" == *"strict skip mode makes that a gate failure"* ]]
    [[ "$output" != *"doctor: all checks passed"* ]]
}
