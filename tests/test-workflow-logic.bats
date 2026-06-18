#!/usr/bin/env bats

@test "workflow has concurrency configuration" {
    grep -q "concurrency:" .github/workflows/ci.yml
    grep -q "cancel-in-progress: true" .github/workflows/ci.yml
}

@test "workflow includes skip ci in status commit" {
    grep -q 'commit -m "ci: update ci status artifacts \[skip ci\]"' .github/workflows/ci.yml
}

@test "workflow persists CI data only on main" {
    grep -q "github.ref == 'refs/heads/main'" .github/workflows/ci.yml
}

@test "workflow uploads CI status artifact" {
    grep -q "upload-artifact" .github/workflows/ci.yml
    grep -q "ci-status" .github/workflows/ci.yml
}

@test "workflow checks required job results" {
    grep -q 'needs.quality-gate.result' .github/workflows/ci.yml
    grep -q 'needs.test.result' .github/workflows/ci.yml
}

@test "workflow uses SHA-pinned actions" {
    grep -q "uses: actions/checkout@" .github/workflows/ci.yml
    grep -q "uses: actions/setup-node@" .github/workflows/ci.yml
    grep -q "uses: actions/setup-python@" .github/workflows/ci.yml
}

@test "workflow has change detection job" {
    grep -q "name: Detect Changes" .github/workflows/ci.yml
    grep -q "dorny/paths-filter" .github/workflows/ci.yml
}

@test "workflow runs quality gate" {
    grep -q "quality_gate.sh" .github/workflows/ci.yml
    grep -q "SKIP_GLOBAL_HOOKS_CHECK=true" .github/workflows/ci.yml
}

@test "workflow runs BATS tests" {
    grep -q "bats tests/\*.bats" .github/workflows/ci.yml
}

@test "workflow has permissions restricted to read" {
    grep -q "permissions:" .github/workflows/ci.yml
    grep -q "contents: read" .github/workflows/ci.yml
}

@test "ci-success job has write permissions for persisting" {
    sed -n '/ci-success:/,/^  [a-z]/p' .github/workflows/ci.yml | grep -q "contents: write"
}
