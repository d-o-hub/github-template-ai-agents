#!/usr/bin/env bats
# Tests for agent-toolkit CLI

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    CLI="$REPO_ROOT/bin/agent-toolkit"
}

@test "agent-toolkit: help shows usage" {
    run "$CLI" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"agent-toolkit"* ]]
    [[ "$output" == *"COMMANDS"* ]]
    [[ "$output" == *"setup"* ]]
    [[ "$output" == *"doctor"* ]]
    [[ "$output" == *"quality"* ]]
}

@test "agent-toolkit: --help shows usage" {
    run "$CLI" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
}

@test "agent-toolkit: -h shows usage" {
    run "$CLI" -h
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMMANDS"* ]]
}

@test "agent-toolkit: version shows version" {
    run "$CLI" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"agent-toolkit v"* ]]
}

@test "agent-toolkit: --version shows version" {
    run "$CLI" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"agent-toolkit v"* ]]
}

@test "agent-toolkit: unknown command fails" {
    run "$CLI" nonexistent
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "agent-toolkit: no args shows help" {
    run "$CLI"
    [ "$status" -eq 0 ]
    [[ "$output" == *"COMMANDS"* ]]
}

@test "agent-toolkit: validate skills runs" {
    run "$CLI" validate skills
    [ "$status" -eq 0 ]
    [[ "$output" == *"All skills valid"* ]]
}

@test "agent-toolkit: validate unknown target fails" {
    run "$CLI" validate bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown validate target"* ]]
}

@test "agent-toolkit: bin/agent-toolkit is symlink" {
    [ -L "$REPO_ROOT/bin/agent-toolkit" ]
}
