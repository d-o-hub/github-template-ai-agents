#!/usr/bin/env bats

@test "workflow uses fixed ci/status-update branch" {
    grep -q "PR_BRANCH=\"ci/status-update\"" .github/workflows/ci-and-labels.yml
}

@test "workflow uses gh pr create command" {
    grep -q "gh pr create" .github/workflows/ci-and-labels.yml
}

@test "workflow includes skip ci in commit message" {
    grep -q "commit -m \"ci: update ci status artifacts \\[skip ci\\]\"" .github/workflows/ci-and-labels.yml
}

@test "workflow hardcodes base to main" {
    grep -q "\-\-base main" .github/workflows/ci-and-labels.yml
}

@test "workflow has concurrency configuration" {
    grep -q "concurrency:" .github/workflows/ci-and-labels.yml
    grep -q "group: ci-status-" .github/workflows/ci-and-labels.yml
    grep -q "cancel-in-progress: true" .github/workflows/ci-and-labels.yml
}

@test "workflow skips PR creation if one exists" {
    grep -q "EXISTING_PR" .github/workflows/ci-and-labels.yml
    grep -q "already exists" .github/workflows/ci-and-labels.yml
}

@test "workflow uses force push to fixed branch" {
    grep -q "git push origin --force -- \"\$PR_BRANCH\"" .github/workflows/ci-and-labels.yml
}
