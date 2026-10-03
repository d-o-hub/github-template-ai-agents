#!/usr/bin/env bats
# Tests for the evals[].files existence check in scripts/eval-skills.sh
#
# Four skills named fixture paths that were never committed: "src/routes/admin.ts",
# "migrations/20260101_add_settings.sql", "pyproject.toml", "src/db.py". Nothing
# verified they existed, so scripts/run-evals.py reported them as missing inputs and
# the catalogue reported 11 failures indistinguishable from real regressions.
#
# The agentskills.io / NVIDIA SkillEvaluator convention is that files[] names input
# fixtures relative to the skill root, staged into the eval workspace -- so the path
# is supposed to resolve. This suite pins that resolution.
#
# The sandbox has to be structurally clean: eval-skills.sh runs under `set -e` and
# aborts at check_structure.py before reaching the files[] check if any skill is
# NEEDS_WORK. Every skill in the sandbox therefore needs a SKILL.md, and every
# skill with an evals/ directory needs at least two eval cases.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    # eval-skills.sh derives the skills dir from its own location, so the sandbox
    # has to look like a repo root.
    SANDBOX="$(mktemp -d /tmp/eval-skills-XXXXXX)"
    mkdir -p "$SANDBOX/scripts"
    cp "$REPO_ROOT/scripts/eval-skills.sh" "$SANDBOX/scripts/"
    SCRIPT="$SANDBOX/scripts/eval-skills.sh"
    SKILLS="$SANDBOX/.agents/skills"

    # eval-skills.sh requires the structural checker to live in the tree it audits.
    mkdir -p "$SKILLS/skill-evaluator/scripts"
    cp "$REPO_ROOT/.agents/skills/skill-evaluator/scripts/check_structure.py" \
        "$SKILLS/skill-evaluator/scripts/"
    printf '# Skill Evaluator\n' > "$SKILLS/skill-evaluator/SKILL.md"

    mkdir -p "$SKILLS/example-skill/evals/files" "$SKILLS/example-skill/references"
    printf '# Example\n\n## Rationalizations\n\nBecause.\n\n## Red Flags\n\nDo not.\n' \
        > "$SKILLS/example-skill/SKILL.md"
    printf 'notes\n' > "$SKILLS/example-skill/references/notes.md"
}

teardown() {
    rm -rf "$SANDBOX"
}

# Writes a three-case evals.json; $1 becomes the files[] of case id 1.
write_evals() {
    cat > "$SKILLS/example-skill/evals/evals.json" <<EOF
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "Do the thing",
      "expected_output": "The thing is done",
      "files": $1,
      "assertions": ["It happened"]
    },
    {
      "id": 2,
      "prompt": "Do the other thing",
      "expected_output": "The other thing is done",
      "files": [],
      "assertions": ["It happened"]
    },
    {
      "id": 3,
      "prompt": "Explain the thing",
      "expected_output": "The thing is explained",
      "files": [],
      "assertions": ["It was explained"]
    }
  ]
}
EOF
}

@test "passes when files[] is empty" {
    write_evals '[]'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "passes when files[] names a committed fixture" {
    printf 'sample\n' > "$SKILLS/example-skill/evals/files/sample.md"
    write_evals '["evals/files/sample.md"]'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "fails when files[] names a fixture that does not exist" {
    write_evals '["evals/files/missing.md"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing.md"* ]]
}

@test "reports the skill and eval id of the dangling fixture" {
    write_evals '["evals/files/missing.md"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"example-skill"* ]]
    [[ "$output" == *"eval #1"* ]]
}

@test "fails when only one of several fixtures is missing" {
    printf 'a\n' > "$SKILLS/example-skill/evals/files/present.md"
    write_evals '["evals/files/present.md", "evals/files/absent.md"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"absent.md"* ]]
    [[ "$output" != *"present.md"* ]]
}

@test "the gate checks existence, not location" {
    # The four skills that broke named paths like "src/db.py" at the skill root.
    # The contract is "the path must exist", matching how run_file_validation
    # resolves it, so a real file in that same wrong place does resolve. Keeping
    # fixtures under evals/files/ is documented guidance in skill-creator's
    # references/schemas.md rather than an enforced rule -- enforcing location
    # would break any skill whose fixture legitimately sits elsewhere.
    mkdir -p "$SKILLS/example-skill/src"
    printf 'db\n' > "$SKILLS/example-skill/src/db.py"
    write_evals '["src/db.py"]'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "a directory does not satisfy a files[] entry" {
    mkdir -p "$SKILLS/example-skill/evals/files/adir"
    write_evals '["evals/files/adir"]'
    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"adir"* ]]
}

@test "the live repository passes its own check" {
    run bash "$REPO_ROOT/scripts/eval-skills.sh"
    [ "$status" -eq 0 ]
}