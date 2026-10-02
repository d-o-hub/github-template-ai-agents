#!/usr/bin/env bats
# Tests for scripts/check-agents-md-skills.sh
#
# The AGENTS.md skill table is hand-curated by category, so the script checks
# names and never edits. These tests pin the three drift classes it reports
# and, just as importantly, that an unreadable table FAILS rather than passes.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    # The script derives REPO_ROOT from its own location, so the sandbox must
    # look like a repo root: <sandbox>/scripts/<script> above AGENTS.md.
    SANDBOX="$(mktemp -d /tmp/agents-md-check-XXXXXX)"
    mkdir -p "$SANDBOX/scripts" "$SANDBOX/.agents/skills"
    cp "$REPO_ROOT/scripts/check-agents-md-skills.sh" "$SANDBOX/scripts/"
    SCRIPT="$SANDBOX/scripts/check-agents-md-skills.sh"
}

teardown() {
    rm -rf "$SANDBOX"
}

make_skill() {
    mkdir -p "$SANDBOX/.agents/skills/$1"
    printf -- '---\nname: %s\ndescription: d\n---\n' "$1" > "$SANDBOX/.agents/skills/$1/SKILL.md"
}

write_agents() {
    printf '%s\n' "$@" > "$SANDBOX/AGENTS.md"
}

@test "checker passes when the table lists every catalog skill" {
    make_skill alpha
    make_skill beta
    write_agents '# Title' '' '## Skills' '' '| Category | Skills |' '|---|---|' '| **A** | `alpha`, `beta` |' '' '## Next' 'text'

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "checker fails when a catalog skill is absent from the table" {
    make_skill alpha
    make_skill beta
    write_agents '# Title' '' '## Skills' '' '| Category | Skills |' '|---|---|' '| **A** | `alpha` |'

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"beta exists"* ]]
}

@test "checker fails when the table lists a skill that no longer exists" {
    make_skill alpha
    write_agents '# Title' '' '## Skills' '' '| Category | Skills |' '|---|---|' '| **A** | `alpha`, `ghost` |'

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ghost is listed in AGENTS.md but no longer exists"* ]]
}

@test "checker fails when a skill is listed in two category rows" {
    make_skill triz
    write_agents '# Title' '' '## Skills' '' '| Category | Skills |' '|---|---|' '| **One** | `triz` |' '| **Two** | `triz` |'

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"listed 2 times"* ]]
}

@test "checker ignores a directory with no SKILL.md" {
    mkdir -p "$SANDBOX/.agents/skills/not-a-skill"
    make_skill alpha
    write_agents '# Title' '' '## Skills' '' '| Category | Skills |' '|---|---|' '| **A** | `alpha` |'

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "checker tolerates a description suffix on a name" {
    make_skill triz
    write_agents '# Title' '' '## Skills' '' '| Category | Skills |' '|---|---|' '| **A** | `triz` (solve + audit modes) |' '' '## Next'

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "checker fails when AGENTS.md has no Skills section (no false green)" {
    make_skill alpha
    write_agents '# Title' '' 'No section here.'

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not find"* ]]
}

@test "checker fails when the Skills section has no table rows (no false green)" {
    make_skill alpha
    write_agents '# Title' '' '## Skills' '' 'Just prose, no table.'

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "checker never modifies AGENTS.md" {
    make_skill alpha
    make_skill beta
    write_agents '# Title' '' '## Skills' '' '| Category | Skills |' '|---|---|' '| **A** | `alpha` |'
    cp "$SANDBOX/AGENTS.md" "$SANDBOX/AGENTS.md.before"

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    run diff "$SANDBOX/AGENTS.md.before" "$SANDBOX/AGENTS.md"
    [ "$status" -eq 0 ]
}