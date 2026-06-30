---
name: agent-coordination
version: "0.3.0"
category: agent
description: Coordinate multiple agents for software development across any language. Use this skill when running parallel execution of independent tasks, sequential chains with dependencies, swarm analysis from multiple perspectives, or iterative refinement loops — even if they just say "run these in parallel" or "coordinate agents". Not for goap-agent.
license: MIT
---

# Agent Coordination

Coordinate multiple agents efficiently for complex development tasks across any programming language.

**Session Start Protocol**: Identify parallelizable work and spawn task agents immediately at the start of a session, instead of doing everything sequentially.

## When to Use

- User asks to run parallel execution of independent tasks
- Need to coordinate sequential chains with dependencies
- Planning swarm analysis or iterative refinement loops
- Even if they just say "run these in parallel" or "coordinate agents"

## Quick Start

Choose your coordination strategy:

- **Parallel** - Independent tasks (no dependencies, concurrent execution)
- **Sequential** - Dependent tasks (A → B → C)
- **Swarm** - Multi-perspective analysis
- **Hybrid** - Multi-phase workflows
- **Iterative** - Progressive refinement

## Available Agents

| Agent | Best For |
|-------|----------|
| code-reviewer | Quality assessment, standards |
| test-runner | Execute tests, verify functionality |
| feature-implementer | Build new capabilities |
| refactorer | Improve existing code |
| debugger | Diagnose and fix issues |
| security-auditor | Find vulnerabilities |
| performance-optimizer | Speed and efficiency |
| loop-agent | Orchestrate iterations |

## Parallel Execution

### When to Parallelize

Tasks are independent when:
- ✓ No data dependencies
- ✓ No resource conflicts
- ✓ No ordering requirements
- ✓ Failures are isolated

### How to Launch

**Critical**: Use **single message** with **multiple Task tool calls**:

```
Single message:
- Task → Agent A
- Task → Agent B
- Task → Agent C

All start simultaneously.
```

### Patterns

**Homogeneous Parallel** — Same agent type, different inputs:

```
├─ test-runner: Test module A
├─ test-runner: Test module B
└─ test-runner: Test module C
```

**Heterogeneous Parallel** — Different agent types:

```
├─ code-reviewer: Quality analysis
├─ test-runner: Test execution
└─ debugger: Performance profiling
```

**Parallel with Convergence** — Parallel execution → Single synthesis:

```
Phase 1: Parallel investigation
Phase 2: Synthesize findings
```

### Synchronization Strategies

- **Wait for All (AND)**: All must complete
- **Wait for Any (OR)**: First success proceeds
- **Wait for Threshold**: N of M must complete

### Error Handling

One failing doesn't stop others:

```
├─ Agent A: ✓ Success
├─ Agent B: ✗ Failed
└─ Agent C: ✓ Success

Collect A and C, report B failed
```

Strategies: Fail Fast, Best Effort, Retry Failed

### Performance

```
Sequential = T1 + T2 + T3
Parallel = max(T1, T2, T3)
Speedup = Sequential / Parallel
```

## Sequential Execution

For dependent tasks with quality gates between phases:

```text
1. Swarm analysis (parallel agents gather insights)
2. Sequential execution (apply findings)
3. Parallel validation (verify results)
```

## Common Patterns

**Analysis + Execution**:

```text
1. Swarm analysis (parallel agents gather insights)
2. Sequential execution (apply findings)
3. Parallel validation (verify results)
```

**Test-Driven Workflow**:

```text
1. test-runner: Run existing tests
2. feature-implementer: Add functionality
3. test-runner: Verify implementation
4. code-reviewer: Quality check
```

**Performance Optimization**:

```text
Loop with performance-optimizer until:
- Metrics meet targets
- No more optimizations found
- Max iterations reached
```

## Quality Gates

Between each phase, verify:
- Code compiles/parses correctly
- Tests pass with adequate coverage
- Security scans clean
- Performance acceptable
- No regressions introduced

## Language Support

This coordination skill works with:
- Python (Django, Flask, FastAPI)
- JavaScript/TypeScript (Node.js, React, Vue)
- Java (Spring, Jakarta EE)
- Go (Gin, Echo)
- Rust (Actix, Rocket)
- C# (.NET, ASP.NET Core)

## See Also

- `goap-agent` — Top-level orchestrator
- `delegate` — Lightweight retrieval agent
- `implementer` — Atomic code execution agent

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll just handle everything sequentially myself" | Parallel coordination reduces wall-clock time and leverages specialized agent strengths. |
| "Coordination overhead isn't worth it for small tasks" | Even small tasks benefit from quality gates and specialized validation that coordination provides. |

## Red Flags

- [ ] Running agents without defining quality gates between phases
- [ ] Choosing a coordination strategy without analyzing task dependencies first
- [ ] Skipping result validation after parallel execution completes
- [ ] Sending separate messages for each agent instead of a single parallel launch
- [ ] Parallelizing tasks that share mutable state or write to the same files
- [ ] Ignoring partial failures and not collecting available results

## References

- **[../../../agents-docs/references/orchestration-patterns.md](../../../agents-docs/references/orchestration-patterns.md)** - Complete guide with detailed steps, patterns, synchronization strategies, error handling, performance optimization, and troubleshooting

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
