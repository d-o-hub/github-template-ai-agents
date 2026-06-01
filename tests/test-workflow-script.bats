#!/usr/bin/env bats

setup() {
    export BATS_TMPDIR_WORKFLOW="$BATS_TMPDIR/workflow_test"
    mkdir -p "$BATS_TMPDIR_WORKFLOW"

    # Mock git
    cat << "MOCK" > "$BATS_TMPDIR_WORKFLOW/git"
#!/bin/bash
if [ "$1" = "diff" ]; then
    if [ -f "$BATS_TMPDIR_WORKFLOW/has_changes" ]; then
        exit 1
    else
        exit 0
    fi
elif [ "$1" = "add" ]; then
    touch "$BATS_TMPDIR_WORKFLOW/staged"
elif [ "$1" = "checkout" ]; then
    echo "Switched to branch $3"
elif [ "$1" = "commit" ]; then
    echo "Committed changes"
elif [ "$1" = "push" ]; then
    echo "Pushed changes"
fi
MOCK
    chmod +x "$BATS_TMPDIR_WORKFLOW/git"

    # Mock gh
    cat << "MOCK" > "$BATS_TMPDIR_WORKFLOW/gh"
#!/bin/bash
if [ "$1" = "pr" ]; then
    if [ "$2" = "list" ]; then
        if [ -f "$BATS_TMPDIR_WORKFLOW/pr_exists" ]; then
            echo "999"
        else
            echo ""
        fi
    elif [ "$2" = "create" ]; then
        echo "Created PR"
    fi
fi
MOCK
    chmod +x "$BATS_TMPDIR_WORKFLOW/gh"

    export PATH="$BATS_TMPDIR_WORKFLOW:$PATH"
    export TARGET_BRANCH="main"
    export GITHUB_RUN_ID="12345"
}

teardown() {
    rm -rf "$BATS_TMPDIR_WORKFLOW"
}

@test "workflow script skips if no changes" {
    run bash -c "
      git add .github/ci-status/ci-status.json .github/ci-status/ci-summary.md
      if git diff --staged --quiet; then
        printf \"No changes\\n\"
        exit 0
      fi
      echo \"Should not reach here\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"No changes"* ]]
}

@test "workflow script creates PR if none exists" {
    touch "$BATS_TMPDIR_WORKFLOW/has_changes"
    run bash -c "
      PR_BRANCH=\"ci/status-update\"
      EXISTING_PR=\$(gh pr list --head \"$PR_BRANCH\" --state open --json number --jq \".[0].number\" 2>/dev/null)
      if [ -n \"\$EXISTING_PR\" ]; then
        echo \"PR #\$EXISTING_PR already exists for \$PR_BRANCH\"
        exit 0
      fi
      gh pr create --title \"test\" --body \"test\" --base \"$TARGET_BRANCH\" --head \"$PR_BRANCH\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Created PR"* ]]
}

@test "workflow script reuses PR if exists" {
    touch "$BATS_TMPDIR_WORKFLOW/has_changes"
    touch "$BATS_TMPDIR_WORKFLOW/pr_exists"
    run bash -c "
      PR_BRANCH=\"ci/status-update\"
      EXISTING_PR=\$(gh pr list --head \"$PR_BRANCH\" --state open --json number --jq \".[0].number\" 2>/dev/null)
      if [ -n \"\$EXISTING_PR\" ]; then
        echo \"PR #\$EXISTING_PR already exists for \$PR_BRANCH\"
        exit 0
      fi
      gh pr create --title \"test\" --body \"test\" --base \"$TARGET_BRANCH\" --head \"$PR_BRANCH\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"PR #999 already exists for ci/status-update"* ]]
    [[ "$output" != *"Created PR"* ]]
}
