#!/usr/bin/env bats
# Tests for scripts/lib/skill-validation.sh
# Covers printf-based output format and validation logic changed in PR

setup_file() {
    export REPO_ROOT_ORIGINAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

setup() {
    # Create an isolated temp directory for each test
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR

    # Provide a fake VERSION file so version checks are exercised
    echo "1.2.0" > "$TEST_TMPDIR/VERSION"

    # Copy the library into the temp dir under a lib/ subdir
    mkdir -p "$TEST_TMPDIR/lib"
    cp "$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh" "$TEST_TMPDIR/lib/"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Helper: create a minimal valid SKILL.md
# ---------------------------------------------------------------------------
make_valid_skill() {
    local skill_dir="$1"
    mkdir -p "$skill_dir"
    cat > "$skill_dir/SKILL.md" << 'EOF'
---
name: test-skill
description: A test skill for unit tests
version: 1.0.0
EOF
}

# ---------------------------------------------------------------------------
# 1. Missing SKILL.md — printf format for missing file
# ---------------------------------------------------------------------------
@test "validate_skill_file: printf 'Missing SKILL.md' to stderr when file absent" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/my-skill"
    # Do NOT create SKILL.md

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/my-skill/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "Missing SKILL.md" ]]
    [[ "$output" =~ "my-skill" ]]
}

# ---------------------------------------------------------------------------
# 2. Must start with '---'
# ---------------------------------------------------------------------------
@test "validate_skill_file: printf error when frontmatter dash missing" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/nodash-skill"
    cat > "$TEST_TMPDIR/.agents/skills/nodash-skill/SKILL.md" << 'EOF'
name: nodash-skill
description: Missing leading ---
version: 1.0.0
EOF

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/nodash-skill/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "Must start with '---'" ]]
    [[ "$output" =~ "nodash-skill" ]]
}

# ---------------------------------------------------------------------------
# 3. Missing 'name:' field
# ---------------------------------------------------------------------------
@test "validate_skill_file: printf error for missing name field" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/noname-skill"
    cat > "$TEST_TMPDIR/.agents/skills/noname-skill/SKILL.md" << 'EOF'
---
description: No name field here
version: 1.0.0
EOF

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/noname-skill/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "Missing 'name:' field" ]]
    [[ "$output" =~ "noname-skill" ]]
}

# ---------------------------------------------------------------------------
# 4. Missing 'description:' field
# ---------------------------------------------------------------------------
@test "validate_skill_file: printf error for missing description field" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/nodesc-skill"
    cat > "$TEST_TMPDIR/.agents/skills/nodesc-skill/SKILL.md" << 'EOF'
---
name: nodesc-skill
version: 1.0.0
EOF

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/nodesc-skill/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "Missing 'description:' field" ]]
    [[ "$output" =~ "nodesc-skill" ]]
}

# ---------------------------------------------------------------------------
# 5. Missing 'version:' field — warning only, no error increment
# ---------------------------------------------------------------------------
@test "validate_skill_file: printf warning for missing version but still returns 0" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/nover-skill"
    cat > "$TEST_TMPDIR/.agents/skills/nover-skill/SKILL.md" << 'EOF'
---
name: nover-skill
description: No version field
EOF

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/nover-skill/SKILL.md'
    " 2>&1

    # version is optional (recommended) — should still return 0
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Missing 'version:' field (recommended)" ]]
    [[ "$output" =~ "nover-skill" ]]
}

# ---------------------------------------------------------------------------
# 6. Line count exceeds MAX_SKILL_LINES
# ---------------------------------------------------------------------------
@test "validate_skill_file: printf error when SKILL.md exceeds MAX_SKILL_LINES" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/toolong-skill"
    {
        printf "---\nname: toolong-skill\ndescription: Too long\nversion: 1.0.0\n"
        # Add enough lines to exceed the default MAX_SKILL_LINES=250
        for i in $(seq 1 260); do printf "line %d\n" "$i"; done
    } > "$TEST_TMPDIR/.agents/skills/toolong-skill/SKILL.md"

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/toolong-skill/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "exceeds" ]]
    [[ "$output" =~ "toolong-skill" ]]
}

# ---------------------------------------------------------------------------
# 7. template_version >1 minor behind current — warning
# ---------------------------------------------------------------------------
@test "validate_skill_file: printf warning when template_version >1 minor behind" {
    # VERSION file = 1.2.0, skill template_version = 1.0.0 (2 minors behind)
    echo "1.2.0" > "$TEST_TMPDIR/VERSION"

    mkdir -p "$TEST_TMPDIR/.agents/skills/oldtmpl-skill"
    cat > "$TEST_TMPDIR/.agents/skills/oldtmpl-skill/SKILL.md" << 'EOF'
---
name: oldtmpl-skill
description: Old template version
version: 1.0.0
template_version: 1.0.0
EOF

    run bash -c "
        REPO_ROOT='$TEST_TMPDIR'
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/oldtmpl-skill/SKILL.md'
    " 2>&1

    # Should warn about being >1 minor behind (1.0.0 vs 1.2.0 = 2 minors behind)
    [[ "$output" =~ "template_version" ]]
    [[ "$output" =~ ">1 minor behind" ]]
    [[ "$output" =~ "oldtmpl-skill" ]]
}

# ---------------------------------------------------------------------------
# 8. template_version only 1 minor behind — no warning
# ---------------------------------------------------------------------------
@test "validate_skill_file: no template_version warning when only 1 minor behind" {
    echo "1.2.0" > "$TEST_TMPDIR/VERSION"

    mkdir -p "$TEST_TMPDIR/.agents/skills/recenttmpl-skill"
    cat > "$TEST_TMPDIR/.agents/skills/recenttmpl-skill/SKILL.md" << 'EOF'
---
name: recenttmpl-skill
description: Recent template version
version: 1.0.0
template_version: 1.1.0
EOF

    run bash -c "
        REPO_ROOT='$TEST_TMPDIR'
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/recenttmpl-skill/SKILL.md'
    " 2>&1

    [ "$status" -eq 0 ]
    # Should NOT warn about template version
    [[ ! "$output" =~ ">1 minor behind" ]]
}

# ---------------------------------------------------------------------------
# 9. Valid skill returns 0 and sets SKILL_LINE_COUNT
# ---------------------------------------------------------------------------
@test "validate_skill_file: valid skill returns 0 and exports SKILL_LINE_COUNT" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/good-skill"
    cat > "$TEST_TMPDIR/.agents/skills/good-skill/SKILL.md" << 'EOF'
---
name: good-skill
description: A completely valid skill
version: 1.0.0
EOF

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/good-skill/SKILL.md'
        echo \"LINE_COUNT=\$SKILL_LINE_COUNT\"
    "

    [ "$status" -eq 0 ]
    [[ "$output" =~ "LINE_COUNT=" ]]
    # SKILL_LINE_COUNT should be > 0
    line_count="${output##*LINE_COUNT=}"
    [ "$line_count" -gt 0 ]
}

# ---------------------------------------------------------------------------
# 10. MAX_SKILL_LINES is configurable
# ---------------------------------------------------------------------------
@test "validate_skill_file: respects custom MAX_SKILL_LINES env var" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/small-skill"
    {
        printf "---\nname: small-skill\ndescription: Short skill\nversion: 1.0.0\n"
        for i in $(seq 1 10); do printf "line %d\n" "$i"; done
    } > "$TEST_TMPDIR/.agents/skills/small-skill/SKILL.md"

    # Set a very low line limit so this short file exceeds it
    run bash -c "
        MAX_SKILL_LINES=5
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/small-skill/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "exceeds" ]]
}

# ---------------------------------------------------------------------------
# 11. Skill name with hyphens renders correctly in printf %s messages (regression)
# ---------------------------------------------------------------------------
@test "validate_skill_file: skill name containing hyphens renders correctly in messages" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/my-complex-skill-name"
    # Missing description to trigger an error message with the skill name
    cat > "$TEST_TMPDIR/.agents/skills/my-complex-skill-name/SKILL.md" << 'EOF'
---
name: my-complex-skill-name
version: 1.0.0
EOF

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/my-complex-skill-name/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "my-complex-skill-name" ]]
    [[ "$output" =~ "Missing 'description:' field" ]]
}

# ---------------------------------------------------------------------------
# 12. Multiple errors accumulated — all reported
# ---------------------------------------------------------------------------
@test "validate_skill_file: accumulates multiple errors (no-dash + no-name + no-desc)" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/broken-skill"
    # No frontmatter, no name, no description
    printf "just some text\n" > "$TEST_TMPDIR/.agents/skills/broken-skill/SKILL.md"

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/broken-skill/SKILL.md'
    " 2>&1

    # Should report multiple distinct errors
    [[ "$output" =~ "Must start with '---'" ]]
    [[ "$output" =~ "Missing 'name:' field" ]]
    [[ "$output" =~ "Missing 'description:' field" ]]
}

# ---------------------------------------------------------------------------
# 13. MAX_SKILL_LINES must be numeric — exits on invalid value
# ---------------------------------------------------------------------------
@test "skill-validation.sh: exits with error when MAX_SKILL_LINES is non-numeric" {
    run bash -c "
        MAX_SKILL_LINES=abc source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
    " 2>&1

    [ "$status" -ne 0 ]
    [[ "$output" =~ "MAX_SKILL_LINES must be numeric" ]]
}

# ---------------------------------------------------------------------------
# 14. Line count message includes both limit and actual count (boundary check)
# ---------------------------------------------------------------------------
@test "validate_skill_file: line-exceed message includes both limit and actual line count" {
    mkdir -p "$TEST_TMPDIR/.agents/skills/boundary-skill"
    {
        printf "---\nname: boundary-skill\ndescription: Just over limit\nversion: 1.0.0\n"
        for i in $(seq 1 260); do printf "line %d\n" "$i"; done
    } > "$TEST_TMPDIR/.agents/skills/boundary-skill/SKILL.md"

    run bash -c "
        source '$REPO_ROOT_ORIGINAL/scripts/lib/skill-validation.sh'
        validate_skill_file '$TEST_TMPDIR/.agents/skills/boundary-skill/SKILL.md'
    " 2>&1

    [ "$status" -ne 0 ]
    # Message should include MAX_SKILL_LINES (250) and the actual count
    [[ "$output" =~ "250" ]]
    [[ "$output" =~ "lines" ]]
}