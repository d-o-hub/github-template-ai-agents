# Agent Coordination Strategy: 3 API Tests + Code Review

## Situation Analysis

You have **4 independent work items**:
- 3 API endpoint tests (independent of each other)
- 1 code review (independent of tests)

Since all tasks are independent with no dependencies, this is a **parallel execution** scenario.

## Recommended Coordination

### Spawn 4 parallel agents:

| Agent | Task | Rationale |
|-------|------|-----------|
| Agent 1 | Test API endpoint A | Independent work |
| Agent 2 | Test API endpoint B | Independent work |
| Agent 3 | Test API endpoint C | Independent work |
| Agent 4 | Code review | Independent work |

### Execution Plan

```
┌─────────────────────────────────────────────────────┐
│  Spawn 4 agents in parallel (single turn)          │
├─────────────────────────────────────────────────────┤
│  Agent 1: Test endpoint A                          │
│  Agent 2: Test endpoint B                          │
│  Agent 3: Test endpoint C                          │
│  Agent 4: Code review                              │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│  Wait for all completions                          │
├─────────────────────────────────────────────────────┤
│  • Collect results from all 4 agents               │
│  • Aggregate findings                              │
│  • Present combined summary                        │
└─────────────────────────────────────────────────────┘
```

### Implementation (if using actor tool)

```javascript
// Spawn all 4 agents in parallel in one turn
actor({ operation: "spawn", subagent_type: "general", description: "Test API A", prompt: "..." })
actor({ operation: "spawn", subagent_type: "general", description: "Test API B", prompt: "..." })
actor({ operation: "spawn", subagent_type: "general", description: "Test API C", prompt: "..." })
actor({ operation: "spawn", subagent_type: "general", description: "Code review", prompt: "..." })

// Then wait for all
actor({ operation: "wait", actor_id: "id-1" })
actor({ operation: "wait", actor_id: "id-2" })
actor({ operation: "wait", actor_id: "id-3" })
actor({ operation: "wait", actor_id: "id-4" })
```

## Key Principles

1. **Parallelism**: All 4 tasks have zero dependencies—run them simultaneously
2. **Isolation**: Each agent works independently; no shared state needed
3. **Aggregation**: Collect all results at the end for a unified report
4. **Atomic prompts**: Give each agent a clear, self-contained task description

## Why Not Sequential?

Sequential execution would take 4x longer with no benefit. Parallelism reduces wall-clock time to roughly the duration of the slowest single task.
