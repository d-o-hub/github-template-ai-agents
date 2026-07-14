#!/usr/bin/env bats

setup() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    source "$REPO_ROOT/scripts/lib/command-categories.sh"
}

@test "env-var-hardening: detects LD_PRELOAD injection" {
    run categorize_command "LD_PRELOAD=./evil.so ls"
    [ "$output" = "dangerous" ]
}

@test "env-var-hardening: detects PYTHONPATH injection" {
    run categorize_command "PYTHONPATH=/tmp/evil python3 script.py"
    [ "$output" = "dangerous" ]
}

@test "env-var-hardening: detects NODE_OPTIONS injection" {
    run categorize_command "NODE_OPTIONS='--loader ./evil.mjs' node script.js"
    [ "$output" = "dangerous" ]
}

@test "env-var-hardening: detects BASH_ENV injection" {
    run categorize_command "BASH_ENV=/tmp/evil.sh bash script.sh"
    [ "$output" = "dangerous" ]
}

@test "env-var-hardening: detects ENV injection" {
    run categorize_command "ENV=/tmp/evil.sh sh script.sh"
    [ "$output" = "dangerous" ]
}

@test "env-var-hardening: detects PS4 injection" {
    run categorize_command "PS4='\$(whoami) ' bash -x script.sh"
    [ "$output" = "dangerous" ]
}

@test "env-var-hardening: handles multiple env vars and mixed case" {
    run categorize_command "LD_PRELOAD=./evil.so PYTHONPATH=/tmp/evil python3"
    [ "$output" = "dangerous" ]

    run categorize_command "ld_preload=./evil.so ls"
    [ "$output" = "dangerous" ]
}

@test "env-var-hardening: handles plus in env vars (e.g. for append)" {
    # Some systems/shells might support += for env vars in some contexts,
    # or it might just be part of a malicious string.
    run categorize_command "PYTHONPATH+=:/tmp/evil python3"
    [ "$output" = "dangerous" ]
}
