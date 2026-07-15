# Agent Evaluation Tracking (EVALS.md)

This document tracks the performance, quality, and reliability of AI agents within this repository. It serves as a historical record for benchmarking model updates, skill changes, and system prompts.

## Purpose and Scope

The goal of this evaluation framework is to:
- Quantify agent performance across key task categories.
- Detect regressions when updating agent instructions or underlying models.
- Provide objective data for choosing the best agent/model for specific workflows.

## Task Categories

Evaluations are grouped into the following domains:

- **Coding**: Feature implementation, bug fixing, refactoring, and test generation.
- **Documentation**: README updates, inline comments, ADR creation, and API docs.
- **Review**: Static analysis triage, PR reviews, and architectural feedback.
- **Workflow Automation**: Scripting, CI/CD configuration, and environment setup.
- **Agent Orchestration**: Task delegation, sub-agent coordination, and context management.

## Dataset & Prompt Set References

| Set ID | Name | Source/Path | Description |
|--------|------|-------------|-------------|
| CORE-01 | Core Coding | `tests/evals/coding/` | Standard feature/bug tasks |
| DOCS-01 | Documentation | `tests/evals/docs/` | Quality of generated docs |
| ORCH-01 | Multi-Agent | `tests/evals/orchestration/` | Delegation logic checks |

## Metrics Table

| Date | Model | Set ID | Pass Rate | First-Pass % | Tool Correctness | Avg. Latency | Avg. Cost |
|------|-------|--------|-----------|--------------|------------------|--------------|-----------|
| | | | | | | | |

- **Pass Rate**: Percentage of tasks meeting all acceptance criteria.
- **First-Pass %**: Percentage of tasks completed correctly without any self-correction or human intervention.
- **Tool Correctness**: Frequency of valid tool/command usage vs. hallucinated or invalid calls.
- **Avg. Latency**: Wall-clock time per completed task.
- **Avg. Cost**: Estimated token consumption per task.

## Regression Tracking

| Version/Date | Impacted Category | Regression Details | Root Cause | Resolution |
|--------------|-------------------|--------------------|------------|------------|
| | | | | |

## Model & Version Comparison

Comparison of results across different models (e.g., Claude 3.5 Sonnet vs. GPT-4o) or agent tool versions.

| Comparison | Winner | Reasoning |
|------------|--------|-----------|
| | | |

## Human Review Notes

Detailed qualitative feedback from human maintainers on agent outputs.

- **[Date]**: [Notes on style, reasoning quality, or recurring edge cases]

## Evaluation Methodology Change-log

- **v1.0.0**: Initial evaluation framework inspired by MiMo-Code.
