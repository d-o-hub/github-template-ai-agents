#!/usr/bin/env bats

@test "workflow uses fixed ci/status-update branch" {
    grep -q 'PR_BRANCH="ci/status-update"' .github/workflows/ci-and-labels.yml
}

@test "workflow uses gh pr create command" {
    grep -q "gh pr create" .github/workflows/ci-and-labels.yml
}

@test "workflow includes skip ci in commit message" {
    grep -q "commit -m \"ci: update ci status artifacts \[skip ci\]\"" .github/workflows/ci-and-labels.yml
}

@test "workflow targets base via TARGET_BRANCH variable" {
    grep -q "TARGET_BRANCH" .github/workflows/ci-and-labels.yml
}
