#!/usr/bin/env bats

setup() {
    # Resolve REPO_ROOT to the actual directory where scripts/ resides
    # Assuming tests/ is a subdirectory of the root.
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "discover-commands.sh exists" {
    [ -x "$REPO_ROOT/scripts/discover-commands.sh" ]
}

@test "verify-commands.sh exists" {
    [ -x "$REPO_ROOT/scripts/verify-commands.sh" ]
}

@test "update-all-docs.sh exists" {
    [ -x "$REPO_ROOT/scripts/update-all-docs.sh" ]
}

@test "command categorization works" {
    source "$REPO_ROOT/scripts/lib/command-categories.sh"
    [ "$(categorize_command "npm run build")" = "dangerous" ]
    [ "$(categorize_command "rm -rf /")" = "dangerous" ]
}

@test "cache operations" {
    # Set CACHE_DIR to a temporary location for testing
    export CACHE_DIR=$(mktemp -d)
    source "$REPO_ROOT/scripts/lib/command-cache.sh"
    # Redefine COMMANDS_CACHE_DIR based on new CACHE_DIR
    COMMANDS_CACHE_DIR="$CACHE_DIR/commands"
    AUDIT_LOG="$CACHE_DIR/audit.log"
    init_cache

    cmd="test"
    file="test.md"
    line="1"
    save_cached_result "$cmd" "$file" "$line" '{"valid":true}'
    [ -n "$(get_cached_result "$file" "$line")" ]
    clear_cache
    [ -z "$(get_cached_result "$file" "$line")" ]
    rm -rf "$CACHE_DIR"
}

@test "verify-commands execution" {
    run "$REPO_ROOT/scripts/verify-commands.sh" --quick --silent
    [ "$status" -eq 0 ]
}

@test "update-all-docs dry-run does not rewrite generated documentation" {
    local backup_dir="$BATS_TEST_TMPDIR/generated-doc-backups"
    mkdir -p "$backup_dir/agents-docs"

    cp "$REPO_ROOT/llms.txt" "$backup_dir/llms.txt"
    cp "$REPO_ROOT/llms-full.txt" "$backup_dir/llms-full.txt"
    cp "$REPO_ROOT/agents-docs/AVAILABLE_SKILLS.md" "$backup_dir/agents-docs/AVAILABLE_SKILLS.md"
    cp "$REPO_ROOT/agents-docs/AGENTS_REGISTRY.md" "$backup_dir/agents-docs/AGENTS_REGISTRY.md"

    printf '\nDRY-RUN CANARY llms.txt\n' >> "$REPO_ROOT/llms.txt"
    printf '\nDRY-RUN CANARY llms-full.txt\n' >> "$REPO_ROOT/llms-full.txt"
    printf '\nDRY-RUN CANARY available skills\n' >> "$REPO_ROOT/agents-docs/AVAILABLE_SKILLS.md"
    printf '\nDRY-RUN CANARY agents registry\n' >> "$REPO_ROOT/agents-docs/AGENTS_REGISTRY.md"

    cp "$REPO_ROOT/llms.txt" "$backup_dir/llms.txt.dirty"
    cp "$REPO_ROOT/llms-full.txt" "$backup_dir/llms-full.txt.dirty"
    cp "$REPO_ROOT/agents-docs/AVAILABLE_SKILLS.md" "$backup_dir/agents-docs/AVAILABLE_SKILLS.md.dirty"
    cp "$REPO_ROOT/agents-docs/AGENTS_REGISTRY.md" "$backup_dir/agents-docs/AGENTS_REGISTRY.md.dirty"

    run "$REPO_ROOT/scripts/update-all-docs.sh" --dry-run

    local docs_unchanged=0
    cmp "$backup_dir/llms.txt.dirty" "$REPO_ROOT/llms.txt" >/dev/null || docs_unchanged=1
    cmp "$backup_dir/llms-full.txt.dirty" "$REPO_ROOT/llms-full.txt" >/dev/null || docs_unchanged=1
    cmp "$backup_dir/agents-docs/AVAILABLE_SKILLS.md.dirty" \
        "$REPO_ROOT/agents-docs/AVAILABLE_SKILLS.md" >/dev/null || docs_unchanged=1
    cmp "$backup_dir/agents-docs/AGENTS_REGISTRY.md.dirty" \
        "$REPO_ROOT/agents-docs/AGENTS_REGISTRY.md" >/dev/null || docs_unchanged=1

    cp "$backup_dir/llms.txt" "$REPO_ROOT/llms.txt"
    cp "$backup_dir/llms-full.txt" "$REPO_ROOT/llms-full.txt"
    cp "$backup_dir/agents-docs/AVAILABLE_SKILLS.md" "$REPO_ROOT/agents-docs/AVAILABLE_SKILLS.md"
    cp "$backup_dir/agents-docs/AGENTS_REGISTRY.md" "$REPO_ROOT/agents-docs/AGENTS_REGISTRY.md"

    [ "$status" -ne 0 ]
    [[ "$output" == *"[DRY-RUN] Checking generated LLM context files without writing committed outputs"* ]]
    [[ "$output" == *"llms.txt is out of date"* ]]
    [ "$docs_unchanged" -eq 0 ]
}
