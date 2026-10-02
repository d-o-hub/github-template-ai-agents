# Plans

Working directory for Architecture Decision Records (ADRs), GOAP execution
plans, and cross-session handover state for this template.

The single source of truth for numbering is `plans/_status.json`. The two
counter lines below mirror `nextAvailable` from that file so a human opening
this directory can see the next free identifiers without reading JSON.
`./scripts/check-plan-numbering.sh` — wired into `./scripts/quality_gate.sh` —
fails the gate if the two ever disagree, or if either counter is missing.

**Next available plan number**: `001`

**Next available ADR number**: `adr-042`

## Directory contents

| Path | Purpose |
|------|---------|
| `_status.json` | Numbering counters, active plan, phase table, and the ADR registry. Schema: [`STATUS_SCHEMA.md`](STATUS_SCHEMA.md). |
| `README.md` | This file: the human-readable counter mirror. |
| `adr-NNN-*.md` | Architecture Decision Records. Numbered from `adr-007`; `adr-001`–`adr-006` predate the numbering scheme. |
| `GOAP_STATE.md` | Active GOAP decomposition and phase progress. |
| `GOAP_PRESWEEP_STATE.md` | Pre-sweep findings register used to drive a remediation pass. |
| `PR-resolution-summary.md` | Roll-up of resolved PR review threads. |
| `monthly-eval-schedule.md` | Cadence for the mandatory skill-evaluation report. |
| `pre-existing-issues.md` | Issues observed in CI that predate the current change. |
| `unresolved-comments.md` | Review threads still awaiting resolution. |
| `followup-actionlint-false-positives.md` | Known actionlint false positives to suppress. |
| `handovers/` | Cross-session context snapshots referenced by `handover_ref`. |
| `archive/` | Superseded plans and ADRs, kept for history. |

## Adding a plan

1. Claim the next plan number from `nextAvailable.plan` in `_status.json`.
2. Write the plan as `plan-NNN-<slug>.md` in this directory.
3. Bump `nextAvailable.plan` and register any new ADR in `entries`.
4. Update the counter line at the top of this file in the same commit.

## Adding an ADR

1. Claim the next ADR number from `nextAvailable.adr` in `_status.json`.
2. Write the record as `adr-NNN-<slug>.md`, using the structure of the
   neighbouring records (Context, Decision, Consequences, Status).
3. Register it under `entries` in `_status.json` with a `status` of
   `proposed`, `accepted`, or `rejected` and an ISO `date`.
4. Update the ADR counter line at the top of this file in the same commit.

Steps 3 and 4 are checked together by `check-plan-numbering.sh`; a commit that
updates one without the other fails the quality gate.
