#!/usr/bin/env bats
# Regression net for tests/test-core-skills-compliance.sh
#
# The suite generates a DORA report at a path derived from the current month, and that path is
# a tracked file in this repository (`agents-docs/dora-reports/YYYY-MM.md`). It used to `rm -f`
# that file before and after generating, so a local run deleted committed work and left the
# tree dirty. CI's disposable checkout hides the defect, which is why these tests build a
# throwaway git repo and assert the working tree afterwards.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# make_sandbox — a committed git repo holding just what the suite inspects: four SKILL.md
# files with X.Y.Z versions, dora-report evals, the real generator, and the suite itself.
make_sandbox() {
    root="$BATS_TEST_TMPDIR/sandbox"
    rm -rf "$root"
    mkdir -p "$root/tests" "$root/agents-docs/dora-reports"
    for skill in avoid-ai-writing skill-creator skill-evaluator dora-report; do
        mkdir -p "$root/.agents/skills/$skill"
        printf -- '---\nname: %s\nversion: "1.0.0"\n---\n# %s\n' "$skill" "$skill" \
            > "$root/.agents/skills/$skill/SKILL.md"
    done
    mkdir -p "$root/.agents/skills/dora-report/evals" "$root/.agents/skills/dora-report/scripts"
    printf '{"evals": [{"id": 1}, {"id": 2}, {"id": 3}]}\n' \
        > "$root/.agents/skills/dora-report/evals/evals.json"
    cp "$REPO_ROOT/.agents/skills/dora-report/scripts/generate_report.py" \
        "$root/.agents/skills/dora-report/scripts/generate_report.py"
    cp "$REPO_ROOT/tests/test-core-skills-compliance.sh" "$root/tests/"
    git -C "$root" init -q
    git -C "$root" config user.email "test@example.com"
    git -C "$root" config user.name "Test"
    printf '%s' "$root"
}

commit_tree() {
    git -C "$1" add -A
    git -C "$1" commit -qm "fixture"
}

@test "the suite runs its checks in a sandbox repo" {
    root=$(make_sandbox)
    commit_tree "$root"

    run bash "$root/tests/test-core-skills-compliance.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"dora-report has 3 eval cases"* ]]
    [[ "$output" == *"Monthly report generated"* ]]
}

@test "a run leaves no working-tree changes behind" {
    root=$(make_sandbox)
    printf '# Report\n\ncommitted content\n' > "$root/agents-docs/dora-reports/$(date +%Y-%m).md"
    commit_tree "$root"

    run bash "$root/tests/test-core-skills-compliance.sh"

    [ "$status" -eq 0 ]
    # The HEAD version of the suite deleted the tracked report, so this was never clean.
    [ -z "$(git -C "$root" status --porcelain)" ]
}

@test "the tracked current-month report survives a run byte for byte" {
    root=$(make_sandbox)
    report="$root/agents-docs/dora-reports/$(date +%Y-%m).md"
    printf '# Report\n\nhand-written analyst notes\n' > "$report"
    cp "$report" "$BATS_TEST_TMPDIR/expected.md"
    commit_tree "$root"

    run bash "$root/tests/test-core-skills-compliance.sh"

    [ "$status" -eq 0 ]
    cmp "$BATS_TEST_TMPDIR/expected.md" "$report"
}

@test "no report file is left behind when none existed beforehand" {
    root=$(make_sandbox)
    commit_tree "$root"

    run bash "$root/tests/test-core-skills-compliance.sh"

    [ "$status" -eq 0 ]
    [ ! -e "$root/agents-docs/dora-reports/$(date +%Y-%m).md" ]
    [ -z "$(git -C "$root" status --porcelain)" ]
}

@test "a generator that writes nothing still fails the suite" {
    root=$(make_sandbox)
    printf '# Report\n\ncommitted content\n' > "$root/agents-docs/dora-reports/$(date +%Y-%m).md"
    commit_tree "$root"
    # The suite asserts the report exists; a stub that produces nothing must not pass, otherwise
    # the whole check is vacuous and would hide the very failure it exists to catch. Commit the
    # stub first, or the sabotage itself shows up as a working-tree change.
    printf 'import sys\nsys.exit(0)\n' > "$root/.agents/skills/dora-report/scripts/generate_report.py"
    commit_tree "$root"

    run bash "$root/tests/test-core-skills-compliance.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Monthly report NOT generated"* ]]
    # Failure must still restore the tracked file.
    [ -z "$(git -C "$root" status --porcelain)" ]
}
