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
