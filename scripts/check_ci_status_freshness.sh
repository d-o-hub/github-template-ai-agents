#!/usr/bin/env bash
# check_ci_status_freshness.sh - Validate committed CI status freshness and optional GitHub run parity.
#
# Validates the fail-closed tri-state contract (schema v3) of
# .github/ci-status/ci-status.json:
#   * status is one of passing | failing | unknown;
#   * `passing` is never claimed alongside a failing job, an unrecognized job
#     result, or a skip that is outside the `allowed_skips` allowlist;
#   * the job lists are mutually consistent with the declared status.
# The artifact is ADVISORY: a committed file is not a merge gate (anybody with
# write permission can set any status). Only a required status check can block
# a merge. See https://docs.github.com/en/pull-requests/reference/status-checks
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly CI_STATUS_FILE="${REPO_ROOT}/.github/ci-status/ci-status.json"
readonly DEFAULT_CI_STATUS_MAX_AGE_SECONDS=86400
readonly DEFAULT_CI_STATUS_BRANCH="main"
readonly DEFAULT_CI_STATUS_RUN_LIMIT=5
readonly DEFAULT_CI_STATUS_WORKFLOW="ci.yml"

ci_status_max_age_seconds="${CI_STATUS_MAX_AGE_SECONDS:-$DEFAULT_CI_STATUS_MAX_AGE_SECONDS}"
ci_status_branch="${CI_STATUS_BRANCH:-$DEFAULT_CI_STATUS_BRANCH}"
ci_status_run_limit="${CI_STATUS_RUN_LIMIT:-$DEFAULT_CI_STATUS_RUN_LIMIT}"
# ci-status.json describes the CI gate (ci.yml) only. Comparing against runs of
# other workflows (e.g. CodeQL's default-setup "dynamic" runs, which fire on
# every push to main regardless of [skip ci]) would flag the committed status
# as stale right after every artifact merge.
ci_status_workflow="${CI_STATUS_WORKFLOW:-$DEFAULT_CI_STATUS_WORKFLOW}"
gh_runs_json=""
gh_checked="false"

usage() {
  cat <<USAGE
Usage: CI_STATUS_MAX_AGE_SECONDS=<seconds> $0

Validates .github/ci-status/ci-status.json for required fields and freshness.
If gh is installed and authenticated, compares the file to recent runs of the
"${DEFAULT_CI_STATUS_WORKFLOW}" gate workflow on "${DEFAULT_CI_STATUS_BRANCH}"
(override with CI_STATUS_BRANCH / CI_STATUS_WORKFLOW).
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if ! [[ "$ci_status_max_age_seconds" =~ ^[0-9]+$ ]]; then
  printf 'ERROR: CI_STATUS_MAX_AGE_SECONDS must be a non-negative integer, got: %s\n' \
    "$ci_status_max_age_seconds" >&2
  exit 1
fi

if ! [[ "$ci_status_run_limit" =~ ^[0-9]+$ ]] || [[ "$ci_status_run_limit" -eq 0 ]]; then
  printf 'ERROR: CI_STATUS_RUN_LIMIT must be a positive integer, got: %s\n' \
    "$ci_status_run_limit" >&2
  exit 1
fi

if [[ ! -f "$CI_STATUS_FILE" ]]; then
  printf 'ERROR: CI status file not found: %s\n' "$CI_STATUS_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'ERROR: python3 is required to parse CI status JSON and timestamps.\n' >&2
  exit 1
fi

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  gh_checked="true"
  if ! gh_runs_json="$(gh run list \
    --branch "$ci_status_branch" \
    --workflow "$ci_status_workflow" \
    --limit "$ci_status_run_limit" \
    --json status,conclusion,createdAt,url)"; then
    printf 'WARNING: gh is authenticated but recent CI runs could not be fetched; skipping remote comparison.\n' >&2
    gh_checked="false"
    gh_runs_json=""
  fi
else
  printf 'INFO: gh is unavailable or unauthenticated; skipping remote CI comparison.\n'
fi

CI_STATUS_MAX_AGE_SECONDS="$ci_status_max_age_seconds" \
CI_STATUS_PATH="$CI_STATUS_FILE" \
GH_CHECKED="$gh_checked" \
GH_RUNS_JSON="$gh_runs_json" \
python3 - <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

REQUIRED_FIELDS = (
    "schema_version",
    "status",
    "last_run",
    "validated",
    "failing_jobs",
    "skipped_jobs",
    "allowed_skips",
    "unallowed_skips",
    "cancelled_jobs",
    "timed_out_jobs",
    "unknown_jobs",
    "succeeded_jobs",
    "advisory_only",
    "workflow_url",
)
LIST_FIELDS = (
    "failing_jobs",
    "skipped_jobs",
    "allowed_skips",
    "unallowed_skips",
    "cancelled_jobs",
    "timed_out_jobs",
    "unknown_jobs",
    "succeeded_jobs",
)
MIN_SCHEMA_VERSION = 3
TRISTATE_STATUSES = ("passing", "failing", "unknown")
STALE_STATUS_MESSAGE = "CI status is stale"
INCONSISTENT_PASSING_MESSAGE = "CI status says passing, but recent GitHub runs disagree"
CONTRADICTION_MESSAGE = "self-contradictory CI status"
FALSE_GREEN_MESSAGE = "CI status says passing, but validated is false (all jobs skipped/unknown)"
NOT_PASSING_MESSAGE = "CI status is not passing"
ADVISORY_MESSAGE = "artifact is not marked advisory_only; a committed file is not a merge gate"
# `stale`/`neutral`/`skipped` are not green; only `success` certifies a run.
GOOD_REMOTE_CONCLUSION = "success"
BAD_REMOTE_CONCLUSIONS = {
    "failure",
    "cancelled",
    "timed_out",
    "action_required",
    "stale",
    "neutral",
    "skipped",
}
INCOMPLETE_REMOTE_STATUSES = {"queued", "in_progress", "waiting", "requested", "pending"}

status_file = os.environ["CI_STATUS_PATH"]
max_age_seconds = int(os.environ["CI_STATUS_MAX_AGE_SECONDS"])
gh_checked = os.environ["GH_CHECKED"] == "true"
gh_runs_json = os.environ.get("GH_RUNS_JSON", "")
errors = []
warnings = []


def parse_time(value, field_name):
    if not isinstance(value, str) or not value.strip():
        errors.append(f"{field_name} must be a non-empty ISO-8601 string")
        return None
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        errors.append(f"{field_name} is not valid ISO-8601: {value}")
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


try:
    with open(status_file, encoding="utf-8") as handle:
        data = json.load(handle)
except json.JSONDecodeError as exc:
    print(f"ERROR: CI status file is not valid JSON: {exc}", file=sys.stderr)
    sys.exit(1)

if not isinstance(data, dict):
    print("ERROR: CI status JSON must be an object", file=sys.stderr)
    sys.exit(1)

for field in REQUIRED_FIELDS:
    if field not in data:
        errors.append(f"missing required field: {field}")

schema_version = data.get("schema_version")
if schema_version is not None and (
    not isinstance(schema_version, int) or schema_version < MIN_SCHEMA_VERSION
):
    errors.append(
        f"schema_version must be an integer >= {MIN_SCHEMA_VERSION}, got: {schema_version!r}"
    )

status = data.get("status")
if status is not None and not isinstance(status, str):
    errors.append("status must be a string")
elif status is not None and status not in TRISTATE_STATUSES:
    errors.append(
        f"status must be one of {', '.join(TRISTATE_STATUSES)}, got: {status!r}"
    )

lists = {}
for field in LIST_FIELDS:
    value = data.get(field)
    if value is None:
        continue
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        errors.append(f"{field} must be a JSON array of strings")
        continue
    lists[field] = sorted(value)

validated = data.get("validated")
if validated is not None and not isinstance(validated, bool):
    errors.append("validated must be a boolean")

advisory_only = data.get("advisory_only")
if advisory_only is not None and not isinstance(advisory_only, bool):
    errors.append("advisory_only must be a boolean")
elif advisory_only is not True:
    warnings.append(ADVISORY_MESSAGE)

workflow_url = data.get("workflow_url")
if workflow_url is not None and not isinstance(workflow_url, str):
    errors.append("workflow_url must be a string")

# --- Coherence: the artifact must never contradict itself -------------------
# GitHub reports an `if:`-skipped job as "Success" and does not block merging
# even as a required check, so `passing` alongside a skip is the exact
# false-green this repo has shipped before. Allowlisted skips are the only
# tolerated kind.
skipped = lists.get("skipped_jobs", [])
allowed = lists.get("allowed_skips", [])
unallowed = lists.get("unallowed_skips", [])
failing = lists.get("failing_jobs", [])
unrecognized = lists.get("unknown_jobs", [])
cancelled = lists.get("cancelled_jobs", [])
timed_out = lists.get("timed_out_jobs", [])
succeeded = lists.get("succeeded_jobs", [])

# This contradiction needs only two scalar fields, so it is checked even when
# other fields are missing or malformed.
if status == "passing" and validated is False:
    errors.append(FALSE_GREEN_MESSAGE)

# Cross-field checks are meaningless until every list field is present and
# well-typed, so they run only once the structure itself is sound.
structure_ok = all(field in lists for field in LIST_FIELDS)

if structure_ok:
    if sorted(set(unallowed) | set(allowed)) != skipped:
        errors.append(
            f"{CONTRADICTION_MESSAGE}: allowed_skips + unallowed_skips "
            f"({sorted(set(allowed) | set(unallowed))}) must partition "
            f"skipped_jobs ({skipped})"
        )
    stale_allowlist = sorted(set(allowed) - set(skipped))
    if stale_allowlist:
        warnings.append(
            f"allowed_skips lists {stale_allowlist} but those jobs did not skip"
        )
    blocking_for_passing = []
    if failing:
        blocking_for_passing.append(f"failing_jobs={failing}")
    if unallowed:
        blocking_for_passing.append(f"unallowed_skips={unallowed}")
    if unrecognized:
        blocking_for_passing.append(f"unknown_jobs={unrecognized}")
    if cancelled:
        blocking_for_passing.append(f"cancelled_jobs={cancelled}")
    if timed_out:
        blocking_for_passing.append(f"timed_out_jobs={timed_out}")

    if status == "passing" and blocking_for_passing:
        errors.append(
            f"{CONTRADICTION_MESSAGE}: status=passing with " + ", ".join(blocking_for_passing)
        )
    if status == "passing" and not succeeded:
        errors.append(
            f"{CONTRADICTION_MESSAGE}: status=passing with no succeeded_jobs; "
            "nothing validated"
        )
    if status == "failing" and not failing:
        errors.append(
            f"{CONTRADICTION_MESSAGE}: status=failing with an empty failing_jobs"
        )
    if (
        status == "unknown"
        and not failing
        and not unallowed
        and not unrecognized
        and succeeded
    ):
        errors.append(
            f"{CONTRADICTION_MESSAGE}: status=unknown although every job succeeded"
        )

if status is not None and status != "passing":
    warnings.append(
        f"{NOT_PASSING_MESSAGE} ({status}); consumers must not treat it as green"
    )

last_run = parse_time(data.get("last_run"), "last_run") if "last_run" in data else None
now = datetime.now(timezone.utc)

if last_run is not None:
    age_seconds = (now - last_run).total_seconds()
    if age_seconds < 0:
        warnings.append("last_run is in the future relative to this system clock")
    elif age_seconds > max_age_seconds:
        errors.append(
            f"{STALE_STATUS_MESSAGE}: age={int(age_seconds)}s max={max_age_seconds}s"
        )

remote_runs = []
if gh_checked:
    try:
        remote_runs = json.loads(gh_runs_json)
    except json.JSONDecodeError as exc:
        errors.append(f"gh run list returned invalid JSON: {exc}")
    else:
        if not isinstance(remote_runs, list):
            errors.append("gh run list JSON must be an array")
            remote_runs = []

if gh_checked and last_run is not None and status == "passing":
    for run in remote_runs:
        if not isinstance(run, dict):
            continue
        run_created = parse_time(run.get("createdAt"), "createdAt")
        run_status = run.get("status")
        run_conclusion = run.get("conclusion")
        run_url = run.get("url", "<unknown-url>")
        if run_created is not None and run_created <= last_run:
            # Older than the committed status: already summarized by last_run
            # (e.g. runs cancelled because a newer push superseded them).
            continue
        if run_created is not None:
            errors.append(
                f"{INCONSISTENT_PASSING_MESSAGE}: run newer than last_run ({run_created.isoformat()} {run_url})"
            )
        if run_conclusion in BAD_REMOTE_CONCLUSIONS:
            errors.append(
                f"{INCONSISTENT_PASSING_MESSAGE}: conclusion={run_conclusion} ({run_url})"
            )
        elif run_conclusion is not None and run_conclusion != GOOD_REMOTE_CONCLUSION:
            warnings.append(
                f"newer run has unrecognized conclusion {run_conclusion!r} ({run_url})"
            )
        if run_status in INCOMPLETE_REMOTE_STATUSES:
            errors.append(
                f"{INCONSISTENT_PASSING_MESSAGE}: status={run_status} ({run_url})"
            )

for warning in warnings:
    print(f"WARNING: {warning}")

if errors:
    for error in errors:
        print(f"ERROR: {error}", file=sys.stderr)
    sys.exit(1)

remote_summary = "with gh comparison" if gh_checked else "without gh comparison"
if status != "passing":
    print(f"OK: CI status JSON is fresh and valid ({remote_summary}); status={status} is not green.")
else:
    print(f"OK: CI status JSON is fresh and valid ({remote_summary}).")
PY
