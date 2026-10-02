# CI Status Contract

> Authoritative reference for `.github/ci-status/ci-status.json` and
> `.github/ci-status/ci-summary.md`. Decision record:
> [`plans/adr-040-ci-status-tristate-fail-closed.md`](../plans/adr-040-ci-status-tristate-fail-closed.md).

## TL;DR

- `status` is **tri-state**: `passing` | `failing` | `unknown`. Only `passing`
  clears the gate. `unknown` is **not** a pass.
- A **skipped** required job is never `passing` unless that job is explicitly
  allowlisted.
- The file is **advisory**. A committed JSON file is not a merge gate — anyone
  with write permission can set any status.

## Why a skipped job cannot be green

GitHub reports a job skipped by an `if:` condition as conclusion **`Success`**,
and a skipped job **does not block a merge even when it is a required check**
([docs](https://docs.github.com/en/pull-requests/reference/status-checks)).
Additionally, `failure()` is `false` for a skipped dependency, so a gate written
as `!failure()` is fail-open.

That makes every *denylist* gate (`res == "failure" || res == "cancelled"`) a
false-green generator. A `needs` chain that propagates a skip can satisfy branch
protection while the work never ran — the NVIDIA/cuda-python#2208 failure mode
(P0, June 2026), where a required aggregator went green while 24 build jobs were
red.

The remedy is the sanctioned signal: `needs.<job_id>.result` distinguishes
`skipped` from `success`, so assert the **expected** value per dependency and
**allowlist** skips instead of denylisting them.

## Derivation rule

`scripts/update-ci-status.py` owns this rule; the workflow gate reads the same
code path via `--check`.

| `status` | Condition |
|----------|-----------|
| `failing` | any job result in {`failure`, `cancelled`, `timed_out`} |
| `passing` | no failing result **and** no unrecognized result **and** no skip outside `allowed_skips` **and** at least one job actually succeeded |
| `unknown` | everything else — unallowlisted skip, nothing ran, or a result outside the known enum |

Invariants that make self-contradiction impossible:

```text
status == "passing"  ⟹  validated ∧ failing_jobs = [] ∧ unallowed_skips = []
                           ∧ unknown_jobs = [] ∧ cancelled_jobs = []
                           ∧ timed_out_jobs = [] ∧ succeeded_jobs ≠ []
allowed_skips ∪ unallowed_skips = skipped_jobs
```

`unrecognized` covers `stale`, `neutral`, `action_required` and any unknown
enum value. `stale` means **unknown**, so it maps to `unknown_jobs`, never to
`failing`. `cancelled` and `timed_out` are red but keep separate buckets.

## Schema (v3)

```json
{
  "schema_version": 3,
  "status": "unknown",
  "last_run": "2026-09-27T16:03:22Z",
  "validated": false,
  "failing_jobs": [],
  "skipped_jobs": ["test"],
  "allowed_skips": [],
  "unallowed_skips": ["test"],
  "cancelled_jobs": [],
  "timed_out_jobs": [],
  "unknown_jobs": [],
  "succeeded_jobs": ["quality-gate"],
  "advisory_only": true,
  "workflow_url": "https://github.com/.../actions/runs/36331732554"
}
```

`validated` means "the gate was certified green", so `passing ⟺ validated`.

## Advisory, not authoritative

`advisory_only: true` is written into the artifact. Only a **required status
check** can block a merge. As of 2026-09-27 the `Main Branch Protection`
ruleset (10252573) carries only `pull_request`, `deletion`,
`required_linear_history`, `code_quality` and `code_scanning` — no
`required_status_checks` — so nothing blocks on `CI Success` today. Treat the
artifact as a fast signal and confirm with `gh run list` before acting.

## Allowing a skip deliberately

`allowed_skips` is empty by default. To accept a skip, set the
`CI_STATUS_ALLOWED_SKIPS` repository variable (comma or space separated job
ids), consumed by `.github/workflows/ci.yml`:

```bash
CI_STATUS_ALLOWED_SKIPS=test
```

**Do not allowlist `test` reflexively.** `test` used to be gated by
`if: needs.changes.outputs.code == 'true'`, so docs-only changes skipped it.
That skip was path-driven, not deliberate: a docs-only change cannot certify
that tests passed, while this repository's suite reads `SKILL.md`, generated
catalogs, `.github/workflows`, and `scripts/lib`. The gate was removed rather
than allowlisted — the fix for a job that never ran is to run it (ADR-041's
lesson, applied to the job condition instead of an inner step). Any remaining
skip is therefore unexpected: confirm it with `gh run view` before thinking
about the allowlist.

## Scripts

| Script | Role |
|--------|------|
| `scripts/update-ci-status.py` | Producer: derives the artifact and `ci-summary.md`; `--check` is the fail-closed gate |
| `scripts/persist-ci-status.sh` | Commits the artifacts and opens the automerge PR |
| `scripts/check_ci_status_freshness.sh` | Consumer: schema, coherence, freshness, and `gh run list` parity |

`check_ci_status_freshness.sh` fails on incoherence and staleness. A
non-`passing` `status` is only a **warning** — the validator checks honesty, not
greenness.

## Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `CI_STATUS_ALLOWED_SKIPS` | *(empty)* | Allowlist of job ids whose skip is tolerated |
| `CI_STATUS_TIMESTAMP` | *(run time)* | ISO-8601 run completion time; used when backfilling artifact provenance |
| `NEEDS_JSON` | `{}` | `toJSON(needs)` of the aggregator job |
| `WORKFLOW_URL` | *(empty)* | URL of the run being summarized |
| `CI_STATUS_MAX_AGE_SECONDS` | `86400` | Freshness window for `last_run` |
| `CI_STATUS_BRANCH` | `main` | Branch compared by the freshness validator |
| `CI_STATUS_RUN_LIMIT` | `5` | Runs fetched by the freshness validator |

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `status: unknown` with `unallowed_skips` non-empty | A required job was skipped by its `if:` — `test` no longer is, so this now means `quality-gate` path-filtered both jobs out, or a job was skipped some other way | Confirm the real state with `gh run view`; decide whether the skip is deliberate, then set `CI_STATUS_ALLOWED_SKIPS` |
| `self-contradictory CI status` from the validator | Artifact hand-edited or produced by a stale producer | Re-run the producer; do not hand-edit the JSON |
| `CI status is stale` | The persist loop has not converged | See ADR-034; check the automerge PR and the janitor |

## Rationalizations

- **Fail-closed, not fail-open.** `unknown` is a legitimate answer. Guessing
  green is worse than admitting ignorance because agents gate on this file.
- **One source of truth.** The write path and the required gate share
  `update-ci-status.py`, so the artifact and the gate cannot disagree.
- **Explicit expected-value assertions.** Asserting `result == 'success'` per
  dependency is the documented remedy for the cuda-python#2208 class of bug.
- **Allowlists over denylists.** A denylist must enumerate every future way to
  not pass; an allowlist only widens by explicit decision.

## Red Flags

- `status: passing` next to a non-empty `skipped_jobs` without a matching
  `allowed_skips` entry — always a false green.
- A gate written as `!failure()` or `res == "failure" || res == "cancelled"` —
  both pass when a dependency was skipped.
- Hand-editing `ci-status.json` to unblock work. It is generated and it is
  advisory; a hand-edit is immediately overwritten by the next run.
- Treating `unknown` as "probably fine". It means a required job did not run.
- Assuming a `passing` artifact means a merge would be blocked. Only a required
  check blocks, and this repository does not currently require `CI Success`.

## Related

- ADR-033 — eliminated the all-skipped false green (superseded in part)
- ADR-034 — autonomous persistence of the artifact (unchanged)
- ADR-040 — this tri-state contract
- `agents-docs/LESSONS.md` — LESSON-021 (stale artifact), LESSON-035 (metrics)
