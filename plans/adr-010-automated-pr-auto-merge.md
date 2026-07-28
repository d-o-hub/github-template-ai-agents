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

## Addendum: Opt-In Auto-Merge for Trusted Authors (2026-07-28)

### Context

The original decision in this ADR applied to *bot-authored* PRs on fixed
branches (`ci/status-update`, `auto/regenerate-llms-txt`). For human-authored
PRs by `d-o-hub` and other maintainers, the `dependabot-auto-merge.yml`
workflow deliberately skips (`if: github.event.pull_request.user.login ==
'dependabot[bot]'`), so every maintainer PR required a manual
`gh pr merge --auto` step. With branch protection requiring
`Require branches to be up to date before merging`, this degraded into the
"last version always needed" symptom — every `main` advancement forced an
`Update Branch` click before merge.

### Decision

Add `.github/workflows/auto-merge-non-deps.yml`: an opt-in, label-gated
auto-merge workflow that mirrors `dependabot-auto-merge.yml` but for any
non-Dependabot PR carrying the `automerge` label.

**Gate**:

```yaml
if: |
  contains(github.event.pull_request.labels.*.name, 'automerge') &&
  github.event.pull_request.user.login != 'dependabot[bot]' &&
  github.actor != 'dependabot[bot]' &&
  github.event.pull_request.draft == false
```

**Trust boundary**: the `automerge` label can only be applied by a GitHub
user with `triage` (or higher) write access on the repo (the default
permission model for outside collaborators). The label is intentionally NOT
listed in `.github/labeler.yml`, so the auto-labeler cannot apply it
based on file-path rules. The label write itself acts as the explicit
opt-in: a maintainer (or designated collaborator) must deliberately add
the label, and removing the label is a future improvement (currently
auto-merge once enabled cannot be auto-disabled by this workflow).

**Defense-in-depth**: the workflow re-asserts `isDraft == false` inside the
GraphQL step so a PR that becomes a draft after the label was applied
still refuses to auto-merge.

### Consequences

**Positive**:

- Removes the "last version needed" friction for maintainer PRs carrying
  the `automerge` label.
- Reuses the proven `enablePullRequestAutoMerge` GraphQL mutation pattern
  from `dependabot-auto-merge.yml` (squash, branch auto-update handled by
  GitHub).
- Opt-in: no behaviour change unless the label is applied.

**Negative / trade-offs**:

- Once `enablePullRequestAutoMerge` fires, removing the `automerge` label
  does not auto-disable auto-merge. A maintainer must click
  `Disable auto-merge` in the PR UI. Track as follow-up.
- Does **not** resolve a different class of bug: if multiple PRs from the
  same maintainer are open simultaneously, each must be re-merged after
  every `main` advancement. This is GitHub's default behaviour and not
  addressed here.
- Does **not** widen `dependabot-auto-merge.yml`'s `if:` guard (rejected
  for supply-chain reasons — see `plans/GOAP_STATE.md` 2026-07-28 lessons).

### Alternatives Considered

- **Widen `dependabot-auto-merge.yml`'s `if:` to allow trusted human
  actors.** Rejected: any owner with push rights could then auto-merge
  their own unreviewed code. The label gate here is opt-in *and* explicit.
- **`gh pr merge --auto` from a separate workflow that always runs.**
  Rejected: same supply-chain concern; also runs the workflow on every PR
  even when not wanted.
- **Tighter trust boundary: only `d-o-hub` user can apply the label.**
  Out of scope; the label-write gate is sufficient today and can be hardened
  via a `CODEOWNERS`-style rule later.

### References

- `.github/workflows/auto-merge-non-deps.yml` (this addendum)
- `.github/workflows/dependabot-auto-merge.yml` (pattern mirrored)
- Issue #741 (the dedup fix this PR was sequenced after)
- `plans/GOAP_STATE.md` (run 2026-07-28)
