# ADR-028: CI Status Staleness as External Dependency

## Status

Accepted

## Context

The `check_ci_status_freshness.sh` script validates that `.github/ci-status/ci-status.json` reflects current GitHub Actions state. When an agent pushes a commit to `main`, the CI status file becomes stale until GitHub Actions completes a new run and the `update-ci-status.py` workflow updates the file.

This creates a window (typically 10–30 minutes) where `doctor.sh` reports CI status as stale, even though the commit itself is valid and the branch is green.

## Decision

Treat CI status staleness as an **external dependency** that cannot be resolved locally by the agent. The agent's responsibility is limited to:

1. Ensuring the current commit's quality gate passes locally.
2. Not suppressing, skipping, or marking as done the stale CI status finding.
3. Documenting the issue if it blocks a workflow (this ADR).

The CI status will self-resolve when:
- GitHub Actions completes a run on `main` after the push.
- The `update-ci-status` workflow updates the status file.
- The `cleanup-ci-status-prs` workflow closes stale CI status PRs.

## Consequences

- `doctor.sh` may report CI status as stale for up to 30 minutes after a push. This is expected behavior, not a bug.
- Agents should not attempt to manually update `ci-status.json` — it is maintained by CI workflows.
- If CI status staleness blocks a merge or deployment, the agent should wait for the next CI run rather than bypass the check.
