# GOAP State: Codebase Improvement Plan

> Status: **EXECUTING** · Started: 2026-07-05
> Strategy: Hybrid (Sequential phases, parallel within phases)
> ADR: Not required — plan already approved as ADR-equivalent document

## Sub-Goals

| # | Goal | Phase | Priority | Deps | Status |
|---|------|-------|----------|------|--------|
| G1 | Fix broken skill refs (#1) | A | P0 | none | PENDING |
| G2 | Regenerate AGENTS.md table (#2) | A | P0 | none | PENDING |
| G3 | De-hardcode version (#3) | A | P0 | none | PENDING |
| G4 | Extend link validation (#4) | A | P0 | none | PENDING |
| G5 | Gitignore + rm eval artifacts (#5,#6) | B | P1 | none | PENDING |
| G6 | Align AGENTS.md limit (#7) | B | P1 | none | PENDING |
| G7 | Fix QUICKSTART (#8) | B | P1 | none | PENDING |
| G8 | Fix .gitignore (#9) | C | P2 | none | PENDING |
| G9 | Dedupe quality_gate.sh (#10) | C | P2 | none | PENDING |
| G10 | Update CHANGELOG-TEMPLATE.md | POST | P1 | G1-G9 | PENDING |
| G11 | Create PR + verify CI | POST | P0 | G1-G10 | PENDING |
| G12 | Cleanup plans/ folder | POST | P2 | G11 | PENDING |

## Phase A — Correctness (parallel)

Tasks G1-G4 are independent. Execute all in parallel.

## Phase B — Cruft reduction (parallel)

Tasks G5-G7 are independent. Execute all in parallel after Phase A.

## Phase C — Housekeeping (parallel)

Tasks G8-G9 are independent. Execute all in parallel after Phase B.

## Progress Log

- 2026-07-05: GOAP planning complete, executing Phase A
