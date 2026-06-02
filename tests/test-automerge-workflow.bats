#!/usr/bin/env bats
# BATS tests for dependabot-auto-merge.yml workflow
# Validates: GraphQL-based auto-merge, review thread resolution, squash

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    WORKFLOW_FILE="$REPO_ROOT/.github/workflows/dependabot-auto-merge.yml"
}

@test "auto-merge workflow file exists" {
    [ -f "$WORKFLOW_FILE" ]
}

@test "auto-merge workflow uses enablePullRequestAutoMerge GraphQL mutation" {
    # Uses GitHub native auto-merge (handles linear history, branch updates,
    # and required checks using system privileges)
    grep -q "enablePullRequestAutoMerge" "$WORKFLOW_FILE"
}

@test "auto-merge workflow resolves review threads before merging" {
    # Resolves bot comments (e.g., Codacy false positives) that would
    # otherwise block merge due to required_review_thread_resolution
    grep -q "resolveReviewThread" "$WORKFLOW_FILE"
}

@test "auto-merge workflow uses SQUASH merge method" {
    grep -q "SQUASH" "$WORKFLOW_FILE"
}

@test "auto-merge workflow checks for existing autoMergeRequest" {
    # Idempotent: if auto-merge is already enabled, don't re-enable
    grep -q "autoMergeRequest" "$WORKFLOW_FILE"
}

@test "auto-merge workflow fetches reviewThreads for resolution" {
    grep -q "reviewThreads" "$WORKFLOW_FILE"
}

@test "auto-merge workflow uses github.graphql (not REST API)" {
    # Native auto-merge requires GraphQL, direct REST pulls.merge
    # can't satisfy required_linear_history with Dependabot tokens
    grep -q "github.graphql" "$WORKFLOW_FILE"
}

@test "auto-merge workflow has the yamllint truthy disable comment" {
    grep -q "yamllint disable-line rule:truthy" "$WORKFLOW_FILE"
}

@test "auto-merge workflow triggers on pull_request events" {
    grep -q "on: pull_request" "$WORKFLOW_FILE"
}

@test "auto-merge workflow has pull-requests write permission" {
    grep -q "pull-requests: write" "$WORKFLOW_FILE"
}

@test "auto-merge workflow has contents write permission" {
    grep -q "contents: write" "$WORKFLOW_FILE"
}

# ──────────────────────────────────────────────────────────────
# Negative tests: verify OLD patterns are NOT present (regression guards)
# These prevent accidental reintroduction of the manual polling +
# direct REST merge approach that couldn't handle linear history.
# ──────────────────────────────────────────────────────────────

@test "auto-merge workflow does NOT contain THIS_JOB_NAME (no manual self-exclusion)" {
    # Manual check-run filtering by job name is obsolete;
    # GitHub native auto-merge handles this natively
    ! grep -q "THIS_JOB_NAME" "$WORKFLOW_FILE"
}

@test "auto-merge workflow does NOT contain MAX_RETRIES (no manual polling timeout)" {
    # Manual polling loop with timeout is obsolete;
    # GitHub native auto-merge handles check waiting natively
    ! grep -q "MAX_RETRIES" "$WORKFLOW_FILE"
}

@test "auto-merge workflow does NOT contain external_id (broken self-exclusion removed)" {
    ! grep -q "external_id" "$WORKFLOW_FILE"
}

@test "auto-merge workflow does NOT contain getCombinedStatusForRef (dead legacy API removed)" {
    # Combined status API treats cancelled as failure and is no longer used
    ! grep -q "getCombinedStatusForRef" "$WORKFLOW_FILE"
}

@test "auto-merge workflow does NOT contain listForRef (no manual check polling)" {
    # Direct check-run polling via REST API is obsolete;
    # GitHub native auto-merge handles required checks natively
    ! grep -q "listForRef" "$WORKFLOW_FILE"
}

@test "auto-merge workflow does NOT contain pulls.merge (no direct REST merge)" {
    # Direct REST pulls.merge can't satisfy required_linear_history
    # when Dependabot token is read-only; GraphQL enablePullRequestAutoMerge
    # uses system privileges instead
    ! grep -q "pulls.merge" "$WORKFLOW_FILE"
}
