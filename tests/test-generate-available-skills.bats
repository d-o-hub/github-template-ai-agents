#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$BATS_TMPDIR/github-template-ai-agents"
    export SKILLS_DIR="$REPO_ROOT/.agents/skills"
    export OUTPUT_FILE="$REPO_ROOT/agents-docs/AVAILABLE_SKILLS.md"

    mkdir -p "$SKILLS_DIR/skill1"
    mkdir -p "$SKILLS_DIR/_hidden-skill"
    mkdir -p "$REPO_ROOT/agents-docs"

    cat << 'FRONTMATTER' > "$SKILLS_DIR/skill1/SKILL.md"
---
name: "Skill 1"
description: "Description 1"
category: "general"
---
FRONTMATTER

    cat << 'FRONTMATTER' > "$SKILLS_DIR/_hidden-skill/SKILL.md"
---
name: "Hidden Skill"
description: "Hidden Description"
category: "hidden"
---
FRONTMATTER
}

teardown() {
    rm -rf "$REPO_ROOT"
}

@test "generate-available-skills.sh ignores directories starting with underscore" {
    # Run the script with REPO_ROOT overridden
    run bash "$BATS_TEST_DIRNAME/../scripts/generate-available-skills.sh"

    [ "$status" -eq 0 ]
    [ -f "$OUTPUT_FILE" ]

    # Check that skill1 is included
    run grep -q "\`Skill 1\`" "$OUTPUT_FILE"
    [ "$status" -eq 0 ]

    # Check that _hidden-skill is ignored
    run grep -q "\`Hidden Skill\`" "$OUTPUT_FILE"
    [ "$status" -eq 1 ]
}

@test "generate-available-skills.sh handles no skills gracefully" {
    rm -rf "$SKILLS_DIR/skill1"

    run bash "$BATS_TEST_DIRNAME/../scripts/generate-available-skills.sh"

    [ "$status" -eq 0 ]
    [ -f "$OUTPUT_FILE" ]

    # Ensure file has header but no skills
    run grep -q "## Usage" "$OUTPUT_FILE"
    [ "$status" -eq 0 ]
    run grep -q "Hidden Skill" "$OUTPUT_FILE"
    [ "$status" -eq 1 ]
}
