#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$BATS_TMPDIR/github-template-ai-agents"
    export SKILLS_DIR="$REPO_ROOT/.agents/skills"
    export OUTPUT_FILE="$REPO_ROOT/agents-docs/skills-reference.md"

    mkdir -p "$SKILLS_DIR/skill1" "$SKILLS_DIR/skill2" "$SKILLS_DIR/_hidden"
    mkdir -p "$REPO_ROOT/agents-docs"

    cat <<'FRONTMATTER' > "$SKILLS_DIR/skill1/SKILL.md"
---
name: "skill-one"
description: "First skill"
category: "general"
---
FRONTMATTER

    cat <<'FRONTMATTER' > "$SKILLS_DIR/skill2/SKILL.md"
---
name: skill-two
description: >
  Multi-line description that spans
  several lines for testing.
category: code-quality
---
FRONTMATTER

    cat <<'FRONTMATTER' > "$SKILLS_DIR/_hidden/SKILL.md"
---
name: "hidden"
description: "Should not appear"
category: "ignored"
---
FRONTMATTER
}

teardown() {
    rm -rf "$REPO_ROOT"
}

@test "generate-skills-reference.sh excludes underscore-prefixed dirs" {
    run bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh"

    [ "$status" -eq 0 ]
    [ -f "$OUTPUT_FILE" ]

    run grep -q '`skill-one`' "$OUTPUT_FILE"
    [ "$status" -eq 0 ]

    run grep -q '`hidden`' "$OUTPUT_FILE"
    [ "$status" -eq 1 ]
}

@test "generate-skills-reference.sh handles YAML block-scalar descriptions" {
    run bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh"

    [ "$status" -eq 0 ]
    run grep -q 'Multi-line description' "$OUTPUT_FILE"
    [ "$status" -eq 0 ]
}

@test "generate-skills-reference.sh --check exits 0 when file is up to date" {
    bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh"
    run bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh" --check
    [ "$status" -eq 0 ]
}

@test "generate-skills-reference.sh --check exits 1 when file is stale" {
    cat <<'EOF' > "$OUTPUT_FILE"
# stale
EOF
    run bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh" --check
    [ "$status" -eq 1 ]
}

@test "generate-skills-reference.sh output is locale-independent" {
    local c_output utf_output
    bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh"
    cp "$OUTPUT_FILE" "$OUTPUT_FILE.c"
    rm -f "$OUTPUT_FILE"

    LC_ALL=en_US.UTF-8 bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh"

    diff -q "$OUTPUT_FILE.c" "$OUTPUT_FILE"
    rm -f "$OUTPUT_FILE.c"
}

@test "generate-skills-reference.sh rejects paths starting with a dash" {
    SKILLS_DIR="-evil" run bash "$BATS_TEST_DIRNAME/../scripts/generate-skills-reference.sh"
    [ "$status" -eq 2 ]
}
