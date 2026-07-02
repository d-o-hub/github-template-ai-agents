---
name: agentic-abstention
version: "0.1.0"
category: agent
description: |
  Encode CONVOLVE-style stopping rules: decide when to stop acting instead of
  continuing tool calls on an infeasible task. Use this skill whenever an agent
  must determine if further execution is warranted. Not for general task
  planning (use goap-agent).
license: MIT
---

# Agentic Abstention

Decide when to stop acting instead of continuing tool calls on an infeasible task.

## When to Use This Skill

- Agent has made repeated tool calls with no progress
- Task appears blocked by environment constraints
- Resource errors indicate the goal is unreachable
- Agent must decide between retrying and emitting ABSTAIN

## Core Stopping Rules (CONVOLVE-derived)

Any single rule triggers mandatory abstention. All thresholds reference
`AGENTS.md` named constants.

### Rule 1: Empty-Result Repetition

Agent returns 2+ consecutive tool calls that yield identical empty or null
results. A single empty result does NOT trigger abstention.

**Check**: `result[N] == result[N-1] == empty` (N ≥ 2)

### Rule 2: Resource Unavailable

Target resource returns HTTP 404, connection refused, DNS resolution failure,
or equivalent "does not exist" signal from the environment.

**Check**: Error code ∈ {404, 502, 503, ECONNREFUSED, ENOENT}

### Rule 3: No-Progress Step Budget

Agent has taken ≥ `DEFAULT_MAX_RETRIES` (3) steps without measurable progress
toward the goal. Progress is measured by state change in the task output.

**Check**: `steps_since_last_progress ≥ DEFAULT_MAX_RETRIES`

### Rule 4: Infeasibility Signal

External system, user, or tool explicitly states the task cannot be completed
(e.g., "not supported", "does not exist", "permission denied", "cannot be done").

**Check**: Output contains explicit infeasibility keyword

### Rule 5: Timeout Budget Exceeded

Elapsed wall-clock time since task start exceeds `DEFAULT_TIMEOUT_SECONDS`
(1800s). Agent must track start time at task initiation.

**Check**: `now - task_start_time > DEFAULT_TIMEOUT_SECONDS`

## ABSTAIN Protocol

When any rule fires, emit the following and halt:

1. **Log**: Record which rule triggered and relevant context
2. **Emit**: Return structured ABSTAIN response:

   ```json
   {
     "action": "ABSTAIN",
     "rule": "<rule-name>",
     "reason": "<brief explanation>",
     "steps_taken": <int>,
     "elapsed_seconds": <int>
   }
   ```

3. **Halt**: Do NOT retry the failed action

## What NOT to Do

- Do not retry after a rule fires — the rule indicates futility
- Do not bypass rules by rephrasing the same tool call
- Do not ignore timeout because "almost done" — budget is absolute
- Do not treat a single empty result as Rule 1 — requires 2+ repetitions

## Integration with Existing AGENTS.md Constants

| Constant | Value | Applies to Rule |
|----------|-------|-----------------|
| `DEFAULT_MAX_RETRIES` | 3 | Rule 3 (No-Progress Step Budget) |
| `DEFAULT_TIMEOUT_SECONDS` | 1800 | Rule 5 (Timeout Budget Exceeded) |

## Example Usage

**Scenario**: Agent searches for a file 3 times, each returning empty.

1. Call 1: `glob("missing.txt")` → empty (no abstain)
2. Call 2: `glob("missing.txt")` → empty (Rule 1 fires: 2+ empty results)
3. **Action**: Emit ABSTAIN with `rule: "empty-result-repetition"`

**Scenario**: Agent calls API, receives 404.

1. Call 1: `GET /api/v1/resource/999` → 404
2. **Action**: Emit ABSTAIN with `rule: "resource-unavailable"`

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "One more try might work" | If a stopping rule fired, the evidence says it will not. Retrying wastes tokens. |
| "The timeout hasn't hit yet" | Rules are independent — timeout is one of five triggers, not the only one. |
| "I'll rephrase and try again" | Rephrasing the same infeasible request still wastes resources. Halt and report. |

## Red Flags

- [ ] Continuing execution after any stopping rule fires
- [ ] Treating first empty result as a stopping condition (Rule 1 requires 2+)
- [ ] Ignoring explicit "cannot be completed" messages
- [ ] Skipping ABSTAIN emission and silently failing

## References

- CONVOLVE stopping rules — origin of the 5-rule framework
- `AGENTS.md` named constants — `DEFAULT_MAX_RETRIES`, `DEFAULT_TIMEOUT_SECONDS`

## See Also

- `goap-agent` — Task decomposition and planning
- `iterative-refinement` — When to continue refining (opposite of abstention)
