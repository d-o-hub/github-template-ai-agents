# ADR-033: Eliminate False-Green CI Status Artifacts

## Status

Accepted (GOAP-orchestrated review swarm remediation, derived from PR #795 roast)

## Context

`scripts/update-ci-status.py::determine_status()` classifies any run with no
`failure`/`cancelled` as `"passing"`. A run in which every required job was
`skipped` (path-filtered out, as happens for `.github/ci-status/*` bookkeeping
pushes) therefore writes `"status": "passing"` even though **no validation
ran**. Because `.github/workflows/ci.yml` persists the status artifact on any
`main` push (`if: github.ref == 'refs/heads/main'`), a no-op bookkeeping run
overwrites a truthful green with a false one. Downstream agents gate on
`.github/ci-status/ci-status.json` (see `AGENTS.md`, `GEMINI.md`, `QWEN.md`), so
a false-green tells every agent "the tree validated" when nothing executed.
The freshness validator has no rule to catch `passing` + skipped.

## Decision

1. **Classifier** — `determine_status` returns:
   - `failing` if any `failure` or `cancelled`;
   - `passing` if at least one job `success`; otherwise
   - `skipped` (all jobs skipped/unknown — never `passing`).
2. **Schema (ci-status.json v2)** — add `skipped_jobs: []` and
   `validated: true|false`. `validated` is `true` iff at least one job had
   result `success` (i.e., a real validation ran).
3. **Writer** — emit the new fields; render `ci-summary.md` header from the
   computed `status` and add a `⚠️` warning line when any job was skipped.
4. **Validator** — `check_ci_status_freshness.sh` lists `skipped_jobs` and
   `validated` as required fields, type-checks them, and flags
   `status == "passing" && validated == false` as an inconsistency (false-green).
5. **Workflow gate** — `ci.yml` writes/persists status artifacts only when
   `needs.quality-gate.result == 'success' || needs.test.result == 'success'`,
   so an all-skipped run cannot overwrite a green.
6. **Remediate committed artifact** — add `skipped_jobs: []`, `validated: true`
   to the checked-in `.github/ci-status/ci-status.json`.

## Consequences

- Agents and the freshness gate can now distinguish "green & validated" from
  "nothing ran" (skipped jobs are surfaced).
- A bookkeeping-only run no longer produces a false `passing`.
- `ci-status.json` schema grows by two fields; all consumers (validator +
  existing BATS/integration tests) are updated in lock-step.
- Defense in depth: the classifier + the workflow gate both prevent false-green.

## Follow-up

- Add regression tests: `test_all_skipped_is_not_passing` (writer) and a
  freshness BATS case for `passing` + `validated:false`.
