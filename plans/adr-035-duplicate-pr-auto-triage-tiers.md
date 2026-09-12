# ADR-035: Duplicate PR Auto-Triage Tiers

## Status

Accepted (2026-09-12, derived from round-5 PR triage of the #861/#863/#864
pileup; replaces the misattributed ADR-034 references in the duplicate guard)

## Context

Automation (Jules, Bolt, Dependabot) spawned ~20 redundant PRs in one month:
5 byte-identical CodeQL pin PRs, 10 overlapping `paths.py` PRs, 9 subshell-perf
PRs. The duplicate guard (`scripts/detect-duplicate-prs.sh`, scheduled 6-hourly
via `.github/workflows/duplicate-pr-guard.yml`) operated without its own ADR
and was misattributed to ADR-034, which actually covers the CI-status
persistence loop.

The 2026-09-12 triage exposed two gaps in the guard's two-tier design:

1. One Jules task produced three overlapping `paths.py` PRs. The exact tier
   (byte-identical whole-diff hashes) did not match because each PR carried a
   different slice of the change, and the near tier (>=70% meaningful-file
   overlap) only flags — never closes. The older two PRs were *strict subsets*
   of the newest: every shared file's patch was byte-identical, yet the guard
   could not act on that containment.
2. The guard's `superseded-candidate` label did not exist in the repo, and the
   swallowed `gh pr edit` error left flags comment-only and invisible to
   label-based triage (label self-heal fixed in #869; the label was created
   in-repo out-of-band).

## Decision

1. **Three auto-triage tiers** in `detect-duplicate-prs.sh`, always comparing
   the older PR against the newer and keeping the newest as survivor:
   - **EXACT** — byte-identical whole-diff hashes: auto-close the older PR.
   - **SUBSET** (new) — the older PR's meaningful-file set is a *proper subset*
     of the newer PR's set *and* every shared file's patch is byte-identical
     across both PRs: auto-close the older PR. The newer PR applies every
     change the older one makes, so closing loses nothing. Divergent patches on
     any shared file fall through to the near tier.
   - **NEAR** — >=70% meaningful-file overlap: comment + label
     `superseded-candidate`, never auto-close (unchanged).
2. **Single diff fetch per PR.** Per-file patch hashes and the meaningful-file
   list are derived from the same `gh pr diff` payload (sections split on
   `diff --git` headers), replacing the separate `--name-only` call.
3. **Self-healing label** — a failed `--add-label` creates the label on
   demand, retries once, and warns on stderr if labeling still fails (#869).
4. **ADR attribution corrected** — the guard cites ADR-035, not ADR-034.

## Consequences

- Subset PRs converge autonomously instead of waiting for manual triage.
- False-close risk is bounded: auto-close requires byte-identical per-file
  patches; base drift, rebase churn, or any divergence degrades to the
  flag-only near tier. Equal-file-set PRs with different patches (conflicting
  edits) are never auto-closed.
- Fewer GitHub API calls (one `gh pr diff` per PR instead of two).
- DRY_RUN and the idempotent HTML marker behavior are preserved on all tiers.

## Verification

- `bats tests/test-detect-duplicate-prs.bats`: subset duplicate auto-closes;
  divergent-patch subset stays flag-only; all pre-existing tiers unchanged.
- `shellcheck` clean; `./scripts/quality_gate.sh` passed.
