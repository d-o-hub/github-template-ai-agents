#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$REPO_ROOT/scripts/lib/command-categories.sh"
}

@test "harden-command-categorization: prevents false positives (partial words)" {
    run categorize_command "mkdir farm"
    [ "$output" = "unknown" ]
    
    run categorize_command "printf storm"
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

@test "harden-command-categorization: prevents false positives for unrelated words containing keywords" {
    run categorize_command "nslookup google.com"
    [ "$output" = "unknown" ]

    run categorize_command "dig google.com"
    [ "$output" = "unknown" ]

    run categorize_command "shout something"
    [ "$output" = "unknown" ]

    run categorize_command "google-chrome"
    [ "$output" = "unknown" ]
}

@test "harden-command-categorization: still detects valid versioned commands" {
    run categorize_command "python3.11 script.py"
    [ "$output" = "dangerous" ]

    run categorize_command "node16 index.js"
    [ "$output" = "dangerous" ]

    run categorize_command "mkfs.ext4 /dev/sda1"
    [ "$output" = "dangerous" ]
}
