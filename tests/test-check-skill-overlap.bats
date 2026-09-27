#!/usr/bin/env bats
# Tests for scripts/check-skill-overlap.sh (Tier-2 keyless overlap gate).

setup() {
    FIXTURE_DIR="$(mktemp -d)"
    mkdir -p "$FIXTURE_DIR/skill-alpha" "$FIXTURE_DIR/skill-beta" "$FIXTURE_DIR/skill-gamma"
    # alpha and beta share a large verbatim block (must flag).
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

@test "advisory default exits 0 even with findings" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04
    [ "$status" -eq 0 ]
}

@test "--strict exits 1 when pairs found" {
    run ./scripts/check-skill-overlap.sh --skills-dir "$FIXTURE_DIR" --threshold 0.04 --strict
    [ "$status" -eq 1 ]
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

@test "known corpus duplicate triz pair is flagged" {
    run ./scripts/check-skill-overlap.sh --threshold 0.04
    [ "$status" -eq 0 ]
    [[ "$output" == *"triz-analysis"* ]]
    [[ "$output" == *"triz-solver"* ]]
}
