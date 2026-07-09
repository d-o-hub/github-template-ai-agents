# Agent Teams, Dynamic Workflows & Worktrees

> Reference doc — not loaded by default. Link from `agent-coordination` skill or AGENTS.md as needed.

Claude Code (v2.1+) ships three native capabilities for parallel agent execution.
This guide covers when to use each, how they compare to custom coordination patterns,
and cost implications.

## Capability Comparison

| Capability | Scope | Communication | Cost Multiplier | Best For |
|-----------|-------|---------------|-----------------|----------|
| **Sub-agents** | One session, delegated workers | Report back to parent only | 4-7x base | Quick focused tasks, noise isolation |
| **Agent View** | Dashboard for background sessions | Dispatch + monitor from one screen | Linear per session | Multiple independent tasks |
| **Agent Teams** | Coordinated squad with peer messaging | Teammates message each other | ~15x base | Complex parallel work needing cross-agent findings |
| **Dynamic Workflows** | Bundled multi-subagent procedures | Orchestrated verification loops | 4-7x base | Reusable multi-step workflows with validation |
| **Worktrees** | Isolated git checkouts | File-system isolation | Zero overhead | Parallel edits to same repo without conflicts |

## Decision Tree

```
Does work parallelize?
├─ No → Stay in single session
└─ Yes → Do workers need to see each other's findings DURING work?
    ├─ No → Sub-agents (cheapest parallel option)
    └─ Yes → Agent Teams (peer coordination)
```

For reusable procedures: use Dynamic Workflows.
For parallel branch development: use Worktrees.

## Sub-agents

Isolated workers that return results to the parent session. The parent context
only sees the final summary, not intermediate tool calls.

**Use when:**
- Tasks are independent (no cross-agent dependencies)
- You want noise isolation (search results, logs stay in worker context)
- Quick focused tasks: "review file X for security", "find all usages of Y"

**Token cost:** 4-7x base session. Workers use their own context window.

## Agent View

A terminal dashboard (`claude agents`) that dispatches and monitors background
sessions. Each session runs independently with its own context.

**Use when:**
- You have several independent tasks to hand off
- Want to check status at a glance and step in only when needed
- Tasks don't require cross-agent communication

**Token cost:** Linear per session. Each background session draws from your plan quota.

## Agent Teams

Multiple coordinated sessions with a shared task list and peer-to-peer messaging.
One session acts as team lead; teammates communicate directly.

**Use when:**
- Workers benefit from each other's findings during execution
- One discovery might change another worker's approach
- Complex research, large-scale refactoring, or multi-module features

**Token cost:** ~15x base session. The communication overhead is significant.

**Example patterns:**
- UI + Backend + QA squads working on a feature in parallel
- Codebase review where findings in one module affect review of another
- Competing migration strategies where researchers share intermediate results

## Dynamic Workflows

Bundled or custom multi-subagent procedures with verification loops. Claude
runs many sub-agents and verifies their findings against each other.

**Use when:**
- You have a repeatable multi-step procedure
- Quality requires cross-checking agent outputs
- Want a reusable workflow (bundled or custom)

**vs. custom swarm:** Dynamic Workflows are the production-grade version of the
patterns in `agent-coordination`. Use them when available; fall back to custom
coordination for tool-agnostic or non-Claude runtimes.

## Worktrees

Isolated git checkouts that let agents work in parallel without file conflicts.
Each agent gets its own working directory; changes are merged at the branch level.

**Use when:**
- Multiple agents need to edit the same files
- Parallel feature development on independent branches
- Want zero file-system coordination overhead

**Setup:**

```bash
git worktree add /tmp/feature-a feature-a
git worktree add /tmp/feature-b feature-b
```

Each agent runs in its own worktree. No conflicts, no locks, clean merge at the end.

## Cost Reference (June 2026)

| Approach | Relative Cost | Context Isolation | Coordination |
|----------|--------------|-------------------|--------------|
| Single session | 1x | None (shared) | None |
| Sub-agents | 4-7x | Per-worker | Parent-child |
| Agent Teams | ~15x | Per-teammate | Peer-to-peer |
| Dynamic Workflows | 4-7x | Per-subagent | Orchestrated |

All costs draw from the same plan quota. There is no separate agent billing.

## See Also

- `agent-coordination` skill — Custom coordination patterns (tool-agnostic)
- `HARNESS.md` — Harness architecture overview
- `SUB-AGENTS.md` — Sub-agent format and cost control
