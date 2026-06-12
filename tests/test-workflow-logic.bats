#!/usr/bin/env bats

@test "workflow uses fixed ci/status-update branch" {
    grep -q "PR_BRANCH=\"ci/status-update\"" .github/workflows/ci.yml
}

@test "workflow uses gh pr create command" {
    grep -q "gh pr create" .github/workflows/ci.yml
}

@test "workflow omits skip ci from branch commit (allows checks to run)" {
    grep -q "commit -m \"ci: update ci status artifacts\"" .github/workflows/ci.yml
    ! grep -q "commit -m \"ci: update ci status artifacts \\[skip ci\\]\"" .github/workflows/ci.yml
}

@test "workflow includes skip ci only in squash merge subject" {
    grep -q '\-\-subject "ci: update ci status artifacts \[skip ci\]"' .github/workflows/ci.yml
}

@test "workflow uses dynamic base for PR creation" {
    grep -q "\-\-base \"\$TARGET_BRANCH\"" .github/workflows/ci.yml
}

@test "workflow has concurrency configuration" {
    grep -q "concurrency:" .github/workflows/ci.yml
    grep -q "group: ci-status-" .github/workflows/ci.yml
    grep -q "cancel-in-progress: true" .github/workflows/ci.yml
}

@test "workflow reuses existing PR for merging" {
    grep -q "EXISTING_PR" .github/workflows/ci.yml
    grep -q "Reusing existing PR" .github/workflows/ci.yml
}

@test "workflow uses force push to fixed branch" {
    grep -q "git push origin --force -- \"\$PR_BRANCH\"" .github/workflows/ci.yml
}

@test "workflow performs auto-merge with admin bypass" {
    grep -q "gh pr merge \"\$NEW_PR\"" .github/workflows/ci.yml
    grep -q "\-\-admin" .github/workflows/ci.yml
    grep -q "\-\-squash" .github/workflows/ci.yml
    # Should NOT use --delete-branch for this specific workflow
    grep -q "\-\-delete-branch=false" .github/workflows/ci.yml
}

@test "workflow has ci-status label step" {
    grep -q "gh label create ci-status" .github/workflows/ci.yml
}

@test "update-ci-status job skips on pull_request events" {
    grep -q "github.event_name != 'pull_request'" .github/workflows/ci.yml
}
