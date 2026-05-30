---
name: dora-report
description: "Monthly DORA + agentic metrics reporting skill. Triggers on 'generate dora report', 'monthly metrics', 'agentic performance report', 'report DORA metrics', or when a monthly audit is required."
category: devops
version: "1.0.0"
template_version: "0.3"
---

# DORA Report

Generate and maintain DORA (DevOps Research and Assessment) metrics and agentic performance metrics to track project velocity, stability, and agent efficiency.

## When to Use
Activate when:
- Monthly reporting is required (e.g., at the end of a calendar month).
- The user requests a performance audit or "DORA report".
- Analyzing the impact of new tools or workflows on delivery speed and quality.

## Instructions

1. **Calculate DORA Metrics**:
   - **Deployment Frequency**: How often code is successfully released to production (or merged to `main` in this template context).
   - **Lead Time for Changes**: The amount of time it takes a commit to get into production.
   - **Change Failure Rate**: The percentage of deployments causing a failure in production (e.g., requiring a hotfix or revert).
   - **Time to Restore Service**: How long it takes to recover from a failure in production.

2. **Calculate Agentic Metrics**:
   - **Tasks Completed**: Total number of GOAP goals or atomic tasks finalized.
   - **Skill Invocations**: Frequency and distribution of skill usage.
   - **Token Usage Trends**: Efficiency of context usage over time.
   - **Self-Fix Success Rate**: Ratio of auto-fixed CI failures vs. those requiring human intervention.

3. **Generate Report**:
   - Create or append to `agents-docs/dora-reports/YYYY-MM.md`.
   - Use standardized tables and charts (Mermaid where appropriate).
   - Compare current metrics against the previous month's baseline.

4. **Identify Bottlenecks**:
   - Based on metrics, suggest one "Innovation Opportunity" using TRIZ principles to improve a lagging metric.

## Instructions
1. Run the automation script: `python3 scripts/generate_report.py`
2. Verify the output in `agents-docs/dora-reports/YYYY-MM.md`.
3. Add any qualitative analysis or TRIZ-based innovation opportunities to the generated file.

## Rationalizations
| Rationalization | Reality |
|-----------------|---------|
| "Metrics are for managers, not agents" | Metrics provide the feedback loop for agentic self-improvement and workflow optimization. |
| "It's too hard to track lead time manually" | Agents can analyze git history and PR timestamps to automate this calculation. |
| "A monthly report is too frequent for a small repo" | Regular snapshots prevent technical debt from accumulating unnoticed. |

## Red Flags
- [ ] Reporting "zero" for failures without verifying revert history or hotfix commits.
- [ ] Ignoring "agentic overhead" (e.g., extremely high token usage for simple tasks).
- [ ] Metrics that lack a time-bound context (e.g., "total tasks" instead of "tasks per week").

## Reference Files
- `agents-docs/WORKFLOW.md` - Standard delivery process to measure against.
- `scripts/analyze-codebase.sh` - Source for some raw performance data.
