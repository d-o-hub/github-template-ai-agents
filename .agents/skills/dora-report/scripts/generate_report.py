import os
import datetime
import sys

def main():
    # Set the output directory
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
    reports_dir = os.path.join(repo_root, "agents-docs/dora-reports")

    if not os.path.exists(reports_dir):
        os.makedirs(reports_dir)

    # Determine current month and year
    now = datetime.datetime.now()
    month_year = now.strftime("%Y-%m")
    filename = f"{month_year}.md"
    filepath = os.path.join(reports_dir, filename)

    # Mock data for demonstration purposes
    # In a real scenario, this would be calculated from git history and logs
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
| Tasks Completed | 42 |
| Skill Invocations | 156 |
| Token Usage Efficiency | +5% vs last month |
| Self-Fix Success Rate | 85% |

---
*Report generated automatically on {now.strftime("%Y-%m-%d %H:%M:%S")}*
"""

    with open(filepath, "w") as f:
        f.write(report_content)

    print(f"Report generated successfully: {filepath}")

if __name__ == "__main__":
    main()
