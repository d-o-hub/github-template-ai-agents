# GOAP_STATE

## Current Mission

**Goal**: Implement all 7 open GitHub issues (#491-#497) using a multi-agent swarm, address all PR comments, ensure all GitHub Actions pass with zero warnings.

**Branch**: `main` (working from)
**CI Status**: `passing` (verified `.github/ci-status/ci-status.json` 2026-06-05T16:47Z)
**Open PRs**: 0 (will create 3)
**Open Issues**: 7 (5 unique, 2 marked duplicate but contain unique content)

## Issue Inventory

| # | Title | File scope | Deps |
|---|-------|------------|------|
| 491 | README hero rewrite | `README.md` | — |
| 492 | Why this template section | `README.md` | 491 |
| 493 | bootstrap.sh script | `scripts/bootstrap.sh` (new) | — |
| 494 | doctor.sh script | `scripts/doctor.sh` (new) | — |
| 495 | Agent compatibility matrix + Mermaid | `README.md` | 491, 492 |
| 496 | Adoption paths + practical examples | `README.md` | 491, 492, 495 |
| 497 | Normalize setup docs | `QUICKSTART.md`, `CONTRIBUTING.md`, `README.md` | 493, 494 |

## Execution Strategy: Hybrid

**3 PRs grouped by concern (per AGENTS.md "one concern per PR"):**

### Wave 1: Setup Scripts (parallel agents)

- **Branch**: `feat/bootstrap-doctor-scripts`
- **Scope**: #493, #494 (independent new files)
- **Strategy**: Parallel — 2 agents in 1 message create `bootstrap.sh` and `doctor.sh`
- **Quality gate**: shellcheck, idempotency check, `agents-docs/SCRIPTS.md` update

### Wave 2: README Overhaul (sequential per file conflict)

- **Branch**: `docs/readme-overhaul`
- **Scope**: #491, #492, #495, #496 (all touch README.md)
- **Strategy**: Sequential within single PR (all 4 are README content additions)
- **Quality gate**: markdownlint, mermaid render check, link validation

### Wave 3: Docs Normalization (depends on Wave 1)

- **Branch**: `chore/normalize-setup-docs`
- **Scope**: #497 (touches QUICKSTART.md, CONTRIBUTING.md, README.md)
- **Strategy**: Sequential, must wait for Wave 1 PR merged
- **Quality gate**: markdownlint, no orphaned references to old setup sequence

## Quality Gates

After each wave:
1. `./scripts/quality_gate.sh` — full local validation
2. `git push` → CI runs
3. Monitor `gh run watch` until all green
4. Auto-fix any failures using `self-fix-loop`
5. Address any PR review comments

## Agent Coordination Plan

| Wave | Agent | Task |
|------|-------|------|
| 1 | general (×2 parallel) | Write `bootstrap.sh` + `doctor.sh` |
| 1 | shell-script-quality | shellcheck + idempotency tests |
| 2 | general (sequential) | README content per issue acceptance criteria |
| 2 | code-review-assistant | Verify markdownlint + mermaid renders |
| 3 | general | Normalize QUICKSTART/CONTRIBUTING |
| 5 | github-pr-sentinel | Monitor CI + comments until merged |

## Actions Queue

1. [x] GOAP plan written
2. [ ] **Wave 1**: Create `scripts/bootstrap.sh` + `scripts/doctor.sh` (parallel)
3. [ ] **Wave 1**: shellcheck + quality gate
4. [ ] **Wave 1**: Branch `feat/bootstrap-doctor-scripts`, commit, push, PR
5. [ ] **Wave 1**: Verify all CI checks pass with zero warnings
6. [ ] **Wave 2**: Implement README hero + 'Why' + compatibility + adoption (sequential)
7. [ ] **Wave 2**: markdownlint + quality gate
8. [ ] **Wave 2**: Branch `docs/readme-overhaul`, commit, push, PR
9. [ ] **Wave 2**: Verify all CI checks pass
10. [ ] **Wave 3**: Normalize QUICKSTART.md + CONTRIBUTING.md + README.md Quick Start
11. [ ] **Wave 3**: Branch `chore/normalize-setup-docs`, commit, push, PR
12. [ ] **Wave 3**: Verify all CI checks pass
13. [ ] Address all PR review comments across waves
14. [ ] Close issues 491-497 via PR references (`Fixes #N` in PR body)
15. [ ] Run `learn` skill, append metrics to `.agents/metrics.jsonl`

## Blockers

- None

## Constraints (from AGENTS.md)

- Max 500 lines/file, 250/SKILL.md, 200/AGENTS.md
- PR title: `type(scope): description` (max 150 chars)
- Commit subject: max 150 chars total lowercase
- One concern per PR; never commit to main directly
- Static analysis findings must be triaged before commit
- Pre-commit hook will run automatically
