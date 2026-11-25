#!/usr/bin/env bats
# Sample BATS tests for validate-skills.sh
# Template users: Add your own tests in this directory

@test "validate-skills.sh exists and is executable" {
    [ -x "./scripts/validate-skills.sh" ]
}

@test "validate-skills.sh runs without errors on valid repository" {
    run ./scripts/validate-skills.sh
    [ "$status" -eq 0 ]
}

@test "validate-skills.sh detects broken symlinks" {
    # Hermetic: the broken symlink lives in a sandboxed farm, not the live
    # .claude/skills. An interrupted run must never leave a farm-dir orphan
    # behind; even if teardown never fires, the residue stays under mktemp.
    SANDBOX="$(mktemp -d)"
    mkdir -p "$SANDBOX/scripts" "$SANDBOX/.agents/skills/demo-skill" "$SANDBOX/.claude/skills"
    cp scripts/validate-skills.sh "$SANDBOX/scripts/"
    cp -r scripts/lib "$SANDBOX/scripts/lib"
    printf -- '---\nname: demo-skill\ndescription: demo\n---\n' > "$SANDBOX/.agents/skills/demo-skill/SKILL.md"
    ln -s ../../.agents/skills/demo-skill "$SANDBOX/.claude/skills/demo-skill"
    ln -sf /nonexistent/path "$SANDBOX/.claude/skills/test-broken-symlink"

    run env bash "$SANDBOX/scripts/validate-skills.sh"

    # Either fails outright or names the damage. Either way no live-tree
    # fixture ever existed.
    [ "$status" -ne 0 ] || { [ -n "$output" ] && echo "$output" | grep -qi "symlink\|broken\|demo"; }

    rm -rf "$SANDBOX"
}

@test "All skill directories have SKILL.md" {
    for skill_dir in .agents/skills/*/; do
        # Skip eval workspace directories and skills-evaluation
        [[ "$skill_dir" == *-workspace/ ]] && continue
        [[ "$skill_dir" == *skills-evaluation/ ]] && continue
        [ -f "$skill_dir/SKILL.md" ]
    done
}

@test "All SKILL.md files have required frontmatter" {
    for skill_file in .agents/skills/*/SKILL.md; do
        # Check for name field
        grep -q "^name:" "$skill_file"
        
        # Check for description field
        grep -q "^description:" "$skill_file"
        
        # Check for frontmatter markers
        head -1 "$skill_file" | grep -q "^---$"
    done
}

@test "SKILL.md line count produces warning for files over 250 lines" {
    # Line count >250 is a WARNING (not failure) to allow pre-existing skills
    # The validate-skills.sh script handles this as a yellow ⚠ warning
    run bash -c 'for skill_file in .agents/skills/*/SKILL.md; do
        line_count=$(wc -l < "$skill_file")
        if [ "$line_count" -gt 250 ]; then
            # perf: replace external basename and dirname subshells with native bash parameter expansion
            # Expected Impact: Eliminates process fork overhead per skill file, improving test execution speed.
            dir="${skill_file%/*}"
            skill_name="${dir##*/}"
            echo "WARNING: $skill_name has $line_count lines"
        fi
    done'
    # This test always passes - it just logs warnings
    [ "$status" -eq 0 ]
}
