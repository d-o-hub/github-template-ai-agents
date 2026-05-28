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
    [ "$(categorize_command "npm run build")" = "safe" ]
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
