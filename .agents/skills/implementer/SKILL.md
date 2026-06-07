---
name: implementer
version: "0.1.0"
description: Execution agent skill focused on implementing changes based on an approved Blueprint. Gated by human or primary agent approval of the implementation strategy. Use for targeted, atomic code changes once the plan is solid.
---

# Implementer Skill

The Implementer skill is an execution-focused tier responsible for making atomic, high-quality code changes.

## When to Use

- Implementing features based on a solid technical specification.
- Applying identified bug fixes.
- Executing planned refactoring tasks.
- Ensuring all changes pass quality gates and tests.

## Workflow

1. **Blueprint Check**: Verify that a clear implementation strategy (ADR) exists.
2. **Atomic Edits**: Apply changes one concern at a time.
3. **Verification**: Run tests and the quality gate.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll just fix it now" | Skipping the Blueprint phase leads to scope creep and architectural regressions. |

## Red Flags

- [ ] Making non-atomic changes that touch multiple unrelated areas.
- [ ] Committing code without running the required quality gate.
