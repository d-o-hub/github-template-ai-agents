# GOAP STATE — Pre-existing Issue Remediation Sweep

Branch: `fix/tier2-p0-and-eval-measurement`
Date: 2026-09-27
Orchestrator: goap-agent (swarm strategy)

## Primary Goal

Eliminate **every** tracked pre-existing issue and every quality-gate warning in
this repository, grounded in official docs and Sept 2026 best practice. No item
is skipped; each is either fixed or explicitly re-deferred with a filed issue.

## Enumerated Inventory (evidence-backed)

| # | Issue | Evidence | Cluster |
|---|-------|----------|---------|
| 1 | Tier 2 script orphaned from all gates/CI | no reference outside own comment; absent from `agents-docs/SCRIPTS.md` | F |
| 2 | Tier 3 unimplemented; `run_loop.py` is description-eval only | `run_loop.py:2` docstring | G |
| 3 | `ci-status.json` false-green: `status: passing` with `skipped_jobs: ["test"]`, `validated: true` | `.github/ci-status/ci-status.json` | E |
| 4 | `skill-creator/SKILL.md` 253 lines (max 250) — warning x2 | quality_gate + loc_gate | D |
| 5 | `quality_gate.sh` 496/500 lines — 4 lines headroom | `wc -l` | C |
| 6 | `check-plan-numbering.sh` silently skips: needs `plans/README.md`, absent | quality_gate `(Skipping check: ...)` | D |
| 7 | `agentic-abstention` at `version: "0.1.0"` vs 43 skills at `0.2.10` | frontmatter | A |
| 8 | `template_version:` policy undefined — 3 of 54 declare it, yet `skill-validation.sh` checks it | issue #941 | A |
| 9 | Catalog descriptions truncate mid-sentence (routing regression) | issue #941 | B |
| 10 | 13 Tier-2 overlap pairs unreviewed | `--strict` output | G |
| 11 | Pre-commit hook missing in `.git/hooks` | `doctor.sh` | local env |

## Resolution (2026-09-27)

All 11 enumerated items plus 5 found by research are resolved or explicitly
re-deferred with a filed issue. No item was skipped.

| # | Item | Outcome |
|---|------|---------|
| 1 | Tier 2 orphaned from gates/CI | `agents-docs/SCRIPTS.md` + CI_STATUS contract documented; threshold now a real gate in the drift suite |
| 2 | Tier 3 unimplemented | Corrected the false ADR-037 mapping; documented as **not implemented** in `SKILL_EVAL_TIERS.md` + ADR-040; deferred to a filed issue |
| 3 | `ci-status.json` false-green | Schema v3 tri-state, fail-closed (`unknown`), `allowed_skips` allowlist, `cancelled`/`timed_out`/`stale` split, ADR-040. Artifact now honestly reads `unknown` |
| 4 | `skill-creator/SKILL.md` 253 lines | 253 -> 210; content extracted to `references/scripts.md` |
| 5 | `quality_gate.sh` 496/500 | 496 -> 356; extracted to `scripts/lib/lang-checks.sh` (was syntactically broken on arrival) |
| 6 | `check-plan-numbering.sh` silent skip | `plans/README.md` added; `||` split into 3 outcomes; regex miss now a failure. Check executes: `next plan 001, next ADR adr-041` |
| 7 | `agentic-abstention` version drift | **Not a defect** — semver-legal; documented as a release stamp, not per-skill semver |
| 8 | `template_version` policy | Full Frontmatter Field Policy in `agents-docs/SKILLS.md`; dead staleness check now announces its deliberate skip |
| 9 | Catalog truncation | 220 -> 1024 chars, word-boundary + `Not for` guard retention. Truncated 52/54 -> 0; guards present 2/50 -> 50/50 |
| 10 | 13 overlap pairs | **Not real** — noise floor 0.0267 vs true dup 0.9556. Threshold corrected 0.04 -> 0.02 -> **0.50**; corpus now correctly clean |
| 11 | Pre-commit hook missing | `core.hooksPath=.githooks` set (repo's own bootstrap step) |
| 12 | 5 skills had unparseable YAML frontmatter | All 54 now `yaml.safe_load` clean; `tests/test-skill-frontmatter-yaml.bats` |
| 13 | `pytest.mark.unit` unregistered | **Already resolved** — registered at `pyproject.toml:157`; verified |
| 14 | `dynamic-catalog.sh` clobbered the catalog | Reduced to a delegating shim; it destroyed **0/54** routing guards vs the canonical generator |
| 15 | `update-agents-registry.sh` 60-char mid-word cuts | Word-boundary trim via `MAX_REGISTRY_DESC_CHARS` |
| 16 | `eval-skills.sh` false header comment | Corrected to describe what it actually validates |
| 17 | `check_structure.py` false docstring | Corrected |
| 18 | Skill quality drift fixture (`test-security-fixes.sh` 6d) | Confirmed self-consistent; no change needed |

## Two corrections this sweep made to its own earlier work

1. **Threshold `0.04` -> `0.02` was wrong, twice.** Research showed 5-gram Jaccard
   scores of 0.02 are boilerplate noise, not semantic overlap. The correct value is
   `0.50`, between the 0.0267 noise floor and 0.9556 true duplication. The 13
   "candidates" are noise; acting on them would have been a false-positive merge.
2. **`--strict` passed green while crashing.** A `NameError` also exits 1, so the
   gate's own test could not detect the missing `import sys`. Fixed by asserting
   the absence of a traceback, not just the exit code.

## Strategy

## Strategy

Swarm: 4 parallel research agents (official docs / Sept 2026 practice) →
6 parallel fix agents (independent file sets) → sequential integration +
quality gates.

## Quality Gates

- G1: research synthesis written to `plans/`
- G2: per-cluster tests pass
- G3: `quality_gate.sh` zero warnings
- G4: `doctor.sh` clean
- G5: full `bats tests/` green

## Constraints

- Never commit to `main` (ADR-008 commit format, `type(scope): subject`)
- `MAX_LINES_PER_SOURCE_FILE=500`, `MAX_LINES_PER_SKILL_MD=250`
- No hardcoded values — named constants only
- Temporary files in `/tmp` only (gitleaks enforced)
