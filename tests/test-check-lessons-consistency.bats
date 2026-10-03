#!/usr/bin/env bats
# Tests for scripts/check-lessons-consistency.sh
#
# LESSONS.md, lessons.jsonl and self-learning-rules.md drifted apart with nothing
# watching: 11 ids were referenced by the runtime index but absent from the
# catalog, and 19 catalog entries had no machine row. LESSONS.md documented the
# gap as a known issue while it kept growing.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    # The script reads fixed paths under REPO_ROOT, which it derives from its own
    # location, so the sandbox must look like a repo root.
    SANDBOX="$(mktemp -d /tmp/lessons-check-XXXXXX)"
    mkdir -p "$SANDBOX/scripts" "$SANDBOX/agents-docs"
    cp "$REPO_ROOT/scripts/check-lessons-consistency.sh" "$SANDBOX/scripts/"
    SCRIPT="$SANDBOX/scripts/check-lessons-consistency.sh"

    cat > "$SANDBOX/agents-docs/LESSONS.md" <<'EOF'
# Lessons

### LESSON-001: First

**Date**: 2026-01-01

### LESSON-002: Second

**Date**: 2026-01-02
EOF
    cat > "$SANDBOX/agents-docs/self-learning-rules.md" <<'EOF'
- **LESSON-001 — First**: one
- **LESSON-002 — Second**: two
EOF
    printf '{"id": "LESSON-001", "title": "First"}\n{"id": "LESSON-002", "title": "Second"}\n' \
        > "$SANDBOX/agents-docs/lessons.jsonl"
}

teardown() {
    rm -rf "$SANDBOX"
}

@test "passes when catalog, jsonl and rules index agree" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "fails when a catalog entry has no jsonl row" {
    printf '{"id": "LESSON-001", "title": "First"}\n' > "$SANDBOX/agents-docs/lessons.jsonl"

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"LESSON-002 is in LESSONS.md but has no lessons.jsonl row"* ]]
}

@test "fails when a jsonl row has no catalog entry" {
    printf '{"id": "LESSON-001", "title": "First"}\n{"id": "LESSON-002", "title": "Second"}\n{"id": "LESSON-003", "title": "Third"}\n' \
        > "$SANDBOX/agents-docs/lessons.jsonl"

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"LESSON-003 has a lessons.jsonl row but no LESSONS.md entry"* ]]
}

@test "fails when the rules index cites a lesson nobody recorded" {
    printf -- '- **LESSON-042 — Ghost**: recorded only in the index\n' \
        >> "$SANDBOX/agents-docs/self-learning-rules.md"

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"references LESSON-042, which is in neither"* ]]
}

@test "accepts a rules reference that lives only in the archive" {
    printf '# Archive\n\n### LESSON-042: Superseded\n' > "$SANDBOX/agents-docs/lessons-archive.md"
    printf -- '- **LESSON-042 — Ghost**: superseded and archived\n' \
        >> "$SANDBOX/agents-docs/self-learning-rules.md"

    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "fails on an unparsable jsonl row instead of skipping it" {
    printf '{"id": "LESSON-001", "title": "First"}\nnot json at all\n' \
        > "$SANDBOX/agents-docs/lessons.jsonl"

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "fails when a jsonl row lacks a title" {
    printf '{"id": "LESSON-001", "title": "First"}\n{"id": "LESSON-002"}\n' \
        > "$SANDBOX/agents-docs/lessons.jsonl"

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}

@test "fails when the catalog has no headings rather than reporting zero drift" {
    printf '# Lessons\n\nNothing recorded yet.\n' > "$SANDBOX/agents-docs/LESSONS.md"

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no lesson headings found"* ]]
}

@test "fails when the rules index is empty rather than passing vacuously" {
    printf '# No runtime notes yet.\n' > "$SANDBOX/agents-docs/self-learning-rules.md"

    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no lesson references found"* ]]
}

@test "reports a multi-digit id without corrupting it" {
    # A leading zero must not be read as octal: 099 has to stay 099.
    printf '\n### LESSON-099: Synthetic\n' >> "$SANDBOX/agents-docs/LESSONS.md"

    run bash "$SCRIPT"
    [ "$status" -eq 1 ]
    [[ "$output" == *"LESSON-099 is in LESSONS.md"* ]]
    [[ "$output" != *"LESSON-000"* ]]
}
