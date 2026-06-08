# ADR-010: Automated PRs Must Auto-Merge Immediately

- **Status:** accepted
- **Date:** 2026-06-08
- **Deciders:** @d-o-hub
- **Related:** PR #519, PR #518, PR #512

## Context

Automated workflows (`ci-and-labels.yml`, `update-llms-txt.yml`) create PRs on
fixed branches (`ci/status-update`, `auto/regenerate-llms-txt`) to update CI
status artifacts and LLM context files. These PRs were created and left open,
requiring manual merge or closure. Over time they accumulated (PR #518, #512),
creating noise in the PR list and confusing contributors.

The root cause: workflows used `gh pr create` but never called `gh pr merge`.
When required status checks include the PR's own branch name, `--auto` deadlocks
(the PR can't merge until checks pass, but the check is on the PR itself).

## Decision

All workflows that create automated PRs MUST immediately auto-merge using:

```bash
gh pr merge "$NEW_PR" \
  --squash \
  --subject "ci: <description> [skip ci]" \
  --admin \
  --delete-branch=false
```

Key requirements:

1. **Find-or-create pattern.** Check for existing open PR on the fixed branch
   before creating. Reuse if found.
2. **`--admin` bypass.** Bypasses required status checks to avoid deadlock when
   the CI status PR is itself a required check.
3. **`--squash` merge.** Clean single-commit history on main.
4. **`--delete-branch=false`.** The branch is force-pushed and reused; deleting
   it would break the next run.
5. **`[skip ci]` in subject.** Prevents the merge commit from re-triggering the
   workflow.
6. **Fallback cleanup.** A scheduled cleanup workflow (`cleanup-ci-status-prs.yml`)
   runs every 6 hours to close any bot-authored PRs on `auto/*` or `ci/*`
   branches older than 24 hours, as a safety net for failed auto-merges.

## Consequences

**Positive:**

- No more lingering automated PRs. CI status and LLM context updates merge
  immediately and silently.
- The 6-hour cleanup schedule catches any edge cases (token expiry, transient
  API failures) within 30 hours worst case.
- `--admin` eliminates the deadlock that prevented `--auto` from working.

**Negative / trade-offs:**

- `--admin` bypasses branch protection. If the automated PR introduces broken
  content, it merges without review. Mitigated by: the PRs only touch generated
  artifacts (ci-status.json, llms.txt) that are already validated by upstream
  jobs.
- `--delete-branch=false` means the `ci/status-update` branch persists on the
  remote. This is intentional — it's a fixed, reused branch.

## Alternatives Considered

- **`gh pr merge --auto` instead of `--admin`.** Rejected: deadlocks when the
  PR's own branch is a required status check.
- **Direct push to main (no PR).** Rejected: bypasses branch protection entirely
  and loses audit trail.
- **Weekly cleanup only.** Rejected: 7-day lag is too long; 6-hour schedule with
  auto-merge as primary is more responsive.

## References

- PR #519: <https://github.com/d-o-hub/github-template-ai-agents/pull/519>
- `.github/workflows/ci-and-labels.yml` (update-ci-status job)
- `.github/workflows/update-llms-txt.yml`
- `.github/workflows/cleanup-ci-status-prs.yml`
- `scripts/cleanup-ci-status-prs.sh`
- LESSON-032 in `AGENTS.md`
