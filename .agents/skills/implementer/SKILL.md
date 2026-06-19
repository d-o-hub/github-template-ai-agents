---
name: implementer
version: "0.1.1"
category: agent
description: Execution agent skill focused on implementing changes based on an approved Blueprint. Use this skill for targeted, atomic code changes once the plan is solid — even if they just say "implement this" or "make the changes". Gated by human or primary agent approval of the implementation strategy.
changelog:
  - 0.1.1: Initial stable version with mandatory TRIZ gate.
  - 0.1.0: Draft version. Not for delegate, goap-agent.
license: MIT
---

# Implementer Skill

The Implementer skill is an execution-focused tier responsible for making atomic, high-quality code changes.

## When to Use

- Implementing features based on a solid technical specification
- Applying identified bug fixes
- Executing planned refactoring tasks
- Ensuring all changes pass quality gates and tests
- Even if they just say "implement this" or "make the changes"

## Blueprint Validation

Before making any changes, verify the Blueprint (ADR) exists and includes:
- [ ] Clear problem statement
- [ ] Proposed solution with specific files to modify
- [ ] TRIZ contradiction analysis (if applicable)
- [ ] Success criteria and test plan
- [ ] Rollback strategy

If the Blueprint is missing or incomplete, stop and request it before proceeding.

## Workflow

1. **Blueprint Check**: Verify that a clear implementation strategy (ADR) with TRIZ analysis exists.
2. **Atomic Edits**: Apply changes one concern at a time. Each edit should be independently committable.
3. **Verification**: Run tests and the quality gate after each atomic change.

## Atomic Edit Pattern

```
1. Identify the single concern to change
2. Make the edit
3. Run: ./scripts/quality_gate.sh
4. If pass → commit with conventional format
5. If fail → fix, re-run quality gate, then commit
6. Move to next concern
```

## Gotchas

- Never bundle unrelated changes in a single commit — if the quality gate fails, you can't tell which change caused it.
- If the Blueprint says "modify files X, Y, Z" but you find a better approach mid-implementation, update the Blueprint first rather than deviating silently.
- Run the quality gate locally before pushing — CI failures are expensive to diagnose remotely.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll just fix it now" | Skipping the Blueprint phase leads to scope creep and architectural regressions. |
| "The change is obvious, no need for a Blueprint" | Obvious changes still need atomic edits and quality gate verification. |

## Red Flags

- [ ] Making non-atomic changes that touch multiple unrelated areas
- [ ] Committing code without running the required quality gate
- [ ] Deviating from the Blueprint without updating it first
- [ ] Skipping the Blueprint Check step because "it's a small change"

## See Also

- `delegate` — Context retrieval before implementation
- `goap-agent` — Orchestrator that assigns implementer tasks
