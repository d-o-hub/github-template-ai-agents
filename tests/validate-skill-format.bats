#!/usr/bin/env bats
# Tests for scripts/validate-skill-format.sh
# Covers the printf "[OK]" output change and SKILL_LINE_COUNT usage from PR

setup_file() {
    export REPO_ROOT_ORIGINAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export VALIDATE_SCRIPT="$REPO_ROOT_ORIGINAL/scripts/validate-skill-format.sh"
}

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR

    # Set up a fake repo with scripts and lib so the script can source the library
    mkdir -p "$TEST_TMPDIR/scripts/lib"
    cp "$REPO_ROOT_ORIGINAL/scripts/validate-skill-format.sh" "$TEST_TMPDIR/scripts/"
    cp "$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh" "$TEST_TMPDIR/scripts/lib/"
    chmod +x "$TEST_TMPDIR/scripts/validate-skill-format.sh"

    # Create .agents/skills/ so the script has something to iterate over
    mkdir -p "$TEST_TMPDIR/.agents/skills"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Helper: make a minimal valid skill dir
# ---------------------------------------------------------------------------
make_valid_skill() {
    local name="$1"
    mkdir -p "$TEST_TMPDIR/.agents/skills/$name"
    cat > "$TEST_TMPDIR/.agents/skills/$name/SKILL.md" << 'EOF'
---
name: test-skill
description: A test skill description
version: 1.0.0
EOF
}

# ---------------------------------------------------------------------------
# Helper: make an invalid skill dir (missing description)
# ---------------------------------------------------------------------------
make_invalid_skill() {
    local name="$1"
    mkdir -p "$TEST_TMPDIR/.agents/skills/$name"
    cat > "$TEST_TMPDIR/.agents/skills/$name/SKILL.md" << 'EOF'
---
name: bad-skill
version: 1.0.0
EOF
}

# ---------------------------------------------------------------------------
# 1. printf "[OK]" line for a valid skill — uses %b for color codes
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: prints [OK] with skill name and line count for valid skill" {
    make_valid_skill "good-skill"

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "[OK]" ]]
    [[ "$output" =~ "good-skill" ]]
    [[ "$output" =~ "Valid" ]]
    [[ "$output" =~ "lines" ]]
}

# ---------------------------------------------------------------------------
# 2. Line count in [OK] message matches actual file size
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: [OK] message includes correct line count" {
    make_valid_skill "counted-skill"
    local expected_lines
    expected_lines=$(wc -l < "$TEST_TMPDIR/.agents/skills/counted-skill/SKILL.md")

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "${expected_lines} lines" ]]
}

# ---------------------------------------------------------------------------
# 3. Script exits 0 when all skills pass
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: exits 0 when all skills are valid" {
    make_valid_skill "skill-a"
    make_valid_skill "skill-b"

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 4. Script exits 1 when a skill is invalid
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: exits 1 when a skill fails validation" {
    make_invalid_skill "bad-skill"

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# 5. Error count reported in summary for invalid skills
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: reports error count in summary" {
    make_invalid_skill "fail-skill"

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'" 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "skill(s) with errors" ]] || [[ "$output" =~ "errors" ]]
}

# ---------------------------------------------------------------------------
# 6. Skills prefixed with _ are skipped
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: skips skill directories starting with underscore" {
    # Only add an underscore-prefixed skill; no valid skills present
    mkdir -p "$TEST_TMPDIR/.agents/skills/_template"
    cat > "$TEST_TMPDIR/.agents/skills/_template/SKILL.md" << 'EOF'
---
name: _template
description: Template skill
version: 1.0.0
EOF

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    # Script should succeed (nothing to validate) and NOT mention _template
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "_template" ]] || [[ "$output" =~ "All SKILL.md files passed" ]]
}

# ---------------------------------------------------------------------------
# 7. Mixed valid and invalid skills — only invalid increments error count
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: counts only invalid skills in error tally" {
    make_valid_skill "ok-skill"
    make_invalid_skill "bad-skill"

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'" 2>&1

    [ "$status" -ne 0 ]
    # Valid skill should show [OK]; invalid should NOT
    [[ "$output" =~ "[OK]" ]]
    [[ "$output" =~ "ok-skill" ]]
}

# ---------------------------------------------------------------------------
# 8. "All SKILL.md files passed validation" message when no errors
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: prints success message when no errors" {
    make_valid_skill "perfect-skill"

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "All SKILL.md files passed validation" ]]
}

# ---------------------------------------------------------------------------
# 9. Empty skills directory — exits 0 with success message
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: exits 0 with empty skills directory" {
    # .agents/skills/ exists but has no subdirectories

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# 10. SKILL_LINE_COUNT used correctly — line count in [OK] is numeric
# ---------------------------------------------------------------------------
@test "validate-skill-format.sh: [OK] line count is a positive integer" {
    make_valid_skill "numeric-skill"

    run bash -c "cd '$TEST_TMPDIR' && REPO_ROOT='$TEST_TMPDIR' bash '$TEST_TMPDIR/scripts/validate-skill-format.sh'"

    [ "$status" -eq 0 ]
    # Extract the number before "lines" from the [OK] line
    ok_line=$(echo "$output" | grep '\[OK\]')
    line_count=$(echo "$ok_line" | grep -oE '[0-9]+ lines' | grep -oE '[0-9]+')
    [ -n "$line_count" ]
    [ "$line_count" -gt 0 ]
}
