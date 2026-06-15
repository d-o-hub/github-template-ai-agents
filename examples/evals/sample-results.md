# Sample Evaluation Results

This is an example of how to use `EVALS.md` to track agent performance over time.

## Summary

Recent evaluations show high reliability in coding and documentation tasks, with room for improvement in complex multi-agent orchestration.

## Metrics Table (Sample Data)

| Date | Model | Set ID | Pass Rate | First-Pass % | Tool Correctness | Avg. Latency | Avg. Cost |
|------|-------|--------|-----------|--------------|------------------|--------------|-----------|
| 2025-02-15 | Claude 3.5 Sonnet | CORE-01 | 92% | 85% | 98% | 45s | $0.12 |
| 2025-02-15 | Claude 3.5 Sonnet | DOCS-01 | 100% | 95% | 100% | 30s | $0.05 |
| 2025-02-16 | Claude 3.5 Sonnet | ORCH-01 | 75% | 60% | 90% | 85s | $0.25 |

## Regression Tracking (Sample Data)

| Version/Date | Impacted Category | Regression Details | Root Cause | Resolution |
|--------------|-------------------|--------------------|------------|------------|
| 2025-02-10 | Coding | `self-fix-loop` failed on complex merge conflicts | Error pattern in `git` skill was too narrow | Expanded regex in `scripts/lib/git-utils.sh` |

## Model Comparison (Sample Data)

| Comparison | Winner | Reasoning |
|------------|--------|-----------|
| Claude 3.5 vs GPT-4o (Coding) | Claude 3.5 | More consistent adherence to `AGENTS.md` file size limits and atomic commit patterns. |
| Sonnet vs Haiku (Docs) | Claude 3 Haiku | Similar quality for simple doc updates at ~5x lower cost and latency. |

## Human Review Notes

- **2025-02-15**: Agents are consistently applying ADR numbering but occasionally miss the `yamllint` truthy rule in new workflows. Added a linter check to catch this automatically.
- **2025-02-16**: Orchestration latency increased after adding 3 new skills. Investigating if skill-loading overhead can be reduced via caching.
