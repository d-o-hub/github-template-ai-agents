#!/usr/bin/env bash
# check_ci_status_freshness.sh - Validate committed CI status freshness and optional GitHub run parity.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly CI_STATUS_FILE="${REPO_ROOT}/.github/ci-status/ci-status.json"
readonly DEFAULT_CI_STATUS_MAX_AGE_SECONDS=86400
readonly DEFAULT_CI_STATUS_BRANCH="main"
readonly DEFAULT_CI_STATUS_RUN_LIMIT=5

ci_status_max_age_seconds="${CI_STATUS_MAX_AGE_SECONDS:-$DEFAULT_CI_STATUS_MAX_AGE_SECONDS}"
ci_status_branch="${CI_STATUS_BRANCH:-$DEFAULT_CI_STATUS_BRANCH}"
ci_status_run_limit="${CI_STATUS_RUN_LIMIT:-$DEFAULT_CI_STATUS_RUN_LIMIT}"
gh_runs_json=""
gh_checked="false"

usage() {
  cat <<USAGE
Usage: CI_STATUS_MAX_AGE_SECONDS=<seconds> $0

Validates .github/ci-status/ci-status.json for required fields and freshness.
If gh is installed and authenticated, compares the file to recent CI runs on
"${DEFAULT_CI_STATUS_BRANCH}" (override with CI_STATUS_BRANCH).
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

REQUIRED_FIELDS = ("status", "last_run", "failing_jobs", "workflow_url")
STALE_STATUS_MESSAGE = "CI status is stale"
INCONSISTENT_PASSING_MESSAGE = "CI status says passing, but recent GitHub runs disagree"
BAD_REMOTE_CONCLUSIONS = {"failure", "cancelled", "timed_out", "action_required"}
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

status = data.get("status")
if status is not None and not isinstance(status, str):
    errors.append("status must be a string")

failing_jobs = data.get("failing_jobs")
if failing_jobs is not None and not isinstance(failing_jobs, list):
    errors.append("failing_jobs must be a JSON array")

workflow_url = data.get("workflow_url")
if workflow_url is not None and not isinstance(workflow_url, str):
    errors.append("workflow_url must be a string")

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
        if run_created is not None and run_created > last_run:
            errors.append(
                f"{INCONSISTENT_PASSING_MESSAGE}: run newer than last_run ({run_created.isoformat()} {run_url})"
            )
        if run_conclusion in BAD_REMOTE_CONCLUSIONS:
            errors.append(
                f"{INCONSISTENT_PASSING_MESSAGE}: conclusion={run_conclusion} ({run_url})"
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
print(f"OK: CI status JSON is fresh and valid ({remote_summary}).")
PY
