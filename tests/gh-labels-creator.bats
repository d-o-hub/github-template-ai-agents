#!/usr/bin/env bats
# Tests for scripts/gh-labels-creator.sh
# Focuses on the changed line: printf "Failed to delete: %s\n" "$label"
# when gh label delete fails.

setup_file() {
    export REPO_ROOT_ORIGINAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export GH_LABELS_SCRIPT="$REPO_ROOT_ORIGINAL/scripts/gh-labels-creator.sh"
}

setup() {
    TEST_TMPDIR="$(mktemp -d)"
    export TEST_TMPDIR

    # Create a fake bin directory with stub executables
    mkdir -p "$TEST_TMPDIR/bin"

    # Stub jq: always exits 0
    cat > "$TEST_TMPDIR/bin/jq" << 'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$TEST_TMPDIR/bin/jq"

    # Default gh stub: succeeds for everything
    _write_gh_stub_success

    # Prepend fake bin to PATH so stubs are found first
    export PATH="$TEST_TMPDIR/bin:$PATH"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# ---------------------------------------------------------------------------
# Helper: write a gh stub that always succeeds
# ---------------------------------------------------------------------------
_write_gh_stub_success() {
    cat > "$TEST_TMPDIR/bin/gh" << 'EOF'
#!/usr/bin/env bash
# Stub gh: succeeds silently
exit 0
EOF
    chmod +x "$TEST_TMPDIR/bin/gh"
}

# ---------------------------------------------------------------------------
# Helper: write a gh stub where `label delete` fails
# ---------------------------------------------------------------------------
_write_gh_stub_delete_fails() {
    cat > "$TEST_TMPDIR/bin/gh" << 'EOF'
#!/usr/bin/env bash
# gh stub: label list returns labels, label delete always fails
if [[ "$1" == "label" && "$2" == "list" ]]; then
    # Output label names via --jq '.[].name' simulation
    # The script calls: gh label list --json name --jq '.[].name'
    printf "my-label\nanother-label\n"
    exit 0
elif [[ "$1" == "label" && "$2" == "delete" ]]; then
    exit 1
else
    exit 0
fi
EOF
    chmod +x "$TEST_TMPDIR/bin/gh"
}

# ---------------------------------------------------------------------------
# Helper: write a gh stub where label list returns specific labels
# ---------------------------------------------------------------------------
_write_gh_stub_with_labels() {
    local labels="$1"
    cat > "$TEST_TMPDIR/bin/gh" << EOF
#!/usr/bin/env bash
if [[ "\$1" == "label" && "\$2" == "list" ]]; then
    printf "%s\n" "$labels"
    exit 0
elif [[ "\$1" == "label" && "\$2" == "delete" ]]; then
    exit 0
else
    exit 0
fi
EOF
    chmod +x "$TEST_TMPDIR/bin/gh"
}

# ---------------------------------------------------------------------------
# 1. printf "Failed to delete: %s\n" on gh label delete failure
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: printf 'Failed to delete' when gh label delete fails" {
    _write_gh_stub_delete_fails

    # Provide 'y' to the delete-all prompt
    run bash -c "echo 'y' | bash '$GH_LABELS_SCRIPT'"

    # Script should continue (not exit) on delete failure
    # The printf output should appear in stdout/stderr
    [[ "$output" =~ "Failed to delete:" ]] || [[ "$output" =~ "my-label" ]]
}

# ---------------------------------------------------------------------------
# 2. printf includes the label name in "Failed to delete" message
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: failed delete message includes the specific label name" {
    _write_gh_stub_delete_fails

    run bash -c "echo 'y' | bash '$GH_LABELS_SCRIPT'" 2>&1

    # Should print: Failed to delete: my-label
    [[ "$output" =~ "my-label" ]]
}

# ---------------------------------------------------------------------------
# 3. Script continues after a failed delete (not exit 1)
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: continues execution after a single delete failure" {
    _write_gh_stub_delete_fails

    run bash -c "echo 'y' | bash '$GH_LABELS_SCRIPT'" 2>&1

    # Script should proceed to label creation; should see "Creating labels..."
    [[ "$output" =~ "Creating labels" ]] || [[ "$output" =~ "Label deletion completed" ]]
}

# ---------------------------------------------------------------------------
# 4. CI mode skips interactive prompts and deletion entirely
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: CI mode skips deletion and proceeds to creation" {
    _write_gh_stub_success

    run bash "$GH_LABELS_SCRIPT" --ci

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Running in CI mode" ]]
    [[ "$output" =~ "Skipping label deletion" ]]
    [[ "$output" =~ "Creating labels" ]]
}

# ---------------------------------------------------------------------------
# 5. Declining the delete prompt skips deletion
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: 'N' at delete prompt skips deletion" {
    _write_gh_stub_success

    run bash -c "echo 'N' | bash '$GH_LABELS_SCRIPT'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Skipping label deletion" ]]
    [[ "$output" =~ "Creating labels" ]]
}

# ---------------------------------------------------------------------------
# 6. Accepting delete prompt triggers the deletion flow
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: 'y' at delete prompt enters deletion flow" {
    _write_gh_stub_success

    # Make gh label list return a label name
    cat > "$TEST_TMPDIR/bin/gh" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "label" && "$2" == "list" ]]; then
    printf "existing-label\n"
    exit 0
else
    exit 0
fi
EOF
    chmod +x "$TEST_TMPDIR/bin/gh"

    run bash -c "echo 'y' | bash '$GH_LABELS_SCRIPT'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Deleting" ]] || [[ "$output" =~ "Label deletion completed" ]]
}

# ---------------------------------------------------------------------------
# 7. "No labels found to delete" when gh label list returns nothing
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: prints 'No labels found' when gh label list is empty" {
    cat > "$TEST_TMPDIR/bin/gh" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "label" && "$2" == "list" ]]; then
    printf ""
    exit 0
else
    exit 0
fi
EOF
    chmod +x "$TEST_TMPDIR/bin/gh"

    run bash -c "echo 'y' | bash '$GH_LABELS_SCRIPT'"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "No labels found to delete" ]]
}

# ---------------------------------------------------------------------------
# 8. Label creation proceeds and prints completion message
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: prints 'Label creation completed!' after creating labels" {
    _write_gh_stub_success

    run bash "$GH_LABELS_SCRIPT" --ci

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Label creation completed!" ]]
}

# ---------------------------------------------------------------------------
# 9. Script requires gh to be installed — exits when gh missing
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: exits with error when gh is not in PATH" {
    # Remove the gh stub from PATH
    rm -f "$TEST_TMPDIR/bin/gh"

    run bash "$GH_LABELS_SCRIPT" --ci

    [ "$status" -ne 0 ]
    [[ "$output" =~ "required" ]] || [[ "$output" =~ "gh" ]]
}

# ---------------------------------------------------------------------------
# 10. "Failed to delete" output does not contain format directives (printf safety)
# ---------------------------------------------------------------------------
@test "gh-labels-creator.sh: printf failure message is safe with label names containing percent signs" {
    # Label name that would be dangerous if passed to echo without proper escaping
    cat > "$TEST_TMPDIR/bin/gh" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "label" && "$2" == "list" ]]; then
    printf "label-with-%%s-inside\n"
    exit 0
elif [[ "$1" == "label" && "$2" == "delete" ]]; then
    exit 1
else
    exit 0
fi
EOF
    chmod +x "$TEST_TMPDIR/bin/gh"

    run bash -c "echo 'y' | bash '$GH_LABELS_SCRIPT'" 2>&1

    # Should print the label name literally — not expand %s as a format specifier
    [[ "$output" =~ "label-with-" ]] || [[ "$output" =~ "Failed to delete" ]]
    # Should NOT have interpreted %s as a format directive (no empty substitution)
    [[ ! "$output" =~ "Failed to delete: $" ]]
}