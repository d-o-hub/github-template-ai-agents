#!/usr/bin/env bats

@test "workflow has concurrency configuration" {
    grep -q "concurrency:" .github/workflows/ci.yml
    grep -q "cancel-in-progress: true" .github/workflows/ci.yml
}

@test "workflow delegates CI status persistence to persist script" {
    grep -q "persist-ci-status.sh" .github/workflows/ci.yml
    test -x scripts/persist-ci-status.sh
    grep -q 'ci: update ci status artifacts \[skip ci\]' scripts/persist-ci-status.sh
}

@test "workflow persists CI data only on main" {
    grep -q "github.ref == 'refs/heads/main'" .github/workflows/ci.yml
}

@test "workflow uploads CI status artifact" {
    grep -q "upload-artifact" .github/workflows/ci.yml
    grep -q "ci-status" .github/workflows/ci.yml
}

@test "workflow checks required job results" {
    # The gate is delegated to the producer, which asserts the expected value of
    # every needs.<job>.result. A denylist of bad results is fail-open: GitHub
    # reports an `if:`-skipped job as "Success" (ADR-040).
    grep -q 'toJSON(needs)' .github/workflows/ci.yml
    grep -q 'update-ci-status.py --check' .github/workflows/ci.yml
    ! grep -q "== \"failure\" || " .github/workflows/ci.yml
}

@test "workflow uses SHA-pinned actions" {
    grep -q "uses: actions/checkout@" .github/workflows/ci.yml
    grep -q "uses: actions/setup-node@" .github/workflows/ci.yml
    grep -q "uses: actions/setup-python@" .github/workflows/ci.yml
}

@test "workflow has no path-filtered job gating validation" {
    # Reversed 2026-10-02. The change-detection job existed only to feed
    # needs.changes.outputs.* into quality-gate's `if:`, and ADR-040's fail-closed
    # artifact turns a skipped required job into `unknown` -- so a docs-only or
    # plans-only PR could not be certified and merging one turned main red.
    # The filter now gates nothing, so the job is gone instead of left as
    # decoration that invites the same regression.
    ! grep -q "name: Detect Changes" .github/workflows/ci.yml
    ! grep -q "dorny/paths-filter" .github/workflows/ci.yml
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

@test "status artifacts are always written on main (all-skipped records unknown)" {
    # ADR-033 deferred the write when every job was skipped to protect a green.
    # The fail-closed producer now records `unknown` instead, so the guard is
    # gone and only the main-ref condition remains.
    ! grep -q "needs.quality-gate.result != 'skipped'" .github/workflows/ci.yml
    ! grep -q "needs.test.result != 'skipped'" .github/workflows/ci.yml
    grep -q "github.ref == 'refs/heads/main'" .github/workflows/ci.yml
}

@test "status artifacts ARE written on failure (not only success)" {
    # Must run when a required job failed/cancelled, so a failing main is
    # recorded as 'failing' rather than left stale/passing.
    ! grep -q "result == 'success' || needs.test.result == 'success'" .github/workflows/ci.yml
    grep -q "github.ref == 'refs/heads/main'" .github/workflows/ci.yml
}

@test "ci-success declares the skip allowlist from a repository variable" {
    sed -n '/ci-success:/,/^  [a-z]/p' .github/workflows/ci.yml \
        | grep -q 'CI_STATUS_ALLOWED_SKIPS: ${{ vars.CI_STATUS_ALLOWED_SKIPS }}'
}

@test "quality-gate is unconditional so a docs-only PR can be certified" {
    # ADR-040: a skipped required job records `unknown`, never `passing`. With a
    # path filter over source extensions, a plans-only or docs-only PR left
    # quality-gate skipped, so `CI Success` failed with
    # "CI gate NOT satisfied (status=unknown)" and main went red on merge.
    # ADR-041 fixed the test job; this pins the gate job.
    job=$(sed -n '/^  quality-gate:/,/^  [a-z]/p' .github/workflows/ci.yml)
    ! grep -q "needs.changes" <<< "$job"
    ! grep -q "outputs.code" <<< "$job"
}

@test "the dead path-filter job is gone rather than left as decoration" {
    # Nothing consumed needs.changes.outputs.* once the gate became
    # unconditional, so keeping the filter would invite the same regression.
    ! grep -q "Detect Changes" .github/workflows/ci.yml
    ! grep -q "dorny/paths-filter" .github/workflows/ci.yml
}
