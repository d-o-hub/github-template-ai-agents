#!/usr/bin/env bats
# BATS tests for scripts/check-cli-parity.sh
#
# Each test builds a minimal three-CLI tree (.claude, .opencode, .gemini) in a
# throwaway sandbox and drives the drift scenarios against a test-controlled
# allowlist: clean parity, unsanctioned drift, sanctioned exclusions, missing
# commands dirs (fail-closed input), optional agent dirs, stale/duplicate/
# malformed allowlist rows, and format dedup.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SANDBOX="$(mktemp -d)"
    mkdir -p "$SANDBOX/scripts/lib"
    cp "$REPO_ROOT/scripts/check-cli-parity.sh" "$SANDBOX/scripts/"
    SCRIPT="$SANDBOX/scripts/check-cli-parity.sh"
    ALLOWLIST="$SANDBOX/scripts/lib/cli-parity-allowlist.tsv"
}

teardown() {
    [[ -n "${SANDBOX:-}" ]] && rm -rf -- "$SANDBOX"
    return 0
}

# Write definitions for one CLI's commands (or agents) surface: gemini names
# carry .toml, claude/opencode carry .md, exactly as the real tree does.
add_definitions() {
    local surface="$1" cli="$2" ext="md"
    shift 2
    [[ "$cli" == "gemini" ]] && ext="toml"
    local dir="$SANDBOX/.$cli/$surface"
    local name
    mkdir -p "$dir"
    for name in "$@"; do
        printf 'definition\n' > "$dir/$name.$ext"
    done
}

allowlist_write() {
    # %b so tests can write real tabs with \t.
    printf '%b' "$1" > "$ALLOWLIST"
}

@test "passes when every CLI defines the same commands" {
    add_definitions commands claude commit deploy
    add_definitions commands opencode commit deploy
    add_definitions commands gemini commit deploy
    allowlist_write '# no sanctioned exclusions\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"commands: claude=2 opencode=2 gemini=2 (union=2)"* ]]
    [[ "$output" == *"✓ no unsanctioned drift"* ]]
}

@test "flags a command missing from one CLI" {
    add_definitions commands claude commit deploy
    add_definitions commands opencode commit deploy
    add_definitions commands gemini commit
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"command 'deploy' missing from: .gemini/commands (defined in: claude, opencode)"* ]]
    [[ "$output" == *"1 unsanctioned gap(s)"* ]]
}

@test "flags the gap in every CLI that lacks the name" {
    add_definitions commands claude commit refactor
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"command 'refactor' missing from: .opencode/commands, .gemini/commands (defined in: claude)"* ]]
    [[ "$output" == *"1 unsanctioned gap(s)"* ]]
}

@test "an allowlist row sanctions the exclusion" {
    add_definitions commands claude commit deploy
    add_definitions commands opencode commit deploy
    add_definitions commands gemini commit
    allowlist_write 'deploy\tgemini\tgemini routes deploy through its skill surface\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"allowlist: 1 sanctioned exclusion row(s), 1 currently applied"* ]]
}

@test "a missing allowlist fails closed instead of comparing unprotected" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"CLI parity allowlist missing"* ]]
    [[ "$output" == *"fail closed"* ]]
}

@test "a malformed allowlist row fails closed" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    allowlist_write 'deploy\tgemini\n'

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"malformed allowlist row 1"* ]]
    [[ "$output" == *"name<TAB>cli<TAB>reason"* ]]
}

@test "an allowlist row naming an unknown CLI fails closed" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    allowlist_write 'commit\tcursor\tcursor is not a tracked dialect\n'

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown CLI 'cursor'"* ]]
}

@test "the final allowlist row still counts without a trailing newline" {
    # check-skill-references.sh once dropped its last registry record this
    # way; the allowlist reader is pinned against the same bug class.
    add_definitions commands claude commit deploy
    add_definitions commands opencode commit deploy
    add_definitions commands gemini commit
    allowlist_write 'deploy\tgemini\tgemini routes deploy through its skill surface'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1 currently applied"* ]]
}

@test "a duplicate allowlist row warns and the first row wins" {
    add_definitions commands claude commit deploy
    add_definitions commands opencode commit deploy
    add_definitions commands gemini commit
    allowlist_write 'deploy\tgemini\tfirst reason\ndeploy\tgemini\tsecond reason\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"1 duplicate allowlist row(s) ignored (first wins)"* ]]
}

@test "a stale allowlist row is a visible warning, not a failure" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    allowlist_write 'ghost\tgemini\tnothing excludes this anywhere\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"stale allowlist row: ghost is not missing from gemini any more"* ]]
}

@test "a missing required commands dir fails closed" {
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"required command dir missing: .claude/commands"* ]]
    [[ "$output" == *"fail closed"* ]]
}

@test "agent dirs participate when present with their own counts" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    allowlist_write '# none\n'
    mkdir -p "$SANDBOX/.claude/agents" "$SANDBOX/.opencode/agents" "$SANDBOX/.gemini/agents"

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"agents: claude=0 opencode=0 gemini=0 (union=0)"* ]]
}

@test "no agent dirs at all skips the agent comparison visibly" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"no agent dirs present; comparison skipped"* ]]
}

@test "flags agent drift across CLIs that ship agent dirs" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    add_definitions agents claude loop
    add_definitions agents opencode loop
    # gemini ships an agent dir, but not this agent: that is drift, not a
    # missing input.
    mkdir -p "$SANDBOX/.gemini/agents"
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"agent 'loop' missing from: .gemini/agents (defined in: claude, opencode)"* ]]
}

@test "an allowlist row also sanctions an agent gap" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    add_definitions agents claude loop
    add_definitions agents opencode loop
    allowlist_write 'loop\tgemini\tgemini drives loops through /build instead of an agent\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"✓ no unsanctioned drift"* ]]
}

@test "empty-but-present agent dirs enroll a CLI in the agent comparison" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    add_definitions agents claude loop
    allowlist_write '# none\n'
    # Deleting an agent dir must not be a bypass: an empty-but-present dir
    # participates with an empty set, so the missing name flags it. Only a
    # CLI that never shipped the surface (dir absent) is exempt.
    mkdir -p "$SANDBOX/.opencode/agents" "$SANDBOX/.gemini/agents"

    run bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" == *"agent 'loop' missing from: .opencode/agents, .gemini/agents (defined in: claude)"* ]]
}

@test "a CLI without an agent dir is exempt when another CLI ships no such agent" {
    # Variant of the exemption: opencode ships agents, claude does not, and
    # the name exists only in opencode, so no participant lacks it.
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    add_definitions agents opencode loop
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"agents: opencode=1 (union=1)"* ]]
}

@test "a name defined twice in one CLI (md and toml) counts once" {
    add_definitions commands claude commit deploy
    add_definitions commands opencode commit deploy
    add_definitions commands gemini commit deploy
    printf 'definition\n' > "$SANDBOX/.claude/commands/deploy.toml"
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"commands: claude=2 opencode=2 gemini=2 (union=2)"* ]]
}

@test "bundle directories inside agents do not surface as agent names" {
    add_definitions commands claude commit
    add_definitions commands opencode commit
    add_definitions commands gemini commit
    add_definitions agents claude goap-agent
    add_definitions agents opencode goap-agent
    add_definitions agents gemini goap-agent
    # The .claude/agents/goap-agent/ bundle travels with the identically
    # named definition; its evals file must not become an extra name that
    # then flags the other CLIs.
    mkdir -p "$SANDBOX/.claude/agents/goap-agent/evals"
    printf '{}\n' > "$SANDBOX/.claude/agents/goap-agent/evals/evals.json"
    allowlist_write '# none\n'

    run bash "$SCRIPT"

    [ "$status" -eq 0 ]
    [[ "$output" == *"agents: claude=1 opencode=1 gemini=1 (union=1)"* ]]
    [[ "$output" != *"evals"* ]]
}
