#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$REPO_ROOT/scripts/lib/command-categories.sh"
}

@test "harden-command-categorization: prevents false positives (partial words)" {
    run categorize_command "mkdir farm"
    [ "$output" = "unknown" ]
    
    run categorize_command "echo storm"
    [ "$output" = "unknown" ]
}

@test "harden-command-categorization: detects obfuscated commands" {
    run categorize_command "r''m -rf /"
    [ "$output" = "dangerous" ]
    
    run categorize_command "r\"\"m -rf /"
    [ "$output" = "dangerous" ]
    
    run categorize_command "r\\m -rf /"
    [ "$output" = "dangerous" ]
}

@test "harden-command-categorization: detects commands near metacharacters" {
    run categorize_command "(rm -rf /)"
    [ "$output" = "dangerous" ]
    
    run categorize_command "rm;ls"
    [ "$output" = "dangerous" ]
    
    run categorize_command "ls|rm"
    [ "$output" = "dangerous" ]
    
    run categorize_command "rm&ls"
    [ "$output" = "dangerous" ]
}

@test "harden-command-categorization: handles mixed case and whitespace" {
    run categorize_command "  RM -rf /  "
    [ "$output" = "dangerous" ]
    
    run categorize_command "Install dependencies"
    [ "$output" = "conditional" ]
}
