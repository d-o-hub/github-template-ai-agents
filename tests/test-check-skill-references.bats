#!/usr/bin/env bats
# Tests for scripts/check-skill-references.sh
#
# Round 8's consolidation (ADR-038) deleted ten skill directories and left live
# routing pointing at them. LESSON-036 listed the doc locations a merge must
# touch but nothing verified them, which is how the references survived.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SANDBOX="$(mktemp -d /tmp/skill-refs-XXXXXX)"
    mkdir -p "$SANDBOX/scripts/lib" "$SANDBOX/.claude/agents" "$SANDBOX/.agents/skills/real-skill"
    cp "$REPO_ROOT/scripts/check-skill-references.sh" "$SANDBOX/scripts/"
    printf 'triz-analysis\ttriz-solver\tADR-038\n' > "$SANDBOX/scripts/lib/folded-skills.tsv"
    SCRIPT="$SANDBOX/scripts/check-skill-references.sh"
    printf -- '---\nname: real-skill\n---\n' > "$SANDBOX/.agents/skills/real-skill/SKILL.md"
}

teardown() {
    rm -rf "$SANDBOX"
}

@test "passes when no folded name is referenced" {
    printf -- '- **goap-agent**: plan\n' > "$SANDBOX/.claude/agents/agent.md"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "fails on a folded name in an agent config" {
    printf -- '- **triz-analysis**: plan\n' > "$SANDBOX/.claude/agents/agent.md"

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"folded skill 'triz-analysis'"* ]]
    [[ "$output" == *"use 'triz-solver'"* ]]
}

@test "exempts a line that documents the fold as history" {
    printf -- 'Watch mode (absorbed from `triz-analysis`).\n' > "$SANDBOX/.claude/agents/agent.md"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "exempts every provenance verb, not just one" {
    printf -- '- superseded by triz-analysis\n- merged from triz-analysis\n- renamed to triz-analysis\n' > "$SANDBOX/.claude/agents/agent.md"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "does not false-positive on a name that merely contains a folded name" {
    printf -- '- **my-triz-analysis-helper**: local tool\n' > "$SANDBOX/.claude/agents/agent.md"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "fails when the registry is missing rather than passing silently" {
    rm "$SANDBOX/scripts/lib/folded-skills.tsv"

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"registry not found"* ]]
}

@test "fails when the registry is empty rather than passing silently" {
    : > "$SANDBOX/scripts/lib/folded-skills.tsv"

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"registry is empty"* ]]
}

@test "skips historical plan directories" {
    mkdir -p "$SANDBOX/plans"
    printf -- 'folded triz-analysis into triz-solver\n' > "$SANDBOX/plans/note.md"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}