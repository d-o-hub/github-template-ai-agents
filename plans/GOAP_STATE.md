# GOAP State: Adopt P0 Primitives from do-gist-hub

## Task Analysis

**Primary Goal**: Implement Issue #581 — adopt 6 P0 generic primitives from do-gist-hub.
**Constraints**: Node 24 deadline Sep 16, 2026 (~13 weeks).
**Complexity**: Medium (5 files to create/modify, 0 architectural changes).
**ADR Link**: `plans/adr-011-adopt-p0-primitives-from-do-gist-hub.md`

## Sub-Goals

| # | Component | Priority | Deps | Strategy |
|---|-----------|----------|------|----------|
| 1 | `scripts/sha-pin-actions.sh` | P0 | none | parallel |
| 2 | `.github/workflows/audit-actions.yml` | P0 | none | parallel |
| 3 | `.github/workflows/track-gitleaks-release.yml` | P0 | none | parallel |
| 4 | `plans/adr-027-ci-node24-android-hardening.md` | P0 | none | parallel |
| 5 | `agents-docs/ci-maintenance.md` enhancement | P0 | none | parallel |
| 6 | Fix pre-existing CI (skills-reference.md stale) | P0 | none | parallel |
| 7 | Quality gate | P0 | 1-6 | sequential |
| 8 | Commit + PR | P0 | 7 | sequential |

## Execution Plan

- **Strategy**: Parallel (items 1-6), then sequential (7-8)
- **Quality Gates**: 1 checkpoint (quality gate before commit)

### Phase 1 — Implement (parallel)

- Tasks 1-6: Launch swarm agents
- Quality Gate: All files written, no syntax errors

### Phase 2 — Validate & Submit

- Run `./scripts/quality_gate.sh`
- If fails, iterative refinement
- Commit and create PR

## Summary

✓ 5 files created/modified
✓ Pre-existing CI issue fixed
✓ Quality gate green
✓ PR created

---

# Blocked: CI Status Staleness

**Status**: blocked
**ADR**: `plans/adr-028-ci-status-staleness-external-dep.md`
**Root Cause**: `.github/ci-status/ci-status.json` is stale because GitHub Actions hasn't completed a run on `main` after the latest push. This is an external dependency — the agent cannot update the CI status file directly.
**Resolution**: Will self-resolve when the next CI run completes and `update-ci-status.py` updates the file. Expected window: 10–30 minutes after push.
