---
name: goap-agent
version: "0.2.10"
category: workflow
description: Orchestrates complex multi-step tasks with intelligent planning: analyze the problem, decompose into sub-goals, select execution strategy, assign agents, and coordinate with quality gates. Use this skill when the user asks to plan a large change, break down a complex problem, coordinate multiple agents, or systematically tackle a multi-file refactoring — even if they just say "plan this out" or "how should we approach this". Not for simple single-step tasks (use delegate) or implementing from an approved plan (use implementer).
license: MIT
---

# GOAP Agent Skill: Goal-Oriented Action Planning

Enable intelligent planning and execution of complex multi-step tasks through systematic decomposition, dependency mapping, and coordinated multi-agent execution.

Always use the plans/ folder for all files. Use `plans/GOAP_STATE.md` to track persistent state.

## Quick Reference

- `execution-strategies.md` - Detailed guide on execution patterns
- `references/guide.md` - Complete examples, templates, and advanced topics

## When to Use

Use this skill when facing:
- **Complex Multi-Step Tasks**: Tasks requiring 5+ distinct steps
- **Cross-Domain Problems**: Issues spanning multiple areas
- **Optimization Opportunities**: Tasks benefiting from parallel execution
- **Quality-Critical Work**: Projects requiring validation checkpoints

## Core GOAP Methodology

### The GOAP Planning Cycle

```
1. ANALYZE → 2. DECOMPOSE → 3. STRATEGIZE → 4. COORDINATE → 5. EXECUTE → 6. SYNTHESIZE
```

## Phase 1: Task Analysis (Analyze & Strategize)

Before decomposing tasks, ensure architectural decisions are sound:
1. **Analyze**: Use `triz-analysis` or `triz-solver` to evaluate the problem and resolve contradictions.
2. **Decide**: Formulate an **ADR** (Architecture Decision Record) detailing Context, Decision, and Consequences.
3. **Gate**: Wait for human approval of the ADR before proceeding to decomposition.

```markdown
## Task Analysis

**Primary Goal**: [Clear statement of what success looks like]
**Constraints**: [Time, Resources]
**Complexity**: Simple/Medium/Complex
**ADR Link**: [Link to approved Architecture Decision Record]
```

Context: Use Explore agent, check past patterns, perform TRIZ analysis, and record architectural decisions.

## Phase 2: Task Decomposition

Decompose high-level objectives into manageable, testable sub-tasks.

### Decomposition Framework

1. **Requirements Analysis**: Extract primary objective, implicit requirements, constraints, success criteria.
2. **Goal Hierarchy**: Top-down decomposition into sub-goals and atomic tasks.
3. **Dependency Mapping**: Sequential (A→B→C), Parallel (A,B,C), Converging (A,B,C→D).
4. **Success Criteria**: Define inputs, outputs, quality standards.

### Atomic Criteria

Each task must be: Single action, defined inputs/outputs, one agent, testable.

### Decomposition Patterns

- **Layer-Based**: Data → Business Logic → API → Testing → Docs
- **Feature-Based**: Core MVP → Error Handling → Performance → Integration → Testing → Docs
- **Phase-Based**: Research → Foundation → Implementation → Integration → Polish → Release
- **Problem-Solution**: Reproduce → Diagnose → Design → Fix → Verify → Prevent

### Output Format

```markdown
### Sub-Goals
1. [Component 1] - Priority: P0, Deps: none
2. [Component 2] - Priority: P1, Deps: Component 1
```

Principles: Atomic, Testable, Independent, Assigned. No task >4 hours.

## Phase 3: Strategy Selection

| Strategy | When | Speed |
|----------|------|-------|
| Parallel | Independent tasks | Nx |
| Sequential | Dependent tasks | 1x |
| Swarm | Many similar tasks | ~Nx |
| Hybrid | Mixed requirements | 2-4x |

See **[execution-strategies.md](execution-strategies.md)** for details.

## Phase 4: Agent Assignment

| Agent | Best For |
|-------|----------|
| feature-implementer | New functionality |
| debugger | Bug fixes |
| test-runner | Test validation |
| refactorer | Code improvements |
| code-reviewer | Quality assurance |
| delegate | Context retrieval, pattern search, state assessment (before planning) |
| implementer | Atomic code changes post-Blueprint approval |

## Phase 5: Execution Planning

```markdown
## Execution Plan

- Strategy: [Type]
- Quality Gates: [N checkpoints]

### Phase 1
- Tasks: [List]
- Quality Gate: [Criteria]
```

## Phase 6: Coordinated Execution

**Parallel**: Single message, multiple Task tool calls
**Sequential**: Phases with quality gates between
**Monitor**: Track progress, validate results

## Phase 7: Result Synthesis

```markdown
## Summary

✓ Completed: [Tasks]
📦 Deliverables: [List]
✅ Quality: [Status]
```

## Common Patterns

- **Research → Implement → Validate**
- **Investigate → Diagnose → Fix → Verify**
- **Audit → Improve → Validate**

## Error Handling

- **Agent Failure**: Retry, Reassign, Modify, or Escalate
- **Quality Gate Failure**: Re-run with fixes
- **Blocked**: Re-order or work on independent tasks

## Best Practices

### DO:

✓ Break tasks into atomic units
✓ Define clear quality gates
✓ Match agents to requirements
✓ Monitor and validate incrementally

### DON'T:

✗ Create monolithic tasks
✗ Skip quality gates
✗ Assume independence without verification

## Integration

- **agent-coordination**: Strategy implementation (parallel, sequential, swarm)

## Summary

GOAP enables systematic planning through: Analysis, Decomposition, Strategy, Quality Assurance, and Coordinated Agents.

## See Also

- `agent-coordination` — Coordinate multiple agents
- `triz-analysis` — Audit systems for contradictions
- `triz-solver` — Solve specific problems using TRIZ

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can just execute all tasks in parallel — it's faster." | Parallel execution without dependency analysis causes race conditions, wasted tokens, and corrupted intermediate state. |
| "Quality gates slow things down — skip them for speed." | Skipping quality gates compounds errors across agents, requiring far more rework than the time saved. |

## Red Flags

- [ ] Executing tasks without mapping dependencies first
- [ ] Skipping ADR approval gate before decomposition
- [ ] Assigning agents without matching skills to task requirements

## References

- `references/guide.md` - Complete templates, detailed examples, extended patterns, error handling, optimization
- `execution-strategies.md` - Execution pattern details

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
