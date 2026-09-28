#!/usr/bin/env bats

setup() {
    export TEST_REPO="$BATS_TMPDIR/repo"
    mkdir -p "$TEST_REPO/scripts" "$TEST_REPO/.github/ci-status"
    cp ./scripts/check_ci_status_freshness.sh "$TEST_REPO/scripts/check_ci_status_freshness.sh"
    chmod +x "$TEST_REPO/scripts/check_ci_status_freshness.sh"
}

write_status_file() {
    local timestamp="$1"
    write_raw_status_file "$timestamp" passing '[]' '[]' '[]' '["quality-gate", "test"]' true
}

# write_raw_status_file <timestamp> <status> <failing> <skipped> <unallowed> <succeeded> <validated>
write_raw_status_file() {
    local timestamp="$1" status="$2" failing="$3" skipped="$4"
    local unallowed="$5" succeeded="$6" validated="$7"
    cat > "$TEST_REPO/.github/ci-status/ci-status.json" <<JSON
{
  "schema_version": 3,
  "status": "$status",
  "last_run": "$timestamp",
  "validated": $validated,
  "failing_jobs": $failing,
  "skipped_jobs": $skipped,
  "allowed_skips": [],
  "unallowed_skips": $unallowed,
  "cancelled_jobs": [],
  "timed_out_jobs": [],
  "unknown_jobs": [],
  "succeeded_jobs": $succeeded,
  "advisory_only": true,
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
    # Hermetic: local environments may have an authenticated gh in /usr/bin,
    # so shadow it with a stub whose auth check fails.
    mkdir -p "$BATS_TMPDIR/nogh"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TMPDIR/nogh/gh"
    chmod +x "$BATS_TMPDIR/nogh/gh"
    write_status_file "$(utc_timestamp_seconds_ago 60)"
    run env PATH="$BATS_TMPDIR/nogh:/usr/bin:/bin" "$TEST_REPO/scripts/check_ci_status_freshness.sh"

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
    [[ "$output" == *"missing required field: skipped_jobs"* ]]
    [[ "$output" == *"missing required field: validated"* ]]
    [[ "$output" == *"missing required field: schema_version"* ]]
    [[ "$output" == *"missing required field: allowed_skips"* ]]
    [[ "$output" == *"missing required field: advisory_only"* ]]
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
    # The cancelled run must be NEWER than the committed status: an older
    # cancellation is already summarized by last_run and is not a disagreement.
    local cancelled_run
    cancelled_run="$(utc_timestamp_seconds_ago 30)"
    write_status_file "$(utc_timestamp_seconds_ago 60)"
    cat > "$BATS_TMPDIR/gh" <<MOCK
#!/usr/bin/env bash
if [[ "\$1" == "auth" && "\$2" == "status" ]]; then
  exit 0
fi
if [[ "\$1" == "run" && "\$2" == "list" ]]; then
  cat <<JSON
[{"status":"completed","conclusion":"cancelled","createdAt":"$cancelled_run","url":"https://example.test/actions/runs/3"}]
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

@test "passing status with validated false is rejected as false-green" {
    local last_run
    last_run="$(utc_timestamp_seconds_ago 60)"
    write_raw_status_file "$last_run" passing '[]' '["quality-gate", "test"]' \
        '["quality-gate", "test"]' '[]' false

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"validated is false"* ]]
}

@test "passing status with an unallowlisted skip is rejected as self-contradictory" {
    # The exact false green this repo shipped: status=passing while a required
    # job was skipped. GitHub reports such a job as "Success" and does not
    # block merging even as a required check.
    write_raw_status_file "$(utc_timestamp_seconds_ago 60)" passing '[]' '["test"]' \
        '["test"]' '["quality-gate"]' true

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"self-contradictory CI status"* ]]
    [[ "$output" == *"unallowed_skips=['test']"* ]]
}

@test "passing status alongside a failing job is rejected as self-contradictory" {
    write_raw_status_file "$(utc_timestamp_seconds_ago 60)" passing '["test"]' '[]' '[]' \
        '["quality-gate"]' true

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"self-contradictory CI status"* ]]
    [[ "$output" == *"failing_jobs=['test']"* ]]
}

@test "unknown status with a skip is accepted and warned, not failed" {
    write_raw_status_file "$(utc_timestamp_seconds_ago 60)" unknown '[]' '["test"]' \
        '["test"]' '["quality-gate"]' false

    run env CI_STATUS_MAX_AGE_SECONDS=3600 \
        PATH="$BATS_TMPDIR/nogh:/usr/bin:/bin" \
        "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 0 ]
    [[ "$output" == *"CI status is not passing (unknown)"* ]]
    [[ "$output" == *"status=unknown is not green"* ]]
}

@test "non-tri-state status value is rejected" {
    # `skipped` was the pre-ADR-035 fourth value; the contract is tri-state.
    write_status_file "$(utc_timestamp_seconds_ago 60)"
    sed -i 's/"status": "passing"/"status": "skipped"/' \
        "$TEST_REPO/.github/ci-status/ci-status.json"

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"status must be one of passing, failing, unknown"* ]]
}

@test "stale schema version is rejected" {
    write_status_file "$(utc_timestamp_seconds_ago 60)"
    sed -i 's/"schema_version": 3/"schema_version": 2/' \
        "$TEST_REPO/.github/ci-status/ci-status.json"

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"schema_version must be an integer >= 3"* ]]
}

@test "unpartitioned skip lists are rejected as self-contradictory" {
    write_status_file "$(utc_timestamp_seconds_ago 60)"
    sed -i 's/"unallowed_skips": \[\]/"unallowed_skips": ["ghost"]/' \
        "$TEST_REPO/.github/ci-status/ci-status.json"

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"must partition skipped_jobs"* ]]
}

@test "unknown status with every job succeeded is rejected as self-contradictory" {
    write_raw_status_file "$(utc_timestamp_seconds_ago 60)" unknown '[]' '[]' '[]' \
        '["quality-gate", "test"]' false

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"status=unknown although every job succeeded"* ]]
}

@test "passing status with no succeeded job is rejected as self-contradictory" {
    write_raw_status_file "$(utc_timestamp_seconds_ago 60)" passing '[]' '[]' '[]' '[]' true

    run env CI_STATUS_MAX_AGE_SECONDS=3600 "$TEST_REPO/scripts/check_ci_status_freshness.sh"

    [ "$status" -eq 1 ]
    [[ "$output" == *"no succeeded_jobs"* ]]
}
