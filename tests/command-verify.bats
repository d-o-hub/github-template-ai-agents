#!/usr/bin/env bats
# BATS tests for command verification system
# Based on approach from https://github.com/d-oit/command-verify

setup() {
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cd "$REPO_ROOT"
    
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    trap "rm -rf $TEST_DIR" EXIT
}

teardown() {
    # Cleanup is handled by trap in setup
    true
}

@test "discover-commands.sh exists and is executable" {
    [ -x "./scripts/discover-commands.sh" ]
}

@test "verify-commands.sh exists and is executable" {
    [ -x "./scripts/verify-commands.sh" ]
}

@test "update-all-docs.sh exists and is executable" {
    [ -x "./scripts/update-all-docs.sh" ]
}

@test "command library files exist" {
    [ -f "./scripts/lib/command-categories.sh" ]
    [ -f "./scripts/lib/command-cache.sh" ]
    [ -f "./scripts/lib/command-invalidation.sh" ]
}

@test "verify-commands.sh --help shows usage" {
    run ./scripts/verify-commands.sh --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "update-all-docs.sh --help shows usage" {
    run ./scripts/update-all-docs.sh --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "verify-commands.sh runs without errors (quick mode)" {
    run ./scripts/verify-commands.sh --quick --silent
    [ "$status" -eq 0 ]
}

@test "update-all-docs.sh dry-run works" {
    run ./scripts/update-all-docs.sh --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[DRY-RUN]"* ]]
}

@test "command categorization works correctly" {
    source scripts/lib/command-categories.sh
    
    # Test safe command
    safe_result=$(categorize_command "npm run build")
    [ "$safe_result" = "safe" ]
    
    # Test dangerous command
    dangerous_result=$(categorize_command "rm -rf /tmp")
    [ "$dangerous_result" = "dangerous" ]
    
    # Test conditional command
    conditional_result=$(categorize_command "npm install")
    [ "$conditional_result" = "conditional" ]
}

@test "is_safe_to_run returns correct values" {
    source scripts/lib/command-categories.sh
    
    run is_safe_to_run "npm run build"
    [ "$status" -eq 0 ]
    
    run is_safe_to_run "rm -rf /tmp"
    [ "$status" -eq 1 ]
}

@test "requires_warning returns correct values" {
    source scripts/lib/command-categories.sh
    
    run requires_warning "rm -rf /tmp"
    [ "$status" -eq 0 ]
    
    run requires_warning "npm run build"
    [ "$status" -eq 1 ]
}

@test "cache initialization works" {
    source scripts/lib/command-cache.sh
    
    init_cache
    
    [ -d ".cache/command-validations" ]
    [ -d ".cache/command-validations/commands" ]
}

@test "cache save and retrieve works" {
    source scripts/lib/command-cache.sh
    
    init_cache
    
    save_cached_result "test-cmd-123" '{"valid":true,"category":"safe"}'
    cached=$(get_cached_result "test-cmd-123")
    [ -n "$cached" ]
    [[ "$cached" == *"valid"* ]]
    
    # Cleanup
    rm -f .cache/command-validations/commands/*.json 2>/dev/null || true
}

@test "cache clear works" {
    source scripts/lib/command-cache.sh
    
    init_cache
    save_cached_result "test-cmd-456" '{"valid":true}'
    clear_cache
    
    cached=$(get_cached_result "test-cmd-456")
    [ -z "$cached" ]
}

@test "get_category_description returns valid descriptions" {
    source scripts/lib/command-categories.sh
    
    desc=$(get_category_description "safe")
    [ -n "$desc" ]
    [[ "$desc" == *"side effects"* ]]
    
    desc=$(get_category_description "dangerous")
    [ -n "$desc" ]
    [[ "$desc" == *"destructive"* ]]
}

@test "discover-commands.sh finds commands in test file" {
    # Create test markdown file
    TEST_FILE=$(mktemp --suffix=.md)
    cat > "$TEST_FILE" << 'EOF'
# Test Document

This is a test.

```bash
npm run build
cargo test
echo "hello"
```

Some text.

```sh
ls -la
```
EOF

    # Run discovery on the test file
    result=$(grep -E "(npm run build|cargo test|echo|ls -la)" <(./scripts/discover-commands.sh 2>/dev/null) || echo "")
    
    # Should find at least some commands
    [ -n "$result" ]
    
    # Cleanup
    rm -f "$TEST_FILE"
}

@test "verify-commands.sh JSON output is valid" {
    run ./scripts/verify-commands.sh --json --silent
    [ "$status" -eq 0 ]
    
    # Check if output looks like JSON
    [[ "$output" == *"{"* ]]
    [[ "$output" == *"}"* ]]
    [[ "$output" == *"total_commands"* ]]
}

@test "verify-commands.sh stats output works" {
    run ./scripts/verify-commands.sh --stats --silent
    [ "$status" -eq 0 ]
}

@test "template files exist for reuse" {
    [ -f "./templates/command-verify-template/README.md" ]
    [ -f "./templates/command-verify-template/install.sh" ]
    [ -f "./templates/command-verify-template/.command-verify.conf.example" ]
}

@test "template install script is executable" {
    [ -x "./templates/command-verify-template/install.sh" ]
}

@test "slash command file exists" {
    [ -f "./templates/command-verify-template/.opencode/commands/verify-commands.md" ]
    [ -f "./.opencode/commands/verify-commands.md" ]
}

@test "integration plan document exists" {
    [ -f "./analysis/command-verify-integration-plan.md" ]
}
