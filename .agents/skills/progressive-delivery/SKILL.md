---
name: progressive-delivery
description: >-
  Remediate a live production failure through a gated loop: reproduce the failure, generate a
  candidate fix, evaluate it, red-team it adversarially, then shadow, canary, and promote or roll back
  on SLO verdicts. Use when production is degraded and the fix must itself be proven safe, or when the
  user is already mid-rollout and needs shadow/canary/rollback decisions — even if they just say "roll
  this out safely", "canary this fix", or "prove the fix". Not for shipping changes through git/GitHub
  (use git-github-workflow), for running tests or diagnosing failures (use test-runner), for
  iterate-until-green validation loops (use iterative-refinement), or for authoring CI/CD pipeline
  config (use cicd-pipeline).
category: workflow
license: MIT
version: "0.2.10"
---

# Progressive Delivery

Production remediation as a gated loop. No stage is skipped; every gate has
an explicit verdict (proceed / abort-and-roll-back) recorded before moving on.

## When to Use

- Production failure needs a fix that must itself be proven safe
- Rolling out a risky change (migration, perf patch, security hardening)
- Setting up shadow/canary/promote/rollback stages in any stack
- Even if they just say "roll this out safely", "canary this", or "prove the fix"

## The Loop

### 1. Failure — capture the signal

Record the failing symptom with evidence: alert text, dashboard link, log
excerpt, failing check name. No fix work starts without a pinned symptom.

### 2. Reproduce — minimal, deterministic

Build the smallest reproducer (failing test, script, or eval case) that fails
before the fix and passes after. Commit it with the fix so regressions recur
as test failures, not incidents.

### 3. Candidate fix — smallest blast radius

Prefer the minimal change that resolves the reproducer. Note what it does
NOT change. Keep migrations and behavior changes in separate commits.

### 4. Evaluate — static + functional gates

Run the repo gates (`./scripts/quality_gate.sh`, targeted tests,
`./scripts/validate-skills.sh` for skill changes). All must pass with zero
warnings before rollout stages.

### 5. Adversarial evaluation — red-team the fix

Author at least one negative case (EVAL.md convention): inputs crafted to
break the fix — reverted-fix checks, boundary values, permission-denied
paths, prompt-injection shapes for agent-facing changes. The fix must fail
closed. See OWASP GenAI LLM Top 10 2026 and MITRE ATLAS for attack shapes.

### 6. Shadow — mirrored traffic, zero user impact

Mirror production traffic to the candidate without serving from it
(Istio `mirror`, Flagger `mirror: true`, Gateway API RequestMirror). Compare
outputs and error rates against stable. Writes must be idempotent or
shadowed read-only; never mirror non-idempotent writes without a sink.

### 7. Canary — weighted traffic on SLO verdicts

Shift traffic in small steps (e.g. 5% → 25% → 50% → 100%) with an
`AnalysisTemplate`-style SLO check at each step (success rate, p99 latency,
error budget). Any threshold breach aborts the rollout and returns traffic
to stable. Keep rollouts short (minutes to ~2h); long-lived canaries are a
smell — promote or roll back. (Argo Rollouts / Flagger 2026 practice.)

### 8. Promote / rollback — decided by data, executed at once

Promote only on consecutive green SLO windows; roll back on first breach —
never "wait and see". Record the verdict, the metrics snapshot, and the
rollback commit. File a follow-up for the root cause if the fix was a
mitigation rather than a cure.

## Stage Cheat Sheet

| Stage | Gate question | Abort action |
|-------|---------------|--------------|
| Reproduce | Does it fail deterministically? | No fix without a repro |
| Evaluate | Gates green, zero warnings? | Fix, don't proceed |
| Adversarial | Fails closed on negatives? | Harden, re-run |
| Shadow | Output parity + no errors? | Stop mirroring, diagnose |
| Canary | SLOs green at this weight? | Traffic to stable, scale canary to 0 |
| Promote | Consecutive green windows? | Roll back on first breach |

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The fix is obviously correct, skip shadow/canary." | Obviously-correct fixes cause the worst incidents; the loop exists because judgment fails under pressure. |
| "Canary is slow — push to 100% and watch dashboards." | Watching dashboards is detection, not prevention; blast radius is the cost you pay for skipping steps. |
| "Adversarial cases are overkill for this fix." | One negative case costs minutes and catches fail-open logic that functional tests never exercise. |
| "The canary looks mostly fine, let it ride." | "Mostly fine" without SLO thresholds is how degraded states become permanent; abort criteria must predate the rollout. |

## Red Flags

- [ ] Proceeding to rollout stages with warnings in static gates
- [ ] Shadow stage mirroring non-idempotent writes to live sinks
- [ ] Canary weights increasing without a recorded SLO verdict per step
- [ ] Rollback plan missing ("we'll figure it out if it breaks")
- [ ] No reproducer committed alongside the fix

## References

- `agents-docs/SKILL_EVAL_TIERS.md` — NVIDIA SkillEvaluator tier mapping
- `evals/evals.json` — cases incl. adversarial negatives

## See Also

- `test-runner` — Execute tests and diagnose failures (stages 2–4)
- `security-code-auditor` — Audit the fix for vulns (stage 5 input)
- `git-github-workflow` — commit/PR/merge mechanics (runs alongside the loop)
- `iterative-refinement` — Validation loops until quality criteria are met
