# Auto-Merge Workflow (Opt-In)

This template ships with an opt-in, label-gated auto-merge workflow for
non-Dependabot PRs:

- File: `.github/workflows/auto-merge-non-deps.yml`
- Label: `automerge`
- Effect: When the label is applied to a PR and CI is green, the PR is
  squash-merged automatically. Maintainer-side friction from "Update
  Branch" clicks is removed.

## When to use

- Trivial docs/comments-only changes
- Cherry-pick fixes that you've already reviewed locally
- Dependabot-style automation for non-bot authors

## When NOT to use

- Architectural changes requiring human review
- PRs with unresolved human review feedback — the workflow refuses and
  posts a PR comment explaining why
- PRs that should wait for additional maintainer approval

## How it works

1. Apply the `automerge` label to a PR.
2. The `auto-merge-non-deps.yml` workflow fires on the `labeled` event.
3. The workflow re-checks the label and `isDraft == false` (defense in
   depth against race conditions between `if:` evaluation and the
   GraphQL call).
4. The workflow scans all unresolved review threads and categorises
   each by author type. Threads with any human-authored comment are
   treated as human feedback; threads where every comment is from a
   bot/app/org author are auto-resolvable.
5. If any unresolved human thread exists, the workflow refuses to
   auto-merge and posts a PR comment listing the human authors.
6. Otherwise, the workflow resolves the bot/app threads and calls
   `enablePullRequestAutoMerge` with `mergeMethod: SQUASH`.
7. GitHub merges the PR automatically once all required checks pass.

## Trust boundary

Only GitHub users with `triage`+ access can apply labels (the default
permission model for outside collaborators). The label is intentionally
NOT listed in `.github/labeler.yml`, so the auto-labeler cannot apply
it based on file-path rules. The label write itself acts as the
explicit opt-in.

## Caveats

- Removing the `automerge` label does NOT auto-disable an enabled
  auto-merge. A maintainer must click `Disable auto-merge` in the
  PR UI.
- For Dependabot PRs, see `.github/workflows/dependabot-auto-merge.yml`.
  That workflow does NOT differentiate bot vs human review threads; it
  silently resolves all unresolved threads. Track parity as follow-up.
