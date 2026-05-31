import os
import datetime
import sys
import json
import argparse
import glob

def update_counters(entry, month_year, counters):
    """Update counters based on a single metrics entry with enhanced schema."""
    if not isinstance(entry, dict):
        return
    
    timestamp = entry.get("timestamp", "")
    if not timestamp.startswith(month_year):
        return
    
    status = entry.get("status")
    if status in counters:
        counters[status] += 1
    
    # Count skills from array
    skills = entry.get("skills_used", [])
    if isinstance(skills, list):
        counters["skills"] += len(skills)
    elif skills:  # Backward compatibility with string
        counters["skills"] += 1
    
    # Sum tokens from agent_metrics or use top-level
    agent_metrics = entry.get("agent_metrics", [])
    if isinstance(agent_metrics, list) and len(agent_metrics) > 0:
        for am in agent_metrics:
            tokens = am.get("tokens")
            if isinstance(tokens, (int, float)):
                counters["tokens"] += int(tokens)
    else:
        tokens = entry.get("tokens_used")
        if isinstance(tokens, (int, float)):
            counters["tokens"] += int(tokens)
    
    # Count handoffs
    handoff_count = entry.get("handoff_count")
    if isinstance(handoff_count, (int, float)):
        counters["handoffs"] += int(handoff_count)
    
    # Count agents
    agents = entry.get("agents", [])
    if isinstance(agents, list):
        counters["agent_invocations"] += len(agents)
    elif agents:  # Backward compatibility
        counters["agent_invocations"] += 1


def load_metrics_from_directory(metrics_dir, month_year):
    """Load and aggregate metrics from all JSON files in a directory."""
    counters = {
        "completed": 0, "failed": 0, "partial": 0,
        "skills": 0, "tokens": 0, "handoffs": 0, "agent_invocations": 0
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
    total_handoffs = counters["handoffs"]
    total_agent_invocations = counters["agent_invocations"]

    # Calculate success rate (including partial tasks)
    total_tasks = tasks_completed + failed_tasks + partial_tasks
    success_rate = (tasks_completed / total_tasks * 100) if total_tasks > 0 else 0

    # Calculate average handoffs per task
    avg_handoffs = (total_handoffs / total_tasks) if total_tasks > 0 else 0

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

Metrics sourced from .agents/metrics/*.json files (enhanced schema).

| Metric | Value |
|---|---|
| Tasks Completed | {tasks_completed} |
| Partial Tasks | {partial_tasks} |
| Failed Tasks | {failed_tasks} |
| Total Tasks | {total_tasks} |
| Success Rate | {success_rate:.1f}% |
| Skill Invocations | {skill_invocations} |
| Total Tokens Used | {total_tokens} |
| Total Agent Invocations | {total_agent_invocations} |
| Total Handoffs | {total_handoffs} |
| Avg Handoffs/Task | {avg_handoffs:.2f} |

---

*Report generated automatically on {datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")}*
"""

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(report_content)

    print(f"Report generated successfully: {filepath}")

if __name__ == "__main__":
    main()