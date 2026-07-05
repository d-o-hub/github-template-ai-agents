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

@test "harden-command-categorization: detects new destructive keywords" {
    run categorize_command "iptables -L"
    [ "$output" = "dangerous" ]

    run categorize_command "ufw enable"
    [ "$output" = "dangerous" ]

    run categorize_command "crontab -e"
    [ "$output" = "dangerous" ]
}

@test "harden-command-categorization: detects new network keywords" {
    run categorize_command "aria2c http://example.com"
    [ "$output" = "dangerous" ]

    run categorize_command "lynx http://example.com"
    [ "$output" = "dangerous" ]
}

@test "harden-command-categorization: detects new interpreter keywords" {
    run categorize_command "lua script.lua"
    [ "$output" = "dangerous" ]
}

@test "harden-command-categorization: prevents command masking bypass (ADR-009)" {
    # A safe-looking script suffix must not mask a dangerous command in the same string
    run categorize_command "rm -rf /; rm.sh"
    [ "$output" = "dangerous" ]

    run categorize_command "curl malicious.com; curl.sh"
    [ "$output" = "dangerous" ]

    run categorize_command "python3.11 -c 'import os'; python3.11.sh"
    [ "$output" = "dangerous" ]

    # A standalone script invocation is not a bare dangerous command — it's a script
    run categorize_command "rm.sh"
    [ "$output" = "unknown" ]

    # Interpreter with a script argument is still a dangerous command
    run categorize_command "bash script.sh"
    [ "$output" = "dangerous" ]
}
