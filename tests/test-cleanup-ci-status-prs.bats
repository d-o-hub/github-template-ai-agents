#!/usr/bin/env bats

setup() {
    # Create mock gh
    cat << 'MOCK' > "$BATS_TMPDIR/gh"
#!/bin/bash
case "$1" in
  repo) echo "owner/repo" ;;
  pr)
    case "$2" in
      view) echo '{"state":"OPEN","headRefName":"branch-1"}' ;;
      list) echo -e "123 branch-123\n456 branch-456" ;;
      close) echo "Closing PR $3" ;;
    esac
    ;;
  api) echo "API call: $*" ;;
esac
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    export PATH="$BATS_TMPDIR:$PATH"
}

@test "cleanup script identifies and closes PRs" {
    # We need to set a fake GITHUB_TOKEN to avoid the check in the script if any
    # The script currently doesn't check for token explicitly at the top but gh command might.

    # Run script and capture output
    run ./scripts/cleanup-ci-status-prs.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"Closing PR #398"* ]]
    [[ "$output" == *"Closing PR #399"* ]]
    [[ "$output" == *"Closing PR #123"* ]]
}

@test "cleanup script deletes branches" {
    run ./scripts/cleanup-ci-status-prs.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleting branch branch-1"* ]]
    [[ "$output" == *"Deleting branch branch-123"* ]]
}
