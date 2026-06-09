#!/usr/bin/env bats

setup() {
    export TEST_REPO="$BATS_TMPDIR/repo"
    mkdir -p "$TEST_REPO/scripts" "$TEST_REPO/.github/ci-status"
    cp ./scripts/check_ci_status_freshness.sh "$TEST_REPO/scripts/check_ci_status_freshness.sh"
    chmod +x "$TEST_REPO/scripts/check_ci_status_freshness.sh"
}

write_status_file() {
    local timestamp="$1"
    cat > "$TEST_REPO/.github/ci-status/ci-status.json" <<JSON
{
  "status": "passing",
  "last_run": "$timestamp",
  "failing_jobs": [],
  "workflow_url": "https://example.test/actions/runs/1"
}
JSON
}

utc_timestamp_seconds_ago() {
    local seconds_ago="$1"
    python3 - "$seconds_ago" <<'PY'
import sys
from datetime import datetime, timedelta, timezone
seconds = int(sys.argv[1])
print((datetime.now(timezone.utc) - timedelta(seconds=seconds)).isoformat().replace("+00:00", "Z"))
PY
}

@test "fresh committed CI status passes without gh" {
    write_status_file "$(utc_timestamp_seconds_ago 60)"
    run env PATH="/usr/bin:/bin" "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"OK: CI status JSON is fresh and valid"* ]]
    [[ "$output" == *"skipping remote CI comparison"* ]]
}

@test "stale committed CI status fails" {
    write_status_file "$(utc_timestamp_seconds_ago 120)"

    run env CI_STATUS_MAX_AGE_SECONDS=1 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"CI status is stale"* ]]
}

@test "missing required CI status fields fail validation" {
    cat > "$TEST_REPO/.github/ci-status/ci-status.json" <<'JSON'
{
  "status": "passing",
  "last_run": "2026-06-09T00:00:00Z"
}
JSON

    run "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"missing required field: failing_jobs"* ]]
    [[ "$output" == *"missing required field: workflow_url"* ]]
}

@test "passing committed status fails when authenticated gh reports newer run" {
    local last_run newer_run
    last_run="$(utc_timestamp_seconds_ago 120)"
    newer_run="$(utc_timestamp_seconds_ago 60)"
    write_status_file "$last_run"
    cat > "$BATS_TMPDIR/gh" <<MOCK
#!/usr/bin/env bash
if [[ "\$1" == "auth" && "\$2" == "status" ]]; then
  exit 0
fi
if [[ "\$1" == "run" && "\$2" == "list" ]]; then
  cat <<JSON
[{"status":"completed","conclusion":"success","createdAt":"$newer_run","url":"https://example.test/actions/runs/2"}]
JSON
  exit 0
fi
exit 1
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    run env PATH="$BATS_TMPDIR:$PATH" CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"run newer than last_run"* ]]
}

@test "passing committed status fails when authenticated gh reports cancelled run" {
    write_status_file "$(utc_timestamp_seconds_ago 60)"
    cat > "$BATS_TMPDIR/gh" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == "auth" && "$2" == "status" ]]; then
  exit 0
fi
if [[ "$1" == "run" && "$2" == "list" ]]; then
  cat <<'JSON'
[{"status":"completed","conclusion":"cancelled","createdAt":"2026-06-09T00:00:00Z","url":"https://example.test/actions/runs/3"}]
JSON
  exit 0
fi
exit 1
MOCK
    chmod +x "$BATS_TMPDIR/gh"
    run env PATH="$BATS_TMPDIR:$PATH" "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"conclusion=cancelled"* ]]
}
