# ADR-039: Post-Creation Audit of Gap Skills (Round 9)

Status: Accepted (build mode, 2026-09-27)
Date: 2026-09-27

## Context

Round 8 created four skills to close audit gaps (`debugger`,
`secrets-management`, `dependency-upgrades`, `progressive-delivery` in
Round 7) without a post-creation quality pass. Per `skill-creator` loop
(create → eval → iterate) and the EVAL.md negatives convention, new skills
require an independent audit before they are considered stable.

## Decision

1. Audit each skill on five axes: sibling overlap (Tier-2 gate +
   description Jaccard), trigger collisions, eval quality (realism,
   near-miss, adversarial fail-closed), references/scripts integrity,
   registry presence.
2. Execute via GOAP swarm: 4 parallel read-only audit agents, one per
   skill; primary consolidates verdicts (KEEP / DISTILL / FIX).
3. Fixes ship as one PR (one concern: new-skill hardening); gates:
   `validate-skills.sh`, `quality_gate.sh`, full CI, `--auto` merge.
4. Findings feed `learn` synthesis; metrics logged per-agent.

## Consequences

- Positive: new skills meet the same bar applied to the rest of the
  catalog in Round 8; trigger routing stays collision-free.
- Negative: small review churn on freshly-merged content.
- Risks: none to CI (read-only audit; fixes validated like any PR).
