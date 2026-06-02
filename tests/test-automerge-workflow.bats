#!/usr/bin/env bats
# BATS tests for dependabot-auto-merge.yml workflow improvements
# Validates: name-based filter, cancelled acceptance, timeout, and label fix

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WORKFLOW_FILE="$REPO_ROOT/.github/workflows/dependabot-auto-merge.yml"
}

@test "auto-merge workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "auto-merge workflow uses THIS_JOB_NAME constant for name-based self-exclusion" {
    # The name-based filter prevents auto-merge from detecting its own
    # previous failures as blocking checks after close/reopen cycles
    grep -q "THIS_JOB_NAME" "$WORKFLOW_FILE"
    grep -q "THIS_JOB_NAME = 'auto-merge'" "$WORKFLOW_FILE"
    grep -q "run.name !== THIS_JOB_NAME" "$WORKFLOW_FILE"
}

@test "auto-merge workflow excludes auto-merge check by name (not external_id)" {
    # After the fix, the filter uses run.name !== THIS_JOB_NAME
    # The broken external_id/html_url approach should be removed
    ! grep -q "external_id" "$WORKFLOW_FILE"
    ! grep -q "html_url" "$WORKFLOW_FILE"
}

@test "auto-merge workflow accepts cancelled checks as non-failing" {
    # Cancelled checks (e.g., Update CI Status from concurrency) should
    # not block auto-merge — they are deliberate, not failures
    grep -q "'cancelled'" "$WORKFLOW_FILE"
    grep -q "'success', 'neutral', 'skipped', 'cancelled'" "$WORKFLOW_FILE"
}

@test "auto-merge workflow has increased MAX_RETRIES for concurrent CI queue" {
    # Increased from 60 to 90 (~45 min total) to handle check queue
    # buildup when multiple CI workflows trigger simultaneously on reopen
    grep -q "MAX_RETRIES = 90" "$WORKFLOW_FILE"
}

@test "auto-merge workflow has the yamllint truthy disable comment" {
    grep -q "yamllint disable-line rule:truthy" "$WORKFLOW_FILE"
}

@test "auto-merge workflow triggers on pull_request events" {
    # Must trigger on pull_request to run for Dependabot PRs
    grep -q "on: pull_request" "$WORKFLOW_FILE"
}

@test "auto-merge workflow has pull-requests write permission" {
    grep -q "pull-requests: write" "$WORKFLOW_FILE"
}

@test "auto-merge workflow has contents write permission" {
    grep -q "contents: write" "$WORKFLOW_FILE"
}
