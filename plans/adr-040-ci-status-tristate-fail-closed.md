# ADR-040: Fail-Closed Tri-State CI Status Artifact

## Status

Accepted (2026-09-27; refines ADR-033 and ADR-034 without contradicting their
persistence work)

## Context

ADR-033 removed one false green: a run in which **every** required job was
skipped no longer wrote `passing`. It left the mixed case open, and the mixed
case is the one that ships:

```json
{"status":"passing","failing_jobs":[],"skipped_jobs":["test"],"validated":true}
```

That is what run `36331732554` wrote on 2026-09-27. `quality-gate` succeeded,
`test` was skipped (path filter found no code changes in a docs-only commit),
and the artifact claimed green.

Three official semantics make every denylist-style gate a false-green
generator:

1. **A skipped job reports "Success" and does not block merging, even as a
   required check.** <https://docs.github.com/en/pull-requests/reference/status-checks>
   A `needs` propagation that turns a dependent into `skipped` therefore
   satisfies branch protection while the real work never ran.
2. **`failure()` is `false` for a skipped dependency.** A gate written as
   `!failure()` is fail-open. The `ci-success` job's old step did exactly this
   (`if res == "failure" || res == "cancelled"` → `exit 1`), so a skipped
   `test` passed the required check. Official guidance is `always()` **plus**
   explicit expected-value assertions.
3. **`needs.<job_id>.result` distinguishes `skipped` from `success`.** That is
   the sanctioned signal, so the classifier must consume it rather than
   infer.

Precedent: NVIDIA/cuda-python#2208 (P0, June 2026) — a required aggregator went
green while 24 build jobs were red, because dependents became `skipped` and the
aggregator only checked `failure|cancelled`. The fix was explicit-expected-value
assertion, not a wider denylist.

`AGENTS.md` tells agents to *check this file and pause unless `passing`*, so a
false `passing` defeats the repository's own gate. A second problem compounds
it: **a committed JSON file is not a merge gate** — anyone with write
permission can set any status. It is advisory, and the docs never said so.

## Decision

### 1. Tri-state, not four states

`status` ∈ {`passing`, `failing`, `unknown`}. ADR-033's fourth value `skipped`
is retired: a non-green that is not a red must read `unknown`, so no consumer
can mistake it for a pass. `check_ci_status_freshness.sh` rejects any other
value, which keeps producers and consumers converging.

### 2. Derivation rule (assert expected values, allowlist skips)

```
passing  ⟸  no failure|cancelled|timed_out
        ∧   no unrecognized result (stale, neutral, action_required, unknown enum)
        ∧   no skip outside allowed_skips
        ∧   ≥ 1 job actually succeeded
failing  ⟸  any failure | cancelled | timed_out
unknown  ⟸  everything else (unallowlisted skip, nothing ran, stale result)
```

Every skip must be **allowlisted**; allowlists are never denylists. Skips are
tolerated only when the repository deliberately lists the job id in
`CI_STATUS_ALLOWED_SKIPS` (default: empty). The invariant
`status == "passing" ⟹ validated ∧ failing_jobs = [] ∧ unallowed_skips = []`
holds by construction, so the artifact cannot contradict itself.

`cancelled` and `timed_out` are red but keep their own buckets instead of being
collapsed into `failing`; `stale` means **unknown** per its check-run semantics
and lands in `unknown_jobs`.

### 3. Schema v3

`schema_version`, `status`, `last_run`, `validated`, `failing_jobs`,
`skipped_jobs`, `allowed_skips`, `unallowed_skips`, `cancelled_jobs`,
`timed_out_jobs`, `unknown_jobs`, `succeeded_jobs`, `advisory_only`,
`workflow_url`.

`allowed_skips ∪ unallowed_skips = skipped_jobs` (partition, enforced).
`validated` now means "the gate was certified green" (was: "at least one job
succeeded"), so `passing ⟺ validated`. `advisory_only: true` records in the
artifact itself that a committed file cannot block a merge.

### 4. Producer is the single source of truth; the gate reads it

`ci.yml`'s `Check all required jobs passed` step now calls
`python3 scripts/update-ci-status.py --check`, which asserts
`needs.<job>.result == 'success'` per dependency (or an allowlisted skip) and
**fails when `needs` is empty** — vacuous truth is fail-open. The write mode
and the gate share one derivation, so they cannot drift.

The `Update CI status artifacts` step lost its
`needs.quality-gate.result != 'skipped' || needs.test.result != 'skipped'`
condition (ADR-033 decision 5). That condition existed to protect a green from
being overwritten by a bookkeeping run; with a fail-closed classifier the
producer writes `unknown` — which is the honest record — so the fragile
second derivation of gate semantics is deleted rather than duplicated. The step
stays **last-adjacent but before** the gate so a red run is always persisted.

### 5. Consumers and docs

- `check_ci_status_freshness.sh` validates the tri-state enum, the schema
  version, list types, the skip partition, and six explicit
  self-contradiction rules. A non-`passing` status is a **warning**, not a
  failure: the validator checks coherence and freshness, not greenness.
- `AGENTS.md`, `GEMINI.md`, `QWEN.md`, `README.md`, `agents-docs/SCRIPTS.md` state
  the tri-state and the advisory-only caveat.
- `stale`, `neutral` and `skipped` were added to the validator's
  `BAD_REMOTE_CONCLUSIONS`; only `success` certifies a remote run.

## Consequences

- **Docs-only merges on `main` will record `unknown`, not `passing`.** The
  `test` job's `if: needs.changes.outputs.code == 'true'` is path-driven, not
  deliberate, so it stays outside the allowlist. This is the intended
  fail-closed outcome: the repository cannot certify that tests passed for a
  change that never ran them. Maintainers who accept that trade-off must set
  the `CI_STATUS_ALLOWED_SKIPS` repository variable explicitly.
- `AGENTS.md`'s "pause unless passing" rule now pauses on docs-only states. That
  is the rule working, not a regression.
- ADR-033's `skipped` status and `validated: "≥1 success"` semantics are
  superseded; its persistence work (decision 5) is intentionally replaced.
- ADR-034 is untouched: the automerge PR fallback, janitor thresholds, and
  `ci.yml`-scoped remote parity all still stand.
- The repo currently has **no** `required_status_checks` in the
  `Main Branch Protection` ruleset (ruleset 10252573 carries only
  `pull_request`, `deletion`, `required_linear_history`, `code_quality`,
  `code_scanning`). Nothing blocks on `CI Success` today, so the artifact is
  strictly advisory until a check-run is required. Documented, not changed —
  ruleset changes are disclosed separately per ADR-034 decision 3.

## Remediated artifact

`last_run` is the real completion time of run `36331732554`
(`2026-09-27T16:03:22Z`, verified via `gh run view`): `quality-gate` = success,
`test` = skipped, run conclusion = `success`. With an empty allowlist that is
`status: unknown`, `unallowed_skips: ["test"]`, `validated: false`. No green
was fabricated.

## Verification

- `pytest tests/test_ci_status_tristate.py tests/test_update_ci_status.py` — 29 passed
- `bats tests/test-check-ci-status-freshness.bats` — 14/14
- `python3 -m py_compile scripts/update-ci-status.py`; `shellcheck --severity=error` clean
