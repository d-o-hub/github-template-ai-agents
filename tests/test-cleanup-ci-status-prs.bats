#!/usr/bin/env bats

setup() {
    # Create mock gh
    cat << "MOCK" > "$BATS_TMPDIR/gh"
#!/bin/bash
if [ "$1" = "repo" ]; then
    echo "owner/repo"
elif [ "$1" = "pr" ]; then
    if [ "$2" = "list" ]; then
        if [[ "$*" == *"--author"* ]] && [[ "$*" == *"github-actions[bot]"* ]] && [[ "$*" == *"--search"* ]] && [[ "$*" == *"ci: update ci status artifacts"* ]]; then
            echo "123 branch-123"
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

@test "cleanup script identifies PRs filtered by author and title" {
    run ./scripts/cleanup-ci-status-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Found PRs to clean up:"* ]]
    [[ "$output" == *"Closing PR #123"* ]]
}

@test "cleanup script handles branch deletion fallback" {
    touch "$BATS_TMPDIR/fail_delete_branch"
    run ./scripts/cleanup-ci-status-prs.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"Manual cleanup for PR #123"* ]]
    [[ "$output" == *"API call: api -X DELETE repos/owner/repo/git/refs/heads/branch-123"* ]]
}
