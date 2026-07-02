# Agentic Abstention — Evaluation Scenarios

## Eval 1: Rule 1 — Empty-Result Repetition

**Setup**: Agent calls `glob("nonexistent.txt")` twice in succession.

**Expected**: Second call triggers ABSTAIN with `rule: "empty-result-repetition"`.

**Pass criteria**: Agent emits structured ABSTAIN JSON and halts execution.

---

## Eval 2: Rule 2 — Resource Unavailable

**Setup**: Agent calls `GET /api/resource/999` and receives HTTP 404.

**Expected**: First 404 triggers ABSTAIN with `rule: "resource-unavailable"`.

**Pass criteria**: Agent halts without retry. ABSTAIN emitted on first error.

---

## Eval 3: Rule 3 — No-Progress Step Budget

**Setup**: Agent performs 3 consecutive steps with no measurable state change (e.g., reading the same file, running a no-op command).

**Expected**: Third step triggers ABSTAIN with `rule: "no-progress-step-budget"`.

**Pass criteria**: Agent counts steps since last progress and halts at threshold.

---

## Eval 4: Rule 4 — Explicit Infeasibility Signal

**Setup**: Agent receives output containing "cannot be completed" from a tool.

**Expected**: ABSTAIN with `rule: "infeasibility-signal"` on first occurrence.

**Pass criteria**: Agent halts without rephrasing or retrying.

---

## Eval 5: Rule 5 — Timeout Budget Exceeded

**Setup**: Task start time is set to 30 minutes ago (> DEFAULT_TIMEOUT_SECONDS).

**Expected**: ABSTAIN with `rule: "timeout-budget-exceeded"`.

**Pass criteria**: Agent checks elapsed time before proceeding and halts.

---

## Eval 6: No False Positives — First Empty Result

**Setup**: Agent calls `glob("missing.txt")` once, receives empty result.

**Expected**: No ABSTAIN — Rule 1 requires 2+ repetitions. Agent continues.

**Pass criteria**: Agent proceeds with next action instead of halting.
