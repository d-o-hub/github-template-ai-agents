---
name: task-decomposition
description: Break down complex tasks into atomic, actionable goals with clear dependencies and success criteria. Use when planning multi-step projects, coordinating agents, or decomposing complex requests.
---

# Task Decomposition

Decompose high-level objectives into manageable, testable sub-tasks.

## When to Use

- Complex requests with multiple components
- Multi-phase projects requiring coordination
- Tasks benefiting from parallel execution

## Framework

### 1. Requirements Analysis

Extract: Primary objective, implicit requirements, constraints, success criteria.

### 2. Goal Hierarchy

```
Main Goal
├─ Sub-goal 1 → Tasks 1.1, 1.2
├─ Sub-goal 2 → Task 2.1
└─ Sub-goal 3
```

**Atomic Criteria**: Single action, defined inputs/outputs, one agent, testable.

### 3. Dependency Mapping

- **Sequential**: A → B → C
- **Parallel**: A, B, C (independent)
- **Converging**: A, B, C → D

### 4. Success Criteria

Define: Inputs, outputs, quality standards.

## Process

### Step 1: Understand Goal
```
Request: [Original]
Goal: [Main objective]
Type: [Implementation/Debug/Refactor]
Complexity: [Simple/Medium/Complex]
```

### Step 2: Identify Components (3-7)
```
Goal: Implement feature
Components: Database, API, Logic, Testing, Docs
```

### Step 3: Decompose Components
```
Component: Database
Tasks: 1. Design schema, 2. Implement operations
```

### Step 4: Map Dependencies
```
[Design] → [Implement] → [Test]
```

### Step 5: Assign Priorities
- P0 (Critical), P1 (Important), P2 (Nice-to-have)

### Step 6: Estimate Complexity
- Low (<30min), Medium (30min-2hr), High (>2hr)

## Patterns

### Layer-Based
1. Data/Storage  2. Business logic  3. API  4. Testing  5. Documentation

### Feature-Based
1. Core (MVP)  2. Error handling  3. Performance  4. Integration  5. Testing  6. Docs

### Phase-Based
1. Research  2. Foundation  3. Implementation  4. Integration  5. Polish  6. Release

### Problem-Solution
1. Reproduce  2. Diagnose  3. Design  4. Fix  5. Verify  6. Prevent

## Examples

### Simple
```
Request: "Fix failing test"
Tasks: 1. Run test  2. Identify cause  3. Apply fix  4. Verify
Sequential, Low complexity
```

### Medium
```
Request: "Add caching"
Tasks: 1. Design  2. Implement  3. Integrate  4. Test  5. Measure
Dependencies: 1→2→3, 4→3, 5→3
```

### Complex
```
Request: "Multiple backends"
Components: Abstraction, Backend A, Backend B, Factory, Migration, Testing, Docs
Strategy: Multi-phase hybrid
```

## Quality Checklist

✓ Atomic and actionable tasks
✓ Dependencies identified
✓ Measurable success criteria
✓ Appropriate complexity estimates
✓ No task >4 hours
✓ Parallelization opportunities

✗ Tasks too large/vague
✗ Missing dependencies
✗ No quality/testing tasks

## Integration

GOAP Phase 1: Decomposition → Execution Plan → Monitor → Report

## Tips

1. **Start with Why**: Understand true goal
2. **Think Top-Down**: High-level first
3. **Consider User**: Value per task
4. **Plan for Quality**: Include testing/docs
5. **Anticipate Issues**: Identify risks
6. **Enable Parallelization**: Find independent tasks

## Summary

Good decomposition enables optimal execution, clear validation, and higher quality.

## Reference Files

- **[reference/guide.md](reference/guide.md)** - Complete guide with detailed framework, process, patterns, examples, and GOAP integration
