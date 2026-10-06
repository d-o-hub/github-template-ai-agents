#!/usr/bin/env bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    SCRIPT="$REPO_ROOT/scripts/cleanup-ci-status-prs.sh"
    export MOCK_DIR="$BATS_TEST_TMPDIR/cleanup"
    mkdir -p "$MOCK_DIR/bin"
    export MOCK_PRS="$MOCK_DIR/prs.json" MOCK_LOG="$MOCK_DIR/gh.jsonl"
    export REAL_DATE
    REAL_DATE=$(command -v date)
    export MOCK_NOW
    MOCK_NOW=$(python3 -c 'from datetime import datetime, timezone; print(int(datetime(2026, 10, 5, tzinfo=timezone.utc).timestamp()))')
    export MOCK_FAIL_AUTH=false MOCK_FAIL_REPO=false MOCK_FAIL_LIST=false MOCK_FAIL_CLOSE=false
    printf '[]\n' > "$MOCK_PRS"
    : > "$MOCK_LOG"
    cat > "$MOCK_DIR/bin/gh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
jq -cn --args '$ARGS.positional' -- "$@" >> "$MOCK_LOG"
case "$1 $2" in
  'auth status')
    if [[ "$MOCK_FAIL_AUTH" == true ]]; then
      printf 'HTTP 401: invalid token\n' >&2
      exit 1
    fi ;;
  'repo view')
    if [[ "$MOCK_FAIL_REPO" == true ]]; then
      printf 'HTTP 403: repository access denied\n' >&2
      exit 1
    fi
    printf 'owner/repo\n' ;;
  'pr list')
    if [[ "$MOCK_FAIL_LIST" == true ]]; then
      printf 'HTTP 403: API rate limit exceeded\n' >&2
      exit 1
    fi
    cat "$MOCK_PRS" ;;
  'pr close')
    if [[ "$MOCK_FAIL_CLOSE" == true ]]; then
      printf 'HTTP 403: branch deletion denied\n' >&2
      exit 1
    fi ;;
  *) printf 'Unexpected gh command: %s\n' "$*" >&2; exit 99 ;;
esac
MOCK
    cat > "$MOCK_DIR/bin/date" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${MOCK_NO_DATE_D:-false}" == true ]]; then
    for arg in "$@"; do
        if [[ "$arg" == -d ]]; then
            printf 'date: illegal option -- d\n' >&2
            exit 1
        fi
    done
fi
if [[ "$*" == '-u +%s' ]]; then
    if [[ "$MOCK_NOW" == unavailable ]]; then
        printf 'Clock unavailable\n' >&2
        exit 1
    fi
    printf '%s\n' "$MOCK_NOW"
else
    exec "$REAL_DATE" "$@"
fi
MOCK
    chmod +x "$MOCK_DIR/bin/gh" "$MOCK_DIR/bin/date"
    export PATH="$MOCK_DIR/bin:$PATH"
}

add_pr() {
    local number="$1" login="$2" branch="$3" title="$4" timestamp="$5"
    jq --argjson number "$number" --arg login "$login" --arg branch "$branch" \
        --arg title "$title" --arg timestamp "$timestamp" \
        '. + [{number: $number, author: {login: $login}, headRefName: $branch,
               title: $title, createdAt: $timestamp}]' "$MOCK_PRS" > "$MOCK_PRS.next"
    mv "$MOCK_PRS.next" "$MOCK_PRS"
}

add_aged_pr() {
    local age="$5" timestamp
    timestamp=$(python3 - "$((MOCK_NOW - age))" <<'PY'
import sys
from datetime import datetime, timezone

print(datetime.fromtimestamp(int(sys.argv[1]), tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
    )
    add_pr "$1" "$2" "$3" "$4" "$timestamp"
}

closed_numbers() {
    jq -sc '[.[] | select(.[0:2] == ["pr", "close"]) | .[2] | tonumber] | sort' "$MOCK_LOG"
}

assert_no_mutations() {
    # Only these three read-only commands are permitted. Unknown commands fail
    # the mock too, so a fallback DELETE/edit cannot accidentally call real gh.
    jq -se 'all(.[]; .[0:2] == ["auth", "status"] or .[0:2] == ["repo", "view"] or
                     .[0:2] == ["pr", "list"])' "$MOCK_LOG" >/dev/null
}

run_workflow() {
    local dry_run="$1" workflow_run
    # Execute the actual workflow block, not a second implementation of its if.
    workflow_run=$(python3 - "$REPO_ROOT/.github/workflows/cleanup-ci-status-prs.yml" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as stream:
    workflow = yaml.safe_load(stream)
steps = workflow["jobs"]["cleanup"]["steps"]
print(next(step["run"] for step in steps if step["name"] == "Run automated PR cleanup"))
PY
    )
    run env DRY_RUN="$dry_run" MOCK_FAIL_LIST="${2:-false}" bash -c "$workflow_run"
}

@test "empty snapshot succeeds without mutation" {
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Cleanup complete.'* ]]
    assert_no_mutations
}

@test "CI artifact selector accepts both bot identities and retains fresh PRs" {
    add_aged_pr 101 app/github-actions ci/ci-status-update 'ci: update ci status artifacts [skip ci]' 21600
    add_aged_pr 102 'github-actions[bot]' ci/ci-status-update 'ci: update ci status artifacts' 21601
    add_aged_pr 103 app/github-actions ci/ci-status-update 'ci: update ci status artifacts [skip ci]' 21599
    add_aged_pr 104 'github-actions[bot]' ci/ci-status-update 'ci: update ci status artifacts' 0
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = '[101,102]' ]
    [[ "$output" != *'Closing PR #103'* && "$output" != *'Closing PR #104'* ]]
}

@test "LLM artifact selector accepts both bot identities at six hours" {
    add_aged_pr 201 app/github-actions auto/regenerate-llms-txt 'ci: regenerate llms.txt and llms-full.txt' 21600
    add_aged_pr 202 'github-actions[bot]' auto/regenerate-llms-txt 'ci: regenerate llms.txt and llms-full.txt [skip ci]' 21601
    add_aged_pr 203 app/github-actions auto/regenerate-llms-txt 'ci: regenerate llms.txt and llms-full.txt' 21599
    add_aged_pr 204 'github-actions[bot]' auto/regenerate-llms-txt 'ci: regenerate llms.txt and llms-full.txt' 0
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = '[201,202]' ]
}

@test "generic auto and ci PRs require at least 24 hours for either bot identity" {
    add_aged_pr 301 app/github-actions auto/catalog 'ci: refresh catalog' 86400
    add_aged_pr 302 'github-actions[bot]' ci/docs 'ci: refresh docs' 86401
    add_aged_pr 303 app/github-actions ci/docs 'ci: refresh docs' 86399
    add_aged_pr 304 'github-actions[bot]' auto/catalog 'ci: refresh catalog' 21601
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = '[301,302]' ]
}

@test "six-hour cleanup requires the title and its matching canonical branch" {
    add_aged_pr 401 app/github-actions ci/ci-status-update 'fix: unrelated change' 21601
    add_aged_pr 402 'github-actions[bot]' auto/other 'ci: update ci status artifacts' 21601
    add_aged_pr 403 app/github-actions ci/ci-status-update 'ci: update ci status artifacts for another project' 21601
    add_aged_pr 404 app/github-actions ci/other 'ci: regenerate llms.txt and llms-full.txt' 21601
    add_aged_pr 405 app/github-actions auto/regenerate-llms-txt 'ci: update ci status artifacts' 21601
    add_aged_pr 406 app/github-actions ci/ci-status-update 'fix: unrelated change' 86400
    add_aged_pr 407 'github-actions[bot]' auto/other 'ci: update ci status artifacts' 86400
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = '[406,407]' ]
}

@test "unrelated authors and branches are retained even when ancient" {
    add_aged_pr 501 contributor ci/ci-status-update 'ci: update ci status artifacts' 172800
    add_aged_pr 502 dependabot ci/ci-status-update 'ci: update ci status artifacts' 172800
    add_aged_pr 503 app/github-actions feature/ci-status 'ci: update ci status artifacts' 172800
    add_aged_pr 504 'github-actions[bot]' automation/catalog 'ci: refresh catalog' 172800
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    assert_no_mutations
}

@test "invalid missing empty and future timestamps never imply stale" {
    add_pr 601 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 'not-a-date'
    add_pr 602 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' ''
    add_pr 603 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' '2026-02-30T00:00:00Z'
    add_pr 604 'github-actions[bot]' auto/docs 'ci: refresh docs' '2026-10-06T00:00:00Z'
    add_pr 605 'github-actions[bot]' auto/docs 'ci: refresh docs' '2020-01-01'
    add_pr 606 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' '2020-01-01T00:00:00Z'
    jq 'map(if .number == 606 then del(.createdAt) else . end)' "$MOCK_PRS" > "$MOCK_PRS.next"
    mv "$MOCK_PRS.next" "$MOCK_PRS"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *'WARNING: Retaining PR #601'* ]]
    assert_no_mutations
}

@test "calendar round-trip accepts leap day but rejects normalized invalid dates" {
    add_pr 611 app/github-actions auto/catalog 'ci: refresh catalog' '2024-02-29T23:59:59Z'
    add_pr 612 'github-actions[bot]' ci/ci-status-update 'ci: update ci status artifacts' '2025-02-29T00:00:00Z'
    add_pr 613 app/github-actions auto/catalog 'ci: refresh catalog' '2026-04-31T00:00:00Z'
    add_pr 614 'github-actions[bot]' ci/docs 'ci: refresh docs' '2026-01-01T24:00:00Z'
    add_pr 615 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' '2026-01-01T00:00:60Z'
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = '[611]' ]
}

@test "malformed PR numbers and metadata are never mutated" {
    add_aged_pr '"701"' app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 172800
    add_aged_pr 0 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 172800
    add_aged_pr 702 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 172800
    jq 'map(if .number == 702 then .headRefName = null else . end)' "$MOCK_PRS" > "$MOCK_PRS.next"
    mv "$MOCK_PRS.next" "$MOCK_PRS"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    assert_no_mutations
}

@test "dry-run reports exactly the live selection without any mutations" {
    add_aged_pr 801 app/github-actions ci/ci-status-update 'ci: update ci status artifacts [skip ci]' 21600
    add_aged_pr 802 'github-actions[bot]' auto/regenerate-llms-txt 'ci: regenerate llms.txt and llms-full.txt' 21600
    add_aged_pr 803 'github-actions[bot]' auto/catalog 'ci: refresh catalog' 86400
    add_aged_pr 804 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 21599
    add_aged_pr 805 app/github-actions auto/catalog 'ci: refresh catalog' 86399
    add_aged_pr 806 contributor ci/ci-status-update 'ci: update ci status artifacts' 172800
    add_pr 807 app/github-actions ci/docs 'ci: refresh docs' 'invalid'
    run bash "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    assert_no_mutations
    local dry_numbers
    dry_numbers=$(jq -Rsc '[split("\n")[] | capture("Would close PR #(?<n>[0-9]+)")? | .n | tonumber] | sort' <<< "$output")
    [ "$dry_numbers" = '[801,802,803]' ]
    : > "$MOCK_LOG"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = "$dry_numbers" ]
}

@test "BSD date without -d still selects stale PRs identically in dry-run and live mode" {
    export MOCK_NO_DATE_D=true
    # Verify the mock really rejects the GNU extension, not just its name.
    run date -u -d '2020-01-01T00:00:00Z' +%s
    [ "$status" -ne 0 ]
    [[ "$output" == *'date: illegal option -- d'* ]]

    add_aged_pr 1301 app/github-actions auto/catalog 'ci: refresh catalog' 86400
    add_aged_pr 1302 'github-actions[bot]' ci/docs 'ci: refresh docs' 86401
    add_aged_pr 1303 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 21600
    add_aged_pr 1304 'github-actions[bot]' auto/catalog 'ci: refresh catalog' 86399
    add_pr 1305 app/github-actions auto/catalog 'ci: refresh catalog' '2026-02-30T00:00:00Z'
    add_pr 1306 'github-actions[bot]' ci/docs 'ci: refresh docs' '2026-10-06T00:00:00Z'
    run bash "$SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    assert_no_mutations
    local dry_numbers
    dry_numbers=$(jq -Rsc '[split("\n")[] | capture("Would close PR #(?<n>[0-9]+)")? | .n | tonumber] | sort' <<< "$output")
    [ "$dry_numbers" = '[1301,1302,1303]' ]
    : > "$MOCK_LOG"
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = "$dry_numbers" ]
}

@test "one snapshot and one close per PR even when title and generic rules overlap" {
    add_aged_pr 901 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 172800
    add_aged_pr 901 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 172800
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = '[901]' ]
    jq -se '[.[] | select(.[0:2] == ["pr", "list"])] | length == 1' "$MOCK_LOG" >/dev/null
    jq -se 'all(.[] | select(.[0:2] == ["pr", "close"]);
        .[3:] == ["--repo", "owner/repo", "--delete-branch"])' "$MOCK_LOG" >/dev/null
}

@test "auth failure is visible and stops before repo lookup or listing" {
    export MOCK_FAIL_AUTH=true
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *'HTTP 401: invalid token'* && "$output" == *'ERROR: gh not authenticated'* ]]
    jq -se '. == [["auth", "status"]]' "$MOCK_LOG" >/dev/null
}

@test "repository lookup failure is visible and stops before listing" {
    export MOCK_FAIL_REPO=true
    run bash "$SCRIPT" --dry-run
    [ "$status" -ne 0 ]
    [[ "$output" == *'HTTP 403: repository access denied'* ]]
    assert_no_mutations
    jq -se 'all(.[]; .[0] != "pr")' "$MOCK_LOG" >/dev/null
}

@test "list API errors fail both live and dry-run rather than passing as empty" {
    local mode
    for mode in live dry; do
        : > "$MOCK_LOG"
        if [[ "$mode" == live ]]; then
            run env MOCK_FAIL_LIST=true bash "$SCRIPT"
        else
            run env MOCK_FAIL_LIST=true bash "$SCRIPT" --dry-run
        fi
        [ "$status" -ne 0 ]
        [[ "$output" == *'HTTP 403: API rate limit exceeded'* ]]
        [[ "$output" != *'Cleanup complete.'* ]]
        assert_no_mutations
    done
}

@test "invalid JSON or response shape fails before any mutation" {
    local response
    for response in '' 'not JSON' '{"message":"API error"}' 'null' '[] []'; do
        printf '%s\n' "$response" > "$MOCK_PRS"
        run bash "$SCRIPT"
        [ "$status" -ne 0 ]
        [[ "$output" == *'ERROR: Cannot parse automated PRs.'* ]]
        assert_no_mutations
    done
}

@test "unavailable or malformed current time fails before any mutation" {
    add_aged_pr 1000 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 172800
    local clock
    for clock in unavailable not-an-epoch; do
        run env MOCK_NOW="$clock" bash "$SCRIPT"
        [ "$status" -ne 0 ]
        [[ "$output" == *'ERROR:'* && "$output" != *'Cleanup complete.'* ]]
        assert_no_mutations
    done
}

@test "close failure is visible with no duplicate retry or fallback DELETE" {
    export MOCK_FAIL_CLOSE=true
    add_aged_pr 1001 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 172800
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *'HTTP 403: branch deletion denied'* && "$output" == *'ERROR: Cleanup failed for PR #1001'* ]]
    [[ "$output" != *'Cleanup complete.'* ]]
    [ "$(closed_numbers)" = '[1001]' ]
    jq -se 'all(.[]; .[0] != "api")' "$MOCK_LOG" >/dev/null
}

@test "unknown or extra arguments fail before any gh command" {
    run bash "$SCRIPT" --dry-run --unexpected
    [ "$status" -ne 0 ]
    [ ! -s "$MOCK_LOG" ]
    run bash "$SCRIPT" --unexpected
    [ "$status" -ne 0 ]
    [ ! -s "$MOCK_LOG" ]
}

@test "workflow dry-run executes the script selector and retains fresh PRs" {
    add_aged_pr 1101 app/github-actions ci/ci-status-update 'ci: update ci status artifacts' 21600
    add_aged_pr 1102 'github-actions[bot]' auto/catalog 'ci: refresh catalog' 86399
    run_workflow true
    [ "$status" -eq 0 ]
    [[ "$output" == *'Would close PR #1101'* && "$output" != *'Would close PR #1102'* ]]
    assert_no_mutations
}

@test "workflow live mode executes the same script and propagates errors" {
    add_aged_pr 1201 'github-actions[bot]' auto/catalog 'ci: refresh catalog' 86400
    run_workflow false
    [ "$status" -eq 0 ]
    [ "$(closed_numbers)" = '[1201]' ]
    run_workflow false true
    [ "$status" -ne 0 ]
    [[ "$output" == *'HTTP 403: API rate limit exceeded'* ]]
}
