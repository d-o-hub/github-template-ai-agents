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
      close) printf "Closing PR #%s\n" "$3" ;;
    esac
    ;;
  api) echo "API call: $*" ;;
esac
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    export PATH="$BATS_TMPDIR:$PATH"
}

@test "cleanup script identifies and closes PRs" {
    # Run script and capture output
    run ./scripts/cleanup-ci-status-prs.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"Closing PR #123"* ]]
    [[ "$output" == *"Closing PR #456"* ]]
}

@test "cleanup script deletes branches" {
    run ./scripts/cleanup-ci-status-prs.sh

    [ "$status" -eq 0 ]
    [[ "$output" == *"deleting branch branch-123"* ]]
    [[ "$output" == *"deleting branch branch-456"* ]]
}
