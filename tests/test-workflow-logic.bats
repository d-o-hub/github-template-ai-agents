#!/usr/bin/env bats

@test "workflow uses fixed branch ci/status-update" {
    grep -q "branch: ci/status-update" .github/workflows/ci-and-labels.yml
}

@test "workflow uses create-pull-request action" {
    grep -q "uses: peter-evans/create-pull-request" .github/workflows/ci-and-labels.yml
}

@test "workflow includes skip ci in commit message" {
    grep -q "commit-message: \"ci: update ci status artifacts \[skip ci\]\"" .github/workflows/ci-and-labels.yml
}

@test "workflow targets main as base branch" {
    grep -q "base: main" .github/workflows/ci-and-labels.yml
}
