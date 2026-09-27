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

## Round 6 (2026-09-25): roast-review-merge #900 → #906 → #905 (ADR-036)

- Goal: fix-then-merge all 3 open PRs (0 open issues; none qualifies for
  no-impact close). User decisions: keep `.jules/bolt.md`, narrow security
  narrative to low-severity filename-policy scope, include pre-existing debt.
- Order (file-overlap dependency): #900 (CLEAN, +4/-1) → #906 (same 2 files,
  needs rebase + full CI retrigger) → #905 (disjoint file, Codacy FAIL).
- Swarm (GOAP orchestrator): swarm-900 (security-merger), swarm-906
  (security-merger), swarm-905 (perf-merger + BATS), swarm-909 (security),
  swarm-debt (investigation only). Merges sequential; fix-prep parallel.
- Gates per PR: all bot + owner comments addressed, `bash -n`,
  `shellcheck --severity=error` clean, BATS + pytest green,
  `quality_gate.sh` pass, `gh pr checks` all-green, rebase onto main,
  squash-merge + delete branch. Jules-clobber watch (Round-5 lesson 1).
- Status: IN FLIGHT (ADR-036 accepted).

## Round 6 final (2026-09-27)

- Merged: #900 `a3ab345a` (curlrc/wgetrc + consumer test, label delabeled),
  #909 `85582b69` (kubeconfig.yaml/yml + consumer test), #905 `2a1f5f44`
  (assoc-array perf + 11 BATS cases, Codacy fail cleared), #912 `69147c72`
  (token-prefix follow-up: policy comment, secret_key dropped, consumer test).
- #906 closed unmerged; content shipped via #907 (lost review fixes → #912).
- Open PRs: 0. Open issues: 0. Debt: skill `version:` already 0-missing;
  validate-links re-verified clean (no read loops, exit 0).
- Merge tactic that beat the sync-bot + main-churn loop: clean linear branch
  → push → `gh pr merge --auto --squash` immediately; auto-merge fires on the
  validated tip before the next sync. Direct merge kept racing (`Base branch
  was modified` from ci-status artifact PRs landing every few minutes).

## Round 7 (2026-09-27): NVIDIA SkillEvaluator reuse + production pipeline

- Goal: adopt SkillEvaluator tier semantics without vendoring (ADR-037);
  ship `progressive-delivery` skill for the production loop
  (failure → reproduce → fix → evaluate → adversarial → shadow → canary →
  promote/rollback); add keyless Tier-2 `check-skill-overlap.sh` (advisory).
- Swarm: single primary + research (web-search-researcher); no subagents
  needed (small, cohesive change).
- Gates: `validate-skills.sh`, BATS for new script, `quality_gate.sh`,
  full CI on PR, squash-merge via `--auto`.
- Status: IN FLIGHT (ADR-037 accepted).

## Round 8 (2026-09-27): skill consolidation execution (ADR-038)

- Goal: execute dogfood verdicts in revertable PRs — safe edits, triz +
  sentinel + coordination folds, testdata/verification/tvm/docs-hook folds,
  6 demotions to SKILLS_OPTIONAL. KEEP deviations: jules-delegator,
  turso-db, do-web-doc-resolver (workflow-coupled, documented in ADR-038).
- Gates per PR: generators re-run, `git grep` cross-ref check,
  `validate-skills.sh`, `quality_gate.sh`, full CI, `--auto` merge.
- Status: IN FLIGHT (ADR-038 accepted).

## Round 8 final (2026-09-27)

- Merged: #918 (trigger hygiene + registry fixes), #920 (triz merge),
  #922 (sentinel + coordination folds + registry link fix), #923-era folds
  (testdata/verification/tvm + 6 demotions), #926 (debugger,
  secrets-management, dependency-upgrades).
- Deviations: KEEP docs-hook (load-bearing 169-line sync script),
  jules-delegator, turso-db, do-web-doc-resolver (workflow-coupled).
- Ghost-dir lesson: `git rm` leaves ignored `__pycache__` behind, tripping
  directory-iterating validators — `rm -rf` ghost dirs (LESSON-043).
- Registry generator bug fixed (block-scalar descriptions 12→0 missing).
- Open PRs: 0. Open issues: 0. Overlap gate: 0 pairs.

## Round 6 deviations (2026-09-27, primary log)

1. **#906 closed via #907**: Jules/user merged token-prefix content as #907
   (`d3d89fbd`, +`secret_key`/`secret-key` extra) WITHOUT swarm-906 fixes
   (consumer test, fail-closed policy comment, narrowed claim). Follow-up PR
   required to port those gaps; also review `secret_key` redundancy (Round-5
   #879 deliberately dropped it as covered by `secret` startswith).
2. **Jules clobbered swarm-900 fix**: auto-sync merge commits (`d6bc456f`)
   broke `pull_request`-event runs (`action_required` on 8 workflows) and
   later force-pushed a re-cut branch (`9421045c`) dropping `03f68a53`.
   Fixed by cherry-picking (`b3857358`+`49bebdc4`) onto `8068e220`,
   force-push with lease, linear history → fresh runs `queued`, anomaly gone.
3. **NEW PR #909** (kubeconfig.yaml/yml suffixes): same 2 files as #900.
   Order now #900 → #909 → #905. Roast: gap real (bare `kubeconfig`
   suffix never matched `*.yaml`), tests meaningful, still needs consumer
   test + narrowed wording + full CI.
4. **`gh pr edit` label op broken repo-wide**: GraphQL `projectCards`
   deprecation error. Workaround: REST
   `DELETE /issues/{n}/labels/{name}` (used for #900 `superseded-candidate`).

## Round 9 (2026-09-27): post-creation audit of gap skills (ADR-039)

- Goal: independent quality pass on debugger, secrets-management,
  dependency-upgrades, progressive-delivery (5 axes each).
- Swarm: 4 parallel read-only audit agents, one per skill; primary
  consolidates verdicts (KEEP / DISTILL / FIX).
- Gates: validate-skills.sh, quality_gate.sh, full CI, --auto merge.
- Status: IN FLIGHT (ADR-039 accepted).

## Round 9 final (2026-09-27)

- Merged: #936 (bidirectional Not-for guards across 8 skills, evals 13->19,
  versions aligned, registries regenerated).
- Audit verdicts: all 4 skills FIX (no DISTILL). Real defects found:
  privacy-first mis-routed "hardcoded secrets"; migration-refactoring stole
  the bump lane; progressive-delivery's "Ship production fixes" collided
  with git-github-workflow's "ship it"; debugger's bare "why is this
  failing" stole test-runner traffic.
- Swarm: 4 parallel read-only audit agents; primary consolidated.
- Open PRs: 0. Open issues: 0. Overlap gate: 0 pairs. Skills: 54.
