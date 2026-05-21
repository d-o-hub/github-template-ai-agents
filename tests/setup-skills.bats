#!/usr/bin/env bats
# Tests for scripts/setup-skills.sh
# Covers printf-based output, mkdir -p --, and ln -s -- changes from PR

setup_file() {
    export REPO_ROOT_ORIGINAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SETUP_SKILLS_SCRIPT="$REPO_ROOT_ORIGINAL/scripts/setup-skills.sh"
}

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR

    # Build a fake repo layout in the temp dir
    mkdir -p "$TEST_TMPDIR/scripts"
    cp "$SETUP_SKILLS_SCRIPT" "$TEST_TMPDIR/scripts/setup-skills.sh"
    chmod +x "$TEST_TMPDIR/scripts/setup-skills.sh"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Helper: create a minimal .agents/skills/<name>/ directory
# ---------------------------------------------------------------------------
make_skill_dir() {
    local name="$1"
    mkdir -p "$TEST_TMPDIR/.agents/skills/$name"
    touch "$TEST_TMPDIR/.agents/skills/$name/SKILL.md"
}

# ---------------------------------------------------------------------------
# 1. printf when no .agents/skills/ directory exists
# ---------------------------------------------------------------------------
@test "setup-skills.sh: printf message when .agents/skills/ does not exist" {
    # Do NOT create .agents/skills/
    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "No skills found at .agents/skills/" ]]
    [[ "$output" =~ "nothing to symlink" ]]
}

# ---------------------------------------------------------------------------
# 2. printf "Setting up skill symlinks" when source dir exists
# ---------------------------------------------------------------------------
@test "setup-skills.sh: printf setup message when .agents/skills/ exists" {
    mkdir -p "$TEST_TMPDIR/.agents/skills"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Setting up skill symlinks from .agents/skills/..." ]]
}

# ---------------------------------------------------------------------------
# 3. printf "linked: %s/%s -> %s" when creating a new symlink
# ---------------------------------------------------------------------------
@test "setup-skills.sh: printf linked message for new symlink" {
    make_skill_dir "alpha-skill"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "linked:" ]]
    [[ "$output" =~ "alpha-skill" ]]
}

# ---------------------------------------------------------------------------
# 4. Symlinks are actually created in expected CLI directories
# ---------------------------------------------------------------------------
@test "setup-skills.sh: creates symlinks in .claude/skills and .qwen/skills" {
    make_skill_dir "my-skill"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [ -L "$TEST_TMPDIR/.claude/skills/my-skill" ]
    [ -L "$TEST_TMPDIR/.qwen/skills/my-skill" ]
}

# ---------------------------------------------------------------------------
# 5. printf "skip (exists)" when symlink already present
# ---------------------------------------------------------------------------
@test "setup-skills.sh: printf skip message when symlink already exists" {
    make_skill_dir "existing-skill"

    # Run once to create symlinks
    bash "$TEST_TMPDIR/scripts/setup-skills.sh" > /dev/null 2>&1

    # Run a second time — should skip
    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "skip (exists):" ]]
    [[ "$output" =~ "existing-skill" ]]
}

# ---------------------------------------------------------------------------
# 6. printf "WARN: real dir exists" when a non-symlink directory is present
# ---------------------------------------------------------------------------
@test "setup-skills.sh: printf WARN when a real directory occupies the link path" {
    make_skill_dir "conflict-skill"

    # Create a real (non-symlink) directory where the symlink would go
    mkdir -p "$TEST_TMPDIR/.claude/skills/conflict-skill"
    mkdir -p "$TEST_TMPDIR/.qwen/skills/conflict-skill"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "WARN: real dir exists at" ]]
    [[ "$output" =~ "conflict-skill" ]]
    [[ "$output" =~ "skipping" ]]
}

# ---------------------------------------------------------------------------
# 7. printf final summary messages
# ---------------------------------------------------------------------------
@test "setup-skills.sh: printf final 'Skill symlinks created' message" {
    mkdir -p "$TEST_TMPDIR/.agents/skills"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skill symlinks created." ]]
    [[ "$output" =~ "validate-skills.sh" ]]
}

# ---------------------------------------------------------------------------
# 8. mkdir -p -- handles target dir path safely (no option injection)
# ---------------------------------------------------------------------------
@test "setup-skills.sh: mkdir -p -- creates target directories correctly" {
    make_skill_dir "safe-skill"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [ -d "$TEST_TMPDIR/.claude/skills" ]
    [ -d "$TEST_TMPDIR/.qwen/skills" ]
}

# ---------------------------------------------------------------------------
# 9. ln -s -- creates a relative symlink that resolves correctly
# ---------------------------------------------------------------------------
@test "setup-skills.sh: created symlink resolves to correct skill directory" {
    make_skill_dir "resolve-skill"
    echo "test content" > "$TEST_TMPDIR/.agents/skills/resolve-skill/SKILL.md"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]

    # Follow the symlink and check the file is accessible
    [ -f "$TEST_TMPDIR/.claude/skills/resolve-skill/SKILL.md" ]
    run cat "$TEST_TMPDIR/.claude/skills/resolve-skill/SKILL.md"
    [[ "$output" =~ "test content" ]]
}

# ---------------------------------------------------------------------------
# 10. Multiple skills — all linked, output contains each name
# ---------------------------------------------------------------------------
@test "setup-skills.sh: handles multiple skill directories" {
    make_skill_dir "skill-one"
    make_skill_dir "skill-two"
    make_skill_dir "skill-three"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "skill-one" ]]
    [[ "$output" =~ "skill-two" ]]
    [[ "$output" =~ "skill-three" ]]
}

# ---------------------------------------------------------------------------
# 11. Output format: "linked: <cli_dir>/<skill_name> -> <rel>" with actual path
# ---------------------------------------------------------------------------
@test "setup-skills.sh: linked message contains cli_dir and skill_name in correct format" {
    make_skill_dir "format-skill"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    # Output should contain the path separator in the linked line
    [[ "$output" =~ ".claude/skills/format-skill" ]] || \
    [[ "$output" =~ ".qwen/skills/format-skill" ]]
}

# ---------------------------------------------------------------------------
# 12. Skill dirs starting with _ are NOT excluded by setup-skills.sh
#     (only validate-skill-format.sh skips _ dirs; setup-skills.sh links all)
# ---------------------------------------------------------------------------
@test "setup-skills.sh: symlinks all skill dirs including those starting with underscore" {
    make_skill_dir "_template-skill"

    run bash "$TEST_TMPDIR/scripts/setup-skills.sh"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "_template-skill" ]]
}