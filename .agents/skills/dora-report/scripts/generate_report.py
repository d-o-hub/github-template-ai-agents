import os
import datetime
import sys
import json

def main():
    # Set the output directory
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
    reports_dir = os.path.join(repo_root, "agents-docs/dora-reports")
    metrics_file = os.path.join(repo_root, ".agents/metrics.jsonl")

    if not os.path.exists(reports_dir):
        os.makedirs(reports_dir)

    # Determine current month and year
    now = datetime.datetime.now()
    month_year = now.strftime("%Y-%m")
    filename = f"{month_year}.md"
    filepath = os.path.join(reports_dir, filename)

    tasks_completed = 0
    skill_invocations = 0
    total_tokens = 0
    failed_tasks = 0
    partial_tasks = 0

    if os.path.exists(metrics_file):
        with open(metrics_file, "r") as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    entry = json.loads(line)
                    # Simple filter for current month based on timestamp string
                    if entry.get("timestamp", "").startswith(month_year):
                        status = entry.get("status")
                        if status == "completed":
                            tasks_completed += 1
                        elif status == "failed":
                            failed_tasks += 1
                        elif status == "partial":
                            partial_tasks += 1

                        if entry.get("skill_used"):
                            skill_invocations += 1

                        tokens = entry.get("tokens_used")
                        if isinstance(tokens, (int, float)):
                            total_tokens += int(tokens)
                except json.JSONDecodeError:
                    continue

    # Calculate success rate
    # We include partial tasks in the denominator to be conservative
    total_tasks = tasks_completed + failed_tasks + partial_tasks
    success_rate = (tasks_completed / total_tasks * 100) if total_tasks > 0 else 0

    # Mock DORA data (as per original script, would need git analysis for real values)
    report_content = f"""# DORA & Agentic Metrics Report - {month_year}

## DORA Metrics

| Metric | Value |
|---|---|
| Deployment Frequency | Daily |
| Lead Time for Changes | < 24 hours |
| Change Failure Rate | 0% |
| Time to Restore Service | < 1 hour |

## Agentic Metrics

| Metric | Value |
|---|---|
| Tasks Completed | {tasks_completed} |
| Partial Tasks | {partial_tasks} |
| Failed Tasks | {failed_tasks} |
| Skill Invocations | {skill_invocations} |
| Total Tokens Used | {total_tokens} |
| Success Rate | {success_rate:.1f}% |

---

*Report generated automatically on {now.strftime("%Y-%m-%d %H:%M:%S")}*
"""

    with open(filepath, "w") as f:
        f.write(report_content)

    print(f"Report generated successfully: {filepath}")

if __name__ == "__main__":
    main()
