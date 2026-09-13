# GOAP STATE: PR Triage & CI Remediation (Round 3 — 2026-08-11)

## Goal

Triage all 9 open PRs (merge impactful, close duplicates/no-impact with roast comments),
root-fix pre-existing CI failures + warnings on main, and leave main CI green with a
fresh `.github/ci-status/ci-status.json`.

## Main context

- Main HEAD at start: `00b51b6` (Round 2 final), main CI green. Pre-existing defects:
  1. **Commit Lint failure on main** at `8d673e1` (2026-08-07, run 31176723566):
     `footer's lines must not be longer than 100 characters` — squash-merge bodies
     (PR markdown) become footers; `commitlint.config.cjs` enforced 100 despite the
     same rationale disables for `body-max-line-length`.
  2. **Stale `.github/ci-status/ci-status.json`** — frozen at `last_run: 2026-06-18`.
     Root cause: `ci.yml` persist step does `git push origin main`, rejected by the
     `Main Branch Protection` ruleset (GH013) and masked by `continue-on-error: true`.
  3. **CI warnings**: `PytestUnknownMarkWarning: Unknown pytest.mark.unit` in
     `do-web-doc-resolver`; transient "Could not fetch schema" for opencode.json.
- Security PRs #775/#776/#778/#783 were 4 near-identical "block db creds/legacy shells/REPL
  histories" denylist PRs (same 9 `FORBIDDEN_PATHS` entries). User decision: **denylist-only
  (#775) is canonical; #776/#778/#783 are duplicates.**

## Swarm (GOAP)

| Role | Task | Outcome |
|------|------|---------|
| closer | close #781 (no-impact/root-guardrail), #776, #778, #783 (dups) w/ roast | ✅ CLOSED + roast comments |
| security-merger | rebase + merge #775 (denylist + tests) | ✅ `ba0aa0e` |
| perf-merger | merge #777 (skills-ref globbing), #782 (doctor.sh globbing) | ✅ `6937ace`, `599354c` |
| dependabot-merger | merge #779 (6 actions), #780 (rust-toolchain) | ✅ `16034fc`, `5a43238` |
| ci-fixer A | commitlint footer-max-line-length `[0]` + quality-gate test sync | #784 |
| ci-fixer C | register `unit` pytest marker | #785 |
| ci-fixer B | `scripts/persist-ci-status.sh` ruleset-safe persist + refresh ci-status | #786 |

## Dependency graph

```
close dup/no-impact PRs (parallel, safe)          → DONE
merge #775 → #777 → #782 → #779 → #780 (sequential, gated on Codacy) → DONE
CI-fix PRs (#784, #785, #786) — independent files, merged after dependabot ci.yml bumps → IN FLIGHT
verify: zero open PRs, main CI green, ci-status fresh, quality gate pass → PENDING
```

## Progress / Deviations

- #781 ignored GOAP-style consult; closed with root-guardrail roast. #778/#783 roast on
  identical-hunk duplication. #776 roast: denylist redundant + `id_` generalization needs its
  own scoped PR.
- Merges executed via `gh pr merge --squash --delete-branch`; strict ruleset requires
  rebase-onto-main per merge (`gh pr update-branch --rebase`), Codacy is the only required
  status check.
- Fix A: commitlint pass verified with a >100-char footer message; quality-gate consistency
  test updated in lock-step (escaping footgun noted).
- Fix C: `pytest tests/test_cache_helpers.py -m 'not live'` → 4 passed, 0 warnings.
- Fix B: script bash-`-n` + shellcheck clean; commit+push path validated in a local bare-repo
  sandbox; `continue-on-error` removed so persist failures surface.

## Final State (to be confirmed)

- Open PRs: **0** (all 9 resolved; 1 canonical merged per group, dups closed)
- Main CI: **green**; Commit Lint failure class eliminated by Fix A; ci-status persistence
  self-healing via automerge PR (Fix B); pytest warning gone (Fix C).

---

# GOAP STATE: False-Green CI Status Remediation (Round 4 — 2026-08-14)

## Goal

Eliminate false-green CI status artifacts: a run in which every required job is
skipped must never be persisted as `passing`. Derived from the PR #795 roast
(auto-generated bot bookkeeping stamped `passing` while quality-gate/test were
`⏭️ skipped`).

## Swarm (GOAP) — parallel implementers, one file each, fixed interface contract

| Role | File | Outcome |
|------|------|---------|
| impl-writer | `scripts/update-ci-status.py` | ✅ status classifier + `skipped_jobs`/`validated` schema + md warning |
| impl-tests | `tests/test_update_ci_status.py` | ✅ 5 tests (added all-skipped & mixed cases) |
| impl-validator | `scripts/check_ci_status_freshness.sh` | ✅ required fields + passing&&!validated rule |
| impl-bats | `tests/test-check-ci-status-freshness.bats` | ✅ fixtures + false-green case |
| impl-workflow | `.github/workflows/ci.yml` | ✅ gate writer on real success |
| impl-data | `.github/ci-status/ci-status.json` | ✅ add skipped_jobs/validated (validated:true) |

## Contract (ADR-033)

- `validated` = true iff ≥1 job `success`;
  `status`∈{passing,failing,skipped,unknown} with `skipped` only when all
  required jobs are skipped, and `unknown` when only unexpected results were
  seen (never passing).
- JSON schema v2: status, last_run, failing_jobs, skipped_jobs, validated, workflow_url.
- ci.yml writes status when at least one required job ran (NOT both skipped):
  `needs.quality-gate.result != 'skipped' || needs.test.result != 'skipped'`
  — so failures are recorded and all-skipped runs can't overwrite a green.

## Review (roast-driven) fixes (Round 4b)

- Gate corrected from "any success" to "not both skipped" — the former
  re-created a false-green on `{failure, skipped}` by never writing `failing`.
- `determine_status` now distinguishes `unknown` from `skipped`.
- Validator uses a dedicated `FALSE_GREEN_MESSAGE` instead of reusing the
  remote-parity message.

## Quality gate

- `python3 -m unittest tests.test_update_ci_status` → 5/5 OK
- `bats tests/test-check-ci-status-freshness.bats` → false-green case + 4 others OK
  (test 1 "fresh without gh" fails only when `gh` is auto-detected in the sandbox
  `/usr/bin`; passes when gh is unavailable — environmental, not a regression)
- `bats tests/test-ci-status-workflow.bats` → 6/6 OK
- YAML parse OK (gate on step [2]); shellcheck clean; python compile OK.

## Final State

- False-green eliminated by defense-in-depth (classifier + workflow gate + validator rule).
- Committed `.github/ci-status/ci-status.json` now carries `skipped_jobs`/`validated`.

## Round 4 (2026-09-06): CI status persistence loop + template 0.2.13

- Diagnosed why the artifact stayed stale despite ADR-033: GITHUB_TOKEN event
  suppression (automerge workflow never fired), janitor closing fresh artifact
  PRs, dead required Codacy check, freshness validator false-reds.
- Fixed in #839/#841; ruleset Codacy requirement removed (ADR-034); artifact
  PRs #840/#842 converged autonomously — verified twice.
- Template version bumped to 0.2.13 (#843) with sonar.projectVersion anchor.
- Anti-churn guard (duplicate PR detection) added — see ADR-035
  and .github/workflows/duplicate-pr-guard.yml.

## Round 5 (2026-09-13): swarm PR triage — #878/#879 roasted, fixed, merged

- Goal: analyze/review/roast all open PRs (incl. drafts); close no-impact,
  ready+fix impactful, merge in order once CI green. goap-agent as
  orchestrator with a 2-agent review swarm (one per PR).
- CI gate: `.github/ci-status/ci-status.json` = passing at start.
- #879 `fix(security): block private/secret key prefixes` — impact yes.
  Fixes: dropped `secret_key` prefix (redundant under existing `secret`
  startswith, zero behavior change), replaced 3 tautological test cases
  (`private-key.pem`/`privkey.pem` blocked by `.pem` suffix on main,
  `secret_key.txt` by `secret` prefix) with `private-key.txt`/`privkey`,
  verified fail-on-revert; retitled (secret half already shipped).
  Merged `1a9a545`.
- #878 `perf: eliminate sed subshells` — impact yes (~115x/call, ~0.1s/run).
  Fixes: retitled `Bolt: perf:` -> `perf(scripts):` (ADR-008 lint was
  failing), corrected future-dated (2026-10-27) bolt entry to 2026-09-13
  with blank-line separator + "hyphen" typo. Merged `3499eb9`.
- Lessons:
  1. Jules re-synced its branch 14min after my fix push and clobbered both
     edits with its original workspace state (re-commit under same subject);
     re-applied on top of the new tip. Merge bot PRs promptly after fixes.
  2. GitHub PR-API major outage 2026-09-13: CodeQL/Trivy SARIF uploads died
     mid-request, `commit_refs` fatal on push, and one reported-failed push
     actually landed (zombie merge commit). Triage via step-level
     conclusions: scan steps succeeded -> failure was platform, not code.
  3. Draft PRs run a reduced check set; the full suite (incl. lint-pr-title
     and Run Tests) only fires on ready_for_review — stale failing checks
     from pre-retitle events need a rerun/retrigger to clear.
