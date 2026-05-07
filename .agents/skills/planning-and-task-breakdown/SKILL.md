---
name: planning-and-task-breakdown
description: Design the technical approach (PLAN.md) and decompose it into tasks (TASKS.md). Triggers after SPEC.md is approved.
category: workflow
version: "1.0"
template_version: "0.3"
---

# Planning and Task Breakdown

PLAN and TASKS phases: Design the system and map the work.

## When to Use
- After `SPEC.md` has been approved by the human
- Before starting implementation

## Instructions

### Phase 2: PLAN
1. **Design Approach**: Create `PLAN.md` in the project root.
2. **Key Components**: Define architecture, data models, and key algorithms.
3. **Risks/Mitigation**: Identify technical challenges and how to handle them.
4. **Seek Approval**: Wait for human approval of `PLAN.md`.

### Phase 3: TASKS
1. **Decompose**: Create `TASKS.md` from the approved `PLAN.md`.
2. **Atomic Units**: Each task should be independent, testable, and < 2 hours.
3. **Dependency Mapping**: Clearly mark which tasks depend on others.
4. **Success Criteria**: Define exact verification for each task.
5. **Seek Approval**: Wait for human approval of `TASKS.md`.

## Rationalizations
| Rationalization | Reality |
|-----------------|---------|
| "The spec is the plan." | The spec is the *what*; the plan is the *how*. |
| "I have it all in my head." | If it's not in `TASKS.md`, it won't be tracked or verified. |
| "Dependencies are obvious." | Explicit dependencies enable parallel work and prevent blocking. |

## Red Flags
- [ ] Task list is just a copy of the spec
- [ ] Tasks are too large or vague (e.g., "Implement API")
- [ ] Circular dependencies in the task list

## Verification
- [ ] `PLAN.md` exists and is approved
- [ ] `TASKS.md` exists and is approved
- [ ] Tasks have clear success criteria
