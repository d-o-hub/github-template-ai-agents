import os
import datetime
import sys
import json
import argparse
import glob

def update_counters(entry, month_year, counters):
    """Update counters based on a single metrics entry."""
    if not isinstance(entry, dict): 
        return
    if entry.get("timestamp", "").startswith(month_year):
        status = entry.get("status")
        if status in counters:
            counters[status] += 1

        if entry.get("skill_used"):
            counters["skills"] += 1

        tokens = entry.get("tokens_used")
        if isinstance(tokens, (int, float)):
            counters["tokens"] += int(tokens)


def load_metrics_from_directory(metrics_dir, month_year):
    """Load and aggregate metrics from all JSON files in a directory."""
    counters = {
        "completed": 0, "failed": 0, "partial": 0,
        "skills": 0, "tokens": 0
    }
    
    if not os.path.exists(metrics_dir):
        return counters
    
    # Find all JSON files in the metrics directory
    json_files = glob.glob(os.path.join(metrics_dir, "*.json"))
    
    for json_file in json_files:
        try:
            with open(json_file, "r", encoding="utf-8") as f:
                entry = json.load(f)
                update_counters(entry, month_year, counters)
        except (OSError, json.JSONDecodeError):
            # Skip files that can't be read or parsed
            continue
    
    return counters


def main():
    parser = argparse.ArgumentParser(description="Generate DORA & Agentic Metrics Report")
    parser.add_argument("--month", type=str, help="Target month in YYYY-MM format")
    args = parser.parse_args()

    # Set the output directory
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
    reports_dir = os.path.join(repo_root, "agents-docs/dora-reports")
    metrics_dir = os.path.join(repo_root, ".agents/metrics")

    if not os.path.exists(reports_dir):
        os.makedirs(reports_dir)

    # Determine target month
    if args.month:
        month_year = args.month
    else:
        month_year = datetime.datetime.now().strftime("%Y-%m")

    filename = f"{month_year}.md"
    filepath = os.path.join(reports_dir, filename)

    counters = load_metrics_from_directory(metrics_dir, month_year)

    tasks_completed = counters["completed"]
    failed_tasks = counters["failed"]
    partial_tasks = counters["partial"]
    skill_invocations = counters["skills"]
    total_tokens = counters["tokens"]

    # Calculate success rate
    total_tasks = tasks_completed + failed_tasks + partial_tasks
    success_rate = (tasks_completed / total_tasks * 100) if total_tasks > 0 else 0

    # Mock DORA data - in a real implementation, these would be calculated from git history
    report_content = f"""# DORA & Agentic Metrics Report - {month_year}

## DORA Metrics

These metrics measure software delivery performance. In this template repository context:
- **Deployment** = merge to main branch
- **Production** = main branch

| Metric | Value | Industry Benchmark (Elite) | Status |
|---|---|---|---|
| Deployment Frequency | Multiple/day | Multiple/day | Check |
| Lead Time for Changes | <1 hour | <1 hour | Check |
| Change Failure Rate | 0-15% | 0-15% | Check |
| Time to Restore Service | <1 hour | <1 hour | Check |

*Note: DORA metrics above show target benchmarks. Actual values would be calculated from git history in a production environment.*

---

## Agentic Metrics

Metrics sourced from .agents/metrics/*.json files.

| Metric | Value |
|---|---|
| Tasks Completed | {tasks_completed} |
| Partial Tasks | {partial_tasks} |
| Failed Tasks | {failed_tasks} |
| Skill Invocations | {skill_invocations} |
| Total Tokens Used | {total_tokens} |
| Success Rate | {success_rate:.1f}% |

---

*Report generated automatically on {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}*
"""

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(report_content)

    print(f"Report generated successfully: {filepath}")

if __name__ == "__main__":
    main()