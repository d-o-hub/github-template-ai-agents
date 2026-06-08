#!/usr/bin/env bats

setup() {
    # Create mock gh that handles auth status, repo view, and PR operations
    cat << "MOCK" > "$BATS_TMPDIR/gh"
#!/bin/bash
if [ "$1" = "auth" ] && [ "$2" = "status" ]; then
    exit 0
elif [ "$1" = "repo" ]; then
    echo "owner/repo"
elif [ "$1" = "pr" ]; then
    if [ "$2" = "list" ]; then
        # Match CI status update PRs
        if [[ "$*" == *"--search"* ]] && [[ "$*" == *"ci: update ci status artifacts"* ]]; then
            echo "123 branch-123"
        # Match LLM regeneration PRs
        elif [[ "$*" == *"--search"* ]] && [[ "$*" == *"ci: regenerate llms.txt"* ]]; then
            echo "456 auto/regenerate-llms-txt"
        # Match stale bot PRs on auto/ci branches (>24h)
        elif [[ "$*" == *"--json"* ]] && [[ "$*" == *"createdAt"* ]]; then
            echo ""
        else
            echo ""
        fi
    elif [ "$2" = "close" ]; then
        if [[ "$*" == *"--delete-branch"* ]]; then
            if [ -f "$BATS_TMPDIR/fail_delete_branch" ]; then
                echo "Simulated failure" >&2
                false
            else
                echo "Closing PR $3 and deleting branch"
            fi
        else
            echo "Closing PR $3"
        fi
    fi
elif [ "$1" = "api" ]; then
    echo "API call: $*"
fi
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    export PATH="$BATS_TMPDIR:$PATH"
    rm -f "$BATS_TMPDIR/fail_delete_branch"
}

@test "cleanup script identifies CI status PRs" {
    run ./scripts/cleanup-ci-status-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale CI status update PRs"* ]]
    [[ "$output" == *"Closing PR #123"* ]]
}

@test "cleanup script identifies LLM regeneration PRs" {
    run ./scripts/cleanup-ci-status-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"stale LLM context regeneration PRs"* ]]
    [[ "$output" == *"Closing PR #456"* ]]
}

@test "cleanup script checks gh auth status" {
    run ./scripts/cleanup-ci-status-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Searching for stale automated PRs"* ]]
}

@test "cleanup script handles branch deletion fallback" {
    touch "$BATS_TMPDIR/fail_delete_branch"
    run ./scripts/cleanup-ci-status-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Retrying close without branch delete for PR #123"* ]]
    [[ "$output" == *"API call: api -X DELETE repos/owner/repo/git/refs/heads/branch-123"* ]]
}
