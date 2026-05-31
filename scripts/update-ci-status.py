#!/usr/bin/env python3
import json
import os
import sys
from datetime import datetime, timezone

def get_job_results(needs):
    """Categorize job results."""
    results = {"failure": [], "success": [], "skipped": [], "cancelled": []}
    for job_name, job_data in needs.items():
        result = job_data.get("result")
        if result in results:
            results[result].append(job_name)
        else:
            results.setdefault("unknown", []).append(job_name)
    return results

def determine_status(results):
    """Determine overall status."""
    if results["failure"] or results["cancelled"]:
        return "failing"
    return "passing"

def get_ci_dir():
    """Return path to .github/ci-status/ directory, creating it if needed."""
    ci_dir = os.path.join(os.getcwd(), ".github", "ci-status")
    os.makedirs(ci_dir, exist_ok=True)
    return ci_dir

def update_json(status, last_run, failing_jobs, workflow_url):
    """Update ci-status.json."""
    ci_status = {
        "status": status,
        "last_run": last_run,
        "failing_jobs": failing_jobs,
        "workflow_url": workflow_url
    }
    path = os.path.join(get_ci_dir(), "ci-status.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(ci_status, f, indent=2)
        f.write("\n")

def update_markdown(status, last_run, workflow_url, needs):
    """Update ci-summary.md."""
    emojis = {
        "success": "✅",
        "failure": "❌",
        "skipped": "⏭️"
    }

    path = os.path.join(get_ci_dir(), "ci-summary.md")
    with open(path, "w", encoding="utf-8") as f:
        f.write("# CI Summary\n\n")
        f.write(f"Latest CI status: **{status}**\n\n")
        f.write(f"- **Last Run:** {last_run}\n")
        f.write(f"- **Workflow URL:** [{workflow_url}]({workflow_url})\n\n")
        f.write("## Job Status\n\n")
        f.write("| Job | Result |\n")
        f.write("| --- | --- |\n")

        for job in sorted(needs.keys()):
            res = needs[job].get("result", "unknown")
            emoji = emojis.get(res, "⚠️")
            f.write(f"| {job} | {emoji} {res} |\n")

def main():
    needs_json = os.environ.get("NEEDS_JSON", "{}")
    workflow_url = os.environ.get("WORKFLOW_URL", "")

    try:
        needs = json.loads(needs_json)
    except json.JSONDecodeError:
        print(f"Error decoding NEEDS_JSON: {needs_json}")
        sys.exit(1)

    results = get_job_results(needs)
    status = determine_status(results)
    last_run = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

    update_json(status, last_run, results["failure"], workflow_url)
    update_markdown(status, last_run, workflow_url, needs)

    print(f"CI status updated to: {status}")

if __name__ == "__main__":
    main()
