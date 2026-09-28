#!/usr/bin/env bats
# Tests for scripts/check-skill-overlap.sh (Tier-2 keyless overlap gate).
#
# Threshold convention in this suite:
#   * "default"  = the shipped THRESHOLD (0.50), exercised by OMITTING
#                  --threshold. Used against the fixture to prove the default
#                  catches true verbatim duplication, and against the real
#                  corpus to prove the default does not invent findings.
#   * "explicit" = a deliberate --threshold override, proving the flag path.
#                  0.04 stands in for "a caller with a stricter opinion";
#                  0.99 for "unreachable".
# Never assume the real corpus has findings: it does not. The 54-skill / 1431-pair
# catalog has a noise floor of 0.0267 (shared template boilerplate) and no
# verbatim duplication, so the default threshold is silent by design.

setup() {
    FIXTURE_DIR="$(mktemp -d)"
    mkdir -p "$FIXTURE_DIR/skill-alpha" "$FIXTURE_DIR/skill-beta" "$FIXTURE_DIR/skill-gamma"
    # alpha and beta share a large verbatim block (scores 0.9556, must flag).
    dup_block="Assess risk first. Critical paths demand review. Public APIs need scrutiny. Security-sensitive areas require care. Style compliance matters. Best practices guide structure. Test coverage verifies change. Documentation records intent. Repeat to raise the shingle mass substantially for the pair under test here."
    printf '# Alpha\n\n%s\n' "$dup_block $dup_block $dup_block" > "$FIXTURE_DIR/skill-alpha/SKILL.md"
    printf '# Beta\n\n%s\n' "$dup_block $dup_block $dup_block" > "$FIXTURE_DIR/skill-beta/SKILL.md"
    # gamma is disjoint (must stay clean).
    printf '# Gamma\n\nCompletely unrelated content about baking sourdough bread with hydration ratios.\n' > "$FIXTURE_DIR/skill-gamma/SKILL.md"
    export FIXTURE_DIR
}

teardown() {
    rm -rf "$FIXTURE_DIR"
}

@test "flags verbatim-duplicate pair in text output" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04
    [ "$status" -eq 0 ]
    [[ "$output" == *"skill-alpha"* ]]
    [[ "$output" == *"skill-beta"* ]]
}

@test "disjoint skill stays clean" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04
    [ "$status" -eq 0 ]
    [[ "$output" != *"skill-gamma"* ]]
}

@test "advisory mode exits 0 with findings at an explicit threshold" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04
    [ "$status" -eq 0 ]
    [[ "$output" == *"skill-alpha"* ]]
}

@test "--strict exits 1 when pairs found" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04 --strict
    [ "$status" -eq 1 ]
    # Guard the gate against passing for the wrong reason: a NameError traceback
    # also exits 1. Without this, the missing `import sys` shipped green.
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"NameError"* ]]
}

@test "--strict exits 0 when clean at high threshold" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.99 --strict
    [ "$status" -eq 0 ]
    [[ "$output" == *"No skill pairs"* ]]
}

@test "json format reports threshold and pairs" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04 --format json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"pairs"'* ]]
    [[ "$output" == *'"skill-alpha"'* ]]
}

@test "default threshold catches the fixture verbatim duplicate" {
    # No --threshold: proves the shipped default is low enough to catch true
    # verbatim duplication (0.9556), not merely an explicit override.
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"OVERLAP 0.9556 skill-alpha skill-beta"* ]]
}

@test "default threshold with --strict gates the fixture duplicate" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --strict
    [ "$status" -eq 1 ]
    [[ "$output" == *"skill-alpha"* ]]
    [[ "$output" == *"skill-beta"* ]]
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"NameError"* ]]
}

@test "default threshold stays above the observed corpus noise floor" {
    # Anti-regression guard against setting the default INSIDE the noise floor.
    # 5-gram Jaccard over the live catalog tops out near 0.027, and that top
    # band is shared template boilerplate ("Use this skill when...",
    # "## Rationalizations", "## Red Flags", "Not for X") -- not semantic
    # overlap. A default at or below the corpus maximum reports pure noise as
    # findings and invites bogus merge/consolidation decisions; a 0.02 default
    # did exactly that, flagging 13 false positives.
    #
    # Robust to corpus changes: nothing is hardcoded. The corpus maximum is read
    # back from `--threshold 0`, so a re-calibration only has to move the
    # default, never this assertion. If this ever fails, a real verbatim
    # duplicate has entered the catalog -- fix the duplicate, not the guard.
    run ./scripts/check-skill-overlap.sh --format json
    [ "$status" -eq 0 ]
    default_json="$output"
    [[ "$default_json" == *'"threshold"'* ]]

    run ./scripts/check-skill-overlap.sh --threshold 0 --format json
    [ "$status" -eq 0 ]
    corpus_json="$output"
    [[ "$corpus_json" == *'"pairs"'* ]]

    default_threshold="$(
        printf '%s' "$default_json" |
            python3 -c 'import json,sys; print(json.load(sys.stdin)["threshold"])'
    )"
    corpus_max="$(
        printf '%s' "$corpus_json" |
            python3 -c 'import json,sys; print(max(p["score"] for p in json.load(sys.stdin)["pairs"]))'
    )"
    [ -n "$default_threshold" ]
    [ -n "$corpus_max" ]

    # Strictly greater: a default equal to the corpus max would re-flag noise.
    python3 -c 'import sys; sys.exit(0 if float(sys.argv[1]) > float(sys.argv[2]) else 1)' \
        "$default_threshold" "$corpus_max"
}

@test "default threshold reports the real corpus as clean" {
    # The corpus has no verbatim duplication, so the default must stay silent.
    run ./scripts/check-skill-overlap.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"No skill pairs"* ]]
}

@test "--strict exits 0 on the real corpus at the default threshold" {
    run ./scripts/check-skill-overlap.sh --strict
    [ "$status" -eq 0 ]
    [[ "$output" == *"No skill pairs"* ]]
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"NameError"* ]]
}

@test "advisory default and --strict agree on findings" {
    # Run against the fixture, which does hold a verbatim duplicate. The real
    # corpus is clean at the default threshold and so cannot exercise agreement.
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04
    advisory_status="$status"
    advisory_output="$output"
    [ "$advisory_status" -eq 0 ]
    [[ "$advisory_output" == *"skill-alpha"* ]]

    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04 --strict
    [ "$status" -eq 1 ]
    [[ "$output" != *"Traceback"* ]]
    [[ "$output" != *"NameError"* ]]
    # Identical findings in both modes; only the exit code differs.
    [ "$output" = "$advisory_output" ]
}
