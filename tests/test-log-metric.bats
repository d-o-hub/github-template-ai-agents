#!/usr/bin/env bats
# BATS tests for scripts/log-metric.sh
# Tests the per-agent metrics helper script

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

setup() {
    cd "$REPO_ROOT" || exit 1
    # Clean up any test artifacts from all agent names used in tests
    rm -f .agents/metrics/metrics-testagent.jsonl
    rm -f .agents/metrics/metrics-test-agent.jsonl
}

teardown() {
    rm -f .agents/metrics/metrics-testagent.jsonl
    rm -f .agents/metrics/metrics-test-agent.jsonl
}

@test "log-metric.sh exists and is executable" {
    [ -x "./scripts/log-metric.sh" ]
}

@test "log-metric.sh fails without arguments" {
    run ./scripts/log-metric.sh
    [ "$status" -ne 0 ]
}

@test "log-metric.sh fails with invalid JSON" {
    run ./scripts/log-metric.sh 'not-json'
    [ "$status" -ne 0 ]
}

@test "log-metric.sh fails when JSON lacks agent field" {
    run ./scripts/log-metric.sh '{"timestamp":"2026-07-29T12:00:00Z","task":"test"}'
    [ "$status" -ne 0 ]
}

@test "log-metric.sh appends valid entry to per-agent file" {
    run ./scripts/log-metric.sh '{"timestamp":"2026-07-29T12:00:00Z","agent":"testagent","task":"test task","skill_used":"none","status":"completed","tokens_used":10,"duration_seconds":1}'
    [ "$status" -eq 0 ]
    [ -f ".agents/metrics/metrics-testagent.jsonl" ]
    # Verify content
    run cat .agents/metrics/metrics-testagent.jsonl
    [[ "$output" == *"testagent"* ]]
    [[ "$output" == *"test task"* ]]
}

@test "log-metric.sh sanitizes agent names with slashes" {
    run ./scripts/log-metric.sh '{"timestamp":"2026-07-29T12:00:00Z","agent":"test/agent","task":"slash test","skill_used":"none","status":"completed","tokens_used":10,"duration_seconds":1}'
    [ "$status" -eq 0 ]
    [ -f ".agents/metrics/metrics-test-agent.jsonl" ]
    rm -f .agents/metrics/metrics-test-agent.jsonl
}

@test "log-metric.sh sanitizes agent names with spaces" {
    run ./scripts/log-metric.sh '{"timestamp":"2026-07-29T12:00:00Z","agent":"test agent","task":"space test","skill_used":"none","status":"completed","tokens_used":10,"duration_seconds":1}'
    [ "$status" -eq 0 ]
    [ -f ".agents/metrics/metrics-test-agent.jsonl" ]
    rm -f .agents/metrics/metrics-test-agent.jsonl
}
