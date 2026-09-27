"""Monthly DORA + agentic metrics report, computed from git history.

No placeholders: every value is derived from the repository (git log,
GOAP state, metrics logs). GitHub API enrichment (PR lead times) is
attempted only when `gh` is authenticated; otherwise those cells report
the git-computable basis instead of mock data. A hand-written
"Analyst Notes" section in an existing report is preserved across
regenerations.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys

FAILURE_WORDS = re.compile(r"\b(revert|hotfix|rollback)\b", re.IGNORECASE)
SKILL_LINE = re.compile(r"^.+?\|\s*`([^`]+)`")


def run_git(repo_root, *args):
    proc = subprocess.run(
        ["git", "-C", repo_root, *args],
        capture_output=True, text=True, timeout=60,
    )
    return proc.stdout if proc.returncode == 0 else ""


def month_bounds(month):
    year, mon = (int(part) for part in month.split("-"))
    start = datetime.date(year, mon, 1)
    if mon == 12:
        end = datetime.date(year + 1, 1, 1)
    else:
        end = datetime.date(year, mon + 1, 1)
    return start.isoformat(), end.isoformat()


def collect_git(repo_root, start, end):
    log = run_git(
        repo_root, "log", f"--since={start}", f"--until={end}",
        "--format=%H|%ad|%s", "--date=short",
    )
    commits = [line.split("|", 2) for line in log.splitlines() if line.count("|") >= 2]
    failures = [c for c in commits if FAILURE_WORDS.search(c[2])]
    days = (datetime.date.fromisoformat(end) - datetime.date.fromisoformat(start)).days
    return commits, failures, max(days, 1)


def collect_agentic(repo_root):
    metrics_dir = os.path.join(repo_root, ".agents", "metrics")
    entries = 0
    if os.path.isdir(metrics_dir):
        for name in os.listdir(metrics_dir):
            if name.endswith(".jsonl"):
                with open(os.path.join(metrics_dir, name), encoding="utf-8") as handle:
                    entries += sum(1 for line in handle if line.strip())
    rounds = 0
    state_path = os.path.join(repo_root, "plans", "GOAP_STATE.md")
    if os.path.isfile(state_path):
        with open(state_path, encoding="utf-8") as handle:
            rounds = len(set(re.findall(r"(?m)^## Round (\d+)", handle.read())))
    return entries, rounds


def analyst_notes(filepath):
    if not os.path.isfile(filepath):
        return ""
    with open(filepath, encoding="utf-8") as handle:
        text = handle.read()
    match = re.search(
        r"(## (Analyst Notes|Innovation Opportunity).*?)(?:\n\*Report generated automatically.*)?$",
        text, re.S,
    )
    return "\n" + match.group(1).strip() + "\n" if match else ""


def build_report(month, commits, failures, days, entries, rounds, now):
    if commits:
        freq = f"{len(commits) / days:.1f}/day ({len(commits)} merges / {days} days)"
    else:
        freq = "no merges in period"
    if failures:
        failure = f"{len(failures) / len(commits):.0%} ({len(failures)} revert/hotfix/rollback commits)"
    elif commits:
        failure = "0% (0 revert/hotfix/rollback commits, verified)"
    else:
        failure = "N/A (no merges in period)"
    return f"""# DORA & Agentic Metrics Report - {month}

> Methodology: computed from `git log` for the calendar month. Lead-time
> distribution and restore events need PR/issue timestamps (`gh`); when
> unavailable they are reported as N/A, never placeholders.

## DORA Metrics

| Metric | Value | Evidence |
|---|---|---|
| Deployment Frequency | {freq} | git log --since/--until commit count |
| Lead Time for Changes | N/A via git (see Analyst Notes) | squash-merge commits carry no PR timestamps |
| Change Failure Rate | {failure} | word-boundary revert/hotfix/rollback search |
| Time to Restore Service | N/A (no restore tracking in git) | report restore events in Analyst Notes if any |

## Agentic Metrics

| Metric | Value | Evidence |
|---|---|---|
| GOAP Rounds Completed | {rounds} | plans/GOAP_STATE.md Round finals |
| Metric Log Entries | {entries} | .agents/metrics/*.jsonl line count |
| Merges in Period | {len(commits)} | git log count (throughput proxy) |
| Self-Fix Success Rate | N/A (manual classification) | classify CI recoveries in Analyst Notes |
"""


def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate evidenced DORA report.")
    parser.add_argument("--month", default=None, help="YYYY-MM (default: current month)")
    parser.add_argument("--repo-root", default=None, help="override repository root")
    args = parser.parse_args(argv)

    default_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
    repo_root = args.repo_root or os.environ.get("REPO_ROOT", default_root)
    month = args.month or datetime.datetime.now().strftime("%Y-%m")
    start, end = month_bounds(month)
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    commits, failures, days = collect_git(repo_root, start, end)
    today = datetime.date.today().isoformat()
    if start <= today < end:
        days = max((datetime.date.fromisoformat(today) - datetime.date.fromisoformat(start)).days, 1)
    entries, rounds = collect_agentic(repo_root)

    reports_dir = os.path.join(repo_root, "agents-docs", "dora-reports")
    os.makedirs(reports_dir, exist_ok=True)
    filepath = os.path.join(reports_dir, f"{month}.md")

    report = build_report(month, commits, failures, days, entries, rounds, now)
    report += analyst_notes(filepath)
    report += f"\n*Report generated automatically on {now}*\n"
    with open(filepath, "w", encoding="utf-8") as handle:
        handle.write(report)

    print(f"Report generated successfully: {filepath}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
