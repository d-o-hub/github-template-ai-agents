#!/usr/bin/env bats
# BATS tests for quality_gate.sh
#
# One gate pass costs ~30s, so the composite run happens exactly once per file, in
# setup_file, and every test below asserts against that saved transcript. The previous
# revision ran the whole gate per test (13 times) while asserting `[ "$status" -eq 0 ] ||
# [ "$status" -eq 2 ]` — accepting both outcomes, so no gate behaviour could fail it.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    GATE_OUT="$BATS_FILE_TMPDIR/gate.out"
    GATE_STATUS="$BATS_FILE_TMPDIR/gate.status"
    # `|| status=$?` because bats runs setup_file under errexit: a failing gate is data
    # here, not a setup error, and the tests decide what it means.
    status=0
    (cd "$REPO_ROOT" && ./scripts/quality_gate.sh) > "$GATE_OUT" 2>&1 || status=$?
    printf '%s\n' "$status" > "$GATE_STATUS"
    export GATE_OUT GATE_STATUS
}

setup() {
    cd "$REPO_ROOT" || exit 1
}

@test "quality_gate.sh exists and is executable" {
    [ -x "$REPO_ROOT/scripts/quality_gate.sh" ]
}

@test "gate exits with a code that matches the verdict it printed" {
    status=$(<"$GATE_STATUS")
    case "$status" in
        0) [[ "$(cat "$GATE_OUT")" == *"All Quality Gates PASSED"* ]] ;;
        2) [[ "$(cat "$GATE_OUT")" == *"Quality Gate FAILED"* ]] ;;
        1) [[ "$(cat "$GATE_OUT")" == *"drift on main branch"* ]] ;;
        *) return 1 ;;
    esac
}

@test "gate prints exactly one verdict banner" {
    # grep -c exits 1 on a zero count; the count is the contract, so do not
    # let a bare assignment abort the case when a crashed run prints no banner.
    banners=$(grep -cE "Quality Gates PASSED|Quality Gate FAILED" "$GATE_OUT" || true)
    [ "$banners" -eq 1 ]
}

@test "a failed check leaves a marker, a passing gate leaves none" {
    status=$(<"$GATE_STATUS")
    # Count the per-check markers, excluding the banner row itself.
    # The final grep exits 1 when nothing matched (a green recording has
    # zero markers); the count, not the exit code, is the contract.
    marks=$(grep -E "✗" "$GATE_OUT" | grep -vc "Quality Gate FAILED" || true)
    if [[ "$status" -eq 2 ]]; then
        [ "$marks" -gt 0 ]
    else
        [ "$marks" -eq 0 ]
    fi
}

@test "gate runs every check section it claims to own" {
    gate=$(cat "$GATE_OUT")
    for section in \
        "Running quality gate..." \
        "Validating git hooks configuration..." \
        "Checking LLM context files..." \
        "Validating GitHub Actions SHAs..." \
        "Validating GitHub Actions Workflows..." \
        "Validating cross-CLI command and agent parity..." \
        "Validating skills..." \
        "Checking skills-reference.md is up to date..." \
        "Validating reference links in SKILL.md files..." \
        "Validating commitlint configuration..." \
        "Enforcing LOC limits..." \
        "Validating forbidden paths..." \
        "Detecting project languages..." \
        "Running Shell script checks..."; do
        [[ "$gate" == *"$section"* ]] || { echo "missing section: $section" >&2; return 1; }
    done
}

@test "SKIP_GLOBAL_HOOKS_CHECK=true removes the hooks section the default run has" {
    [[ "$(cat "$GATE_OUT")" == *"Validating git hooks configuration..."* ]]
    run env SKIP_GLOBAL_HOOKS_CHECK=true ./scripts/quality_gate.sh
    [[ "$output" != *"Validating git hooks configuration..."* ]]
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ] || [ "$status" -eq 2 ]
}

@test "gate reaches a verdict in a project with no recognizable files" {
    TEMP_DIR=$(mktemp -d)
    OUT="$BATS_TEST_TMPDIR/empty-project-gate.out"
    mkdir -p "$TEMP_DIR/.agents/skills/test-skill" "$TEMP_DIR/scripts"
    printf -- '---\nname: test\ndescription: test skill\n---\n' \
        > "$TEMP_DIR/.agents/skills/test-skill/SKILL.md"
    cp -r "$REPO_ROOT/scripts/." "$TEMP_DIR/scripts/"
    chmod +x "$TEMP_DIR/scripts/"*.sh
    status=0
    (cd "$TEMP_DIR" && ./scripts/quality_gate.sh) > "$OUT" 2>&1 || status=$?
    rm -rf "$TEMP_DIR"
    # A verdict banner means the gate ran every section to the end; a crash mid-way would
    # exit with the same 0/2 by luck but print no summary.
    [[ "$(cat "$OUT")" == *"Quality Gates PASSED"* ]] || \
        [[ "$(cat "$OUT")" == *"Quality Gate FAILED"* ]]
    [ "$status" -eq 0 ] || [ "$status" -eq 2 ]
}
