#!/usr/bin/env bats
# Tests for .agents/skills/dora-report/scripts/generate_report.py:
# real computed metrics, no placeholders, notes preservation.

setup() {
    FIXTURE_DIR="$(mktemp -d)"
    export REPO_ROOT="$FIXTURE_DIR"
    mkdir -p "$FIXTURE_DIR/agents-docs/dora-reports" "$FIXTURE_DIR/.agents/metrics" "$FIXTURE_DIR/plans"
    git -C "$FIXTURE_DIR" init -q
    git -C "$FIXTURE_DIR" config user.email "test@example.com"
    git -C "$FIXTURE_DIR" config user.name "test"
    printf 'x\n' > "$FIXTURE_DIR/file.txt"
    git -C "$FIXTURE_DIR" add -A
    GIT_AUTHOR_DATE="2026-09-05T10:00:00" GIT_COMMITTER_DATE="2026-09-05T10:00:00" \
        git -C "$FIXTURE_DIR" commit -qm "feat: first change"
    printf 'y\n' >> "$FIXTURE_DIR/file.txt"
    git -C "$FIXTURE_DIR" add -A
    GIT_AUTHOR_DATE="2026-09-10T10:00:00" GIT_COMMITTER_DATE="2026-09-10T10:00:00" \
        git -C "$FIXTURE_DIR" commit -qm "fix: revert broken flag"
    printf '{"agent":"t","task":"x"}\n' > "$FIXTURE_DIR/.agents/metrics/metrics-t.jsonl"
    printf '## Round 1 final\n' > "$FIXTURE_DIR/plans/GOAP_STATE.md"
    export FIXTURE_DIR
    GEN="$BATS_TEST_DIRNAME/../.agents/skills/dora-report/scripts/generate_report.py"
}

teardown() {
    rm -rf "$FIXTURE_DIR"
}

@test "generates current-month report with real commit counts" {
    run python3 "$GEN" --month 2026-09
    [ "$status" -eq 0 ]
    [ -f "$FIXTURE_DIR/agents-docs/dora-reports/2026-09.md" ]
    grep -q "2 merges" "$FIXTURE_DIR/agents-docs/dora-reports/2026-09.md"
}

@test "counts revert commits as failures" {
    run python3 "$GEN" --month 2026-09
    [ "$status" -eq 0 ]
    grep -q "1 revert/hotfix/rollback commits" "$FIXTURE_DIR/agents-docs/dora-reports/2026-09.md"
}

@test "contains no mock placeholders" {
    run python3 "$GEN" --month 2026-09
    [ "$status" -eq 0 ]
    ! grep -q "Tasks Completed | 42" "$FIXTURE_DIR/agents-docs/dora-reports/2026-09.md"
    ! grep -q "Skill Invocations | 156" "$FIXTURE_DIR/agents-docs/dora-reports/2026-09.md"
}

@test "preserves analyst notes across regeneration" {
    printf '## Analyst Notes\nKeep this.\n' >> "$FIXTURE_DIR/agents-docs/dora-reports/2026-09.md"
    run python3 "$GEN" --month 2026-09
    [ "$status" -eq 0 ]
    grep -q "Keep this." "$FIXTURE_DIR/agents-docs/dora-reports/2026-09.md"
}

@test "empty month reports N/A instead of zeros-as-facts" {
    run python3 "$GEN" --month 2026-01
    [ "$status" -eq 0 ]
    grep -q "N/A (no merges in period)" "$FIXTURE_DIR/agents-docs/dora-reports/2026-01.md"
}
