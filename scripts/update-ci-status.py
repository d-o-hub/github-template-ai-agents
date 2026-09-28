#!/usr/bin/env python3
"""Derive the committed CI status artifact from GitHub Actions `needs.<job>.result`.

Fail-closed by construction. GitHub reports a job skipped by an `if:` condition
as conclusion "Success", and a skipped job does **not** block a merge even when
it is a required check (https://docs.github.com/en/pull-requests/reference/status-checks).
`failure()` is likewise `false` for a skipped dependency, so any gate built from
`!failure()` or from a denylist of bad results reports green when the job that
mattered never ran. This module therefore asserts the *expected* value of every
required job and treats a skip as non-passing unless the job is explicitly
listed in the allowed-skips allowlist (best practice: allowlist skips, never
denylist them).

Usage:
    python3 scripts/update-ci-status.py            # write .github/ci-status/*
    python3 scripts/update-ci-status.py --check    # exit 0 only if status == passing

Environment:
    NEEDS_JSON              JSON of the aggregator job's `needs` context.
    WORKFLOW_URL            URL of the run being summarized.
    CI_STATUS_ALLOWED_SKIPS Comma/space separated allowlist of skippable job ids.
    CI_STATUS_TIMESTAMP     ISO-8601 run completion time (backfill provenance).
"""
import json
import os
import sys
from datetime import datetime, timezone

SCHEMA_VERSION = 3

# Tri-state contract. `skipped` is deliberately absent: a non-passing artifact
# that is not a red must read "unknown" so consumers cannot read it as green.
STATUS_PASSING = "passing"
STATUS_FAILING = "failing"
STATUS_UNKNOWN = "unknown"
TRISTATE_STATUSES = (STATUS_PASSING, STATUS_FAILING, STATUS_UNKNOWN)

# `needs.<job_id>.result` enum: success | failure | cancelled | skipped.
RESULT_SUCCESS = "success"
RESULT_FAILURE = "failure"
RESULT_CANCELLED = "cancelled"
RESULT_SKIPPED = "skipped"

# Check-run conclusions that are distinguishable from `failure` but still not
# green. `timed_out` is a definite non-success; `stale` means "unknown" and is
# lumped with any unrecognized result so the distinction is never collapsed
# into a red.
RESULT_TIMED_OUT = "timed_out"
BUCKET_UNRECOGNIZED = "unrecognized"

# Definite non-success results. Each keeps its own bucket in the artifact.
FAILING_RESULTS = (RESULT_FAILURE, RESULT_CANCELLED, RESULT_TIMED_OUT)

# Result -> artifact bucket. Anything absent lands in BUCKET_UNRECOGNIZED.
RESULT_BUCKETS = {
    RESULT_SUCCESS: RESULT_SUCCESS,
    RESULT_FAILURE: RESULT_FAILURE,
    RESULT_CANCELLED: RESULT_CANCELLED,
    RESULT_SKIPPED: RESULT_SKIPPED,
    RESULT_TIMED_OUT: RESULT_TIMED_OUT,
    "stale": BUCKET_UNRECOGNIZED,
    "neutral": BUCKET_UNRECOGNIZED,
    "action_required": BUCKET_UNRECOGNIZED,
}

# Empty by default: a required job must actually run to be certified green.
# Add a job id here only when the repo deliberately accepts its absence.
DEFAULT_ALLOWED_SKIPS = ()

# A committed JSON file is not a merge gate — anyone with write permission can
# set any status. Recorded in the artifact so consumers see it without docs.
ADVISORY_ONLY = True


def parse_allowed_skips(raw):
    """Parse the allowlist from a comma/space separated string."""
    if not raw:
        return set(DEFAULT_ALLOWED_SKIPS)
    tokens = raw.replace(",", " ").split()
    return {token for token in tokens if token}


def categorize_results(needs):
    """Bucket job ids by result, preserving non-`failure` distinctions."""
    buckets = {
        RESULT_SUCCESS: [],
        RESULT_FAILURE: [],
        RESULT_CANCELLED: [],
        RESULT_SKIPPED: [],
        RESULT_TIMED_OUT: [],
        BUCKET_UNRECOGNIZED: [],
    }
    for job_name, job_data in needs.items():
        result = job_data.get("result") if isinstance(job_data, dict) else None
        bucket = RESULT_BUCKETS.get(result, BUCKET_UNRECOGNIZED)
        buckets[bucket].append(job_name)
    return buckets


def derive(needs, allowed_skips=None):
    """Derive the tri-state status and every supporting list from `needs`.

    `passing` requires ALL of: no failing result, no unrecognized result, no
    skip outside the allowlist, and at least one job that actually succeeded.
    """
    allowed = set(allowed_skips or ())
    buckets = categorize_results(needs)

    skipped = sorted(buckets[RESULT_SKIPPED])
    tolerated = sorted(job for job in skipped if job in allowed)
    unallowed = sorted(job for job in skipped if job not in allowed)
    failing = sorted(job for result in FAILING_RESULTS for job in buckets[result])
    unrecognized = sorted(buckets[BUCKET_UNRECOGNIZED])
    succeeded = sorted(buckets[RESULT_SUCCESS])

    if failing:
        status = STATUS_FAILING
    elif unrecognized:
        status = STATUS_UNKNOWN
    elif unallowed:
        # Fail-closed: the gate is unsatisfied, and we cannot call it red.
        status = STATUS_UNKNOWN
    elif succeeded:
        status = STATUS_PASSING
    else:
        # Nothing ran and succeeded: no validation happened.
        status = STATUS_UNKNOWN

    validated = status == STATUS_PASSING and bool(succeeded)

    return {
        "status": status,
        "validated": validated,
        "failing_jobs": failing,
        "skipped_jobs": skipped,
        "allowed_skips": tolerated,
        "declared_allowed_skips": sorted(allowed),
        "unallowed_skips": unallowed,
        "cancelled_jobs": sorted(buckets[RESULT_CANCELLED]),
        "timed_out_jobs": sorted(buckets[RESULT_TIMED_OUT]),
        "unknown_jobs": unrecognized,
        "succeeded_jobs": succeeded,
    }


def build_artifact(derivation, last_run, workflow_url):
    """Assemble the ci-status.json payload."""
    return {
        "schema_version": SCHEMA_VERSION,
        "status": derivation["status"],
        "last_run": last_run,
        "validated": derivation["validated"],
        "failing_jobs": derivation["failing_jobs"],
        "skipped_jobs": derivation["skipped_jobs"],
        "allowed_skips": derivation["allowed_skips"],
        "unallowed_skips": derivation["unallowed_skips"],
        "cancelled_jobs": derivation["cancelled_jobs"],
        "timed_out_jobs": derivation["timed_out_jobs"],
        "unknown_jobs": derivation["unknown_jobs"],
        "succeeded_jobs": derivation["succeeded_jobs"],
        "advisory_only": ADVISORY_ONLY,
        "workflow_url": workflow_url,
    }


def build_summary(derivation, artifact):
    """Render ci-summary.md from the same derivation as the JSON artifact.

    Built as sections so blank-line rules (markdownlint MD022/MD012) always
    hold: exactly one blank line between blocks and a single trailing newline.
    """
    emojis = {
        RESULT_SUCCESS: "✅",
        RESULT_FAILURE: "❌",
        RESULT_CANCELLED: "⛔",
        RESULT_SKIPPED: "⏭️",
        RESULT_TIMED_OUT: "⏱️",
    }
    needs = {}
    for job in derivation["succeeded_jobs"]:
        needs[job] = RESULT_SUCCESS
    for job in derivation["failing_jobs"]:
        needs[job] = RESULT_FAILURE if job not in derivation["cancelled_jobs"] else RESULT_CANCELLED
    for job in derivation["timed_out_jobs"]:
        needs[job] = RESULT_TIMED_OUT
    for job in derivation["skipped_jobs"]:
        needs[job] = RESULT_SKIPPED
    for job in derivation["unknown_jobs"]:
        needs[job] = BUCKET_UNRECOGNIZED

    sections = [
        "# CI Summary",
        "",
        f"Latest CI status: **{artifact['status']}**",
        "",
        f"- **Last Run:** {artifact['last_run']}",
        f"- **Schema Version:** {artifact['schema_version']}",
        f"- **Workflow URL:** [{artifact['workflow_url']}]({artifact['workflow_url']})",
    ]
    if derivation["unallowed_skips"]:
        jobs = ", ".join(derivation["unallowed_skips"])
        sections += [
            "",
            f"> ⚠️ Required jobs skipped outside the allowlist: {jobs}",
            ">",
            "> This artifact is **advisory**. Only a required status check can block a",
            "> merge; see [GitHub docs on status checks](https://docs.github.com/en/pull-requests/reference/status-checks)",
        ]
    sections += ["", "## Job Status", "", "| Job | Result |", "| --- | --- |"]
    for job in sorted(needs.keys()):
        result = needs[job]
        suffix = " (allowlisted)" if job in derivation["allowed_skips"] else ""
        sections.append(f"| {job} | {emojis.get(result, '⚠️')} {result}{suffix} |")

    return "\n".join(sections) + "\n"


def get_ci_dir():
    """Return path to .github/ci-status/ directory, creating it if needed."""
    ci_dir = os.path.join(os.getcwd(), ".github", "ci-status")
    os.makedirs(ci_dir, exist_ok=True)
    return ci_dir


def run_gate(derivation, needs):
    """Fail-closed gate: explicit expected-value assertion per required job."""
    problems = []
    if not needs:
        # Vacuous truth is fail-open: with no `needs` there is nothing to assert.
        problems.append("no required jobs reported; cannot certify the gate")
    for job in sorted(needs.keys()):
        result = needs[job].get("result") if isinstance(needs[job], dict) else None
        if result == RESULT_SUCCESS or job in derivation["allowed_skips"]:
            continue
        problems.append(f"{job}: expected 'success', got '{result}'")
    satisfied = sorted(derivation["succeeded_jobs"] + derivation["allowed_skips"])
    for problem in problems:
        print(f"Required job did not succeed -> {problem}", file=sys.stderr)
    if problems:
        print(f"CI gate NOT satisfied (status={derivation['status']}).", file=sys.stderr)
        return 1
    print(f"CI gate satisfied: {', '.join(satisfied) or '(no jobs)'}")
    return 0


def main():
    check_only = "--check" in sys.argv[1:]
    needs_json = os.environ.get("NEEDS_JSON", "{}")
    workflow_url = os.environ.get("WORKFLOW_URL", "")

    try:
        needs = json.loads(needs_json)
    except json.JSONDecodeError:
        print(f"Error decoding NEEDS_JSON: {needs_json}", file=sys.stderr)
        return 1
    if not isinstance(needs, dict):
        print(f"NEEDS_JSON must be a JSON object, got: {type(needs).__name__}", file=sys.stderr)
        return 1

    allowed_skips = parse_allowed_skips(os.environ.get("CI_STATUS_ALLOWED_SKIPS", ""))
    derivation = derive(needs, allowed_skips)

    if check_only:
        return run_gate(derivation, needs)

    last_run = os.environ.get("CI_STATUS_TIMESTAMP", "").strip()
    if not last_run:
        last_run = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    artifact = build_artifact(derivation, last_run, workflow_url)
    ci_dir = get_ci_dir()
    with open(os.path.join(ci_dir, "ci-status.json"), "w", encoding="utf-8") as handle:
        json.dump(artifact, handle, indent=2)
        handle.write("\n")
    with open(os.path.join(ci_dir, "ci-summary.md"), "w", encoding="utf-8") as handle:
        handle.write(build_summary(derivation, artifact))

    print(f"CI status updated to: {artifact['status']}")
    if artifact["unallowed_skips"]:
        print(
            "NOT passing: required job(s) skipped outside the allowlist: "
            f"{', '.join(artifact['unallowed_skips'])}",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
