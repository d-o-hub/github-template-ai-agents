---
name: incremental-implementation
description: Implement tasks one by one using TDD and thin vertical slices. Triggers after TASKS.md is approved.
category: workflow
version: "1.0"
template_version: "0.3"
---

# Incremental Implementation

IMPLEMENT phase: Build, test, verify, repeat.

## When to Use
- After `TASKS.md` has been approved by the human
- For all code changes

## Instructions
1. **Pick Task**: Select the next task from `TASKS.md` with met dependencies.
2. **Apply TDD**: Use the `test-driven-development` skill for every task.
   - Red: Write a failing test.
   - Green: Implement minimum code to pass.
   - Refactor: Clean up while keeping tests green.
3. **Verify Task**: Run the task's success criteria.
4. **Human Gate**: After each significant task or vertical slice, present the work and verification to the human.
5. **Update TASKS.md**: Mark the task as completed.
6. **Commit**: Use `atomic-commit` (if available) or the standard commit workflow.

## Rationalizations
| Rationalization | Reality |
|-----------------|---------|
| "I'll implement three tasks at once to save time." | This increases risk and makes debugging harder. |
| "I'll add the tests after I'm sure it works." | TDD ensures it works *and* is testable from the start. |
| "This is too small to show the human." | Small steps prevent large regressions. |

## Red Flags
- [ ] Working on multiple tasks simultaneously
- [ ] Skipping tests for "simple" logic
- [ ] Committing large blocks of code without task checkpoints

## Verification
- [ ] Every task in `TASKS.md` has passing tests
- [ ] Human has approved the implementation of each milestone
- [ ] `PHASES.md` updated to reflect completion
