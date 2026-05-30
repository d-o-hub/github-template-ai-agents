#!/usr/bin/env python3
import json
import os
import sys
from datetime import datetime

def main():
    needs_json = os.environ.get("NEEDS_JSON", "{}")
    workflow_url = os.environ.get("WORKFLOW_URL", "")

    try:
        needs = json.loads(needs_json)
    except json.JSONDecodeError:
        print(f"Error decoding NEEDS_JSON: {needs_json}")
        sys.exit(1)

    failing_jobs = []
    passing_jobs = []
    skipped_jobs = []
    cancelled_jobs = []

    for job_name, job_data in needs.items():
        result = job_data.get("result")
        if result == "failure":
            failing_jobs.append(job_name)
        elif result == "success":
            passing_jobs.append(job_name)
        elif result == "skipped":
            skipped_jobs.append(job_name)
        elif result == "cancelled":
            cancelled_jobs.append(job_name)

    if failing_jobs:
        status = "failing"
    elif cancelled_jobs:
        status = "failing" # Treat cancelled as failing for safety
    else:
        status = "passing"

    last_run = datetime.utcnow().isoformat() + "Z"

    # Update ci-status.json
    ci_status = {
        "status": status,
        "last_run": last_run,
        "failing_jobs": failing_jobs,
        "workflow_url": workflow_url
    }

    with open("ci-status.json", "w") as f:
        json.dump(ci_status, f, indent=2)
        f.write("\n")

    # Update ci-summary.md
    with open("ci-summary.md", "w") as f:
        f.write("# CI Summary\n\n")
        f.write(f"Latest CI status: **{status}**\n\n")
        f.write(f"- **Last Run:** {last_run}\n")
        f.write(f"- **Workflow URL:** [{workflow_url}]({workflow_url})\n\n")

        f.write("## Job Status\n\n")
        f.write("| Job | Result |\n")
        f.write("| --- | --- |\n")

        all_jobs = sorted(needs.keys())
        for job in all_jobs:
            res = needs[job].get("result", "unknown")
            emoji = "✅" if res == "success" else "❌" if res == "failure" else "⏭️" if res == "skipped" else "⚠️"
            f.write(f"| {job} | {emoji} {res} |\n")

    print(f"CI status updated to: {status}")

if __name__ == "__main__":
    main()
