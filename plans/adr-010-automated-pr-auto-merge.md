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

**Permissions**: the workflow grants both `pull-requests: write` AND
`contents: write` on the `GITHUB_TOKEN`, mirroring
`dependabot-auto-merge.yml`. Initial analysis (PR #745) attributed a
run of `failure` conclusions to missing `contents: write`; later work
(PR #746) showed the actual root cause was a YAML parse error in the
`script: |` block scalar (see "Lessons" below). The `contents: write`
permission is retained as a defensive mirror of the proven dependabot
workflow but is not load-bearing for F8's fix to take effect.

**Defense-in-depth**: the workflow re-asserts `isDraft == false` inside the
GraphQL step so a PR that becomes a draft after the label was applied
still refuses to auto-merge.

**Bot-vs-human review thread handling**: the workflow queries each
unresolved review thread's first comment author and categorises them as
`Bot` / `App` / `Organization` (auto-resolvable, e.g. Codacy false
positives) or anything else (treated as human review feedback). If ANY
unresolved thread is human-authored, the workflow refuses to auto-merge,
logs the thread IDs and authors, and exits. Bot threads are
auto-resolved. This defends against the case where a real reviewer left
feedback that the maintainer (via the `automerge` label) would
otherwise silently dismiss.

### Consequences

**Positive**:

- Removes the "last version needed" friction for maintainer PRs carrying
  the `automerge` label.
- Reuses the proven `enablePullRequestAutoMerge` GraphQL mutation pattern
  from `dependabot-auto-merge.yml` (squash, branch auto-update handled by
  GitHub).
- Bot-vs-human differentiation prevents silent dismissal of human review
  feedback when the `automerge` label is applied.
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
- The `dependabot-auto-merge.yml` reference workflow *does* still
  silently resolve human threads. Out of scope here but tracked for
  follow-up parity.

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
- **Treat `Organization` as a bot type.** Accepted: GitHub Apps and
  org-owned bots (e.g. `github-actions[bot]`) are not human reviewers.
  If a specific org-owned bot is incorrectly classified, the work-around
  is to resolve the thread manually before applying the `automerge` label.

### References

- `.github/workflows/auto-merge-non-deps.yml` (this addendum)
- `.github/workflows/dependabot-auto-merge.yml` (pattern mirrored; not yet
  bot-vs-human aware)
- Issue #741 (the dedup fix this PR was sequenced after)
- `plans/GOAP_STATE.md` (run 2026-07-28)

### Lessons from the F7 / F8 debug cycle (2026-07-28)

The `auto-merge-non-deps.yml` workflow failed with `failure` conclusion
on 7 consecutive runs across three PRs (#742, #743, #745). PR #745
(the "F7" attempt) theorised the failure was a missing `contents: write`
permission. After merging #745, the failure persisted — disproving the
hypothesis. The actual root cause (discovered in PR #746, "F8") was a
**YAML parse error in the `script: |` block scalar**.

**Symptom**: workflow concluded `failure` on every run where the
`automerge` label was present. No JS code in the script ever executed —
GitHub Actions rejected the workflow at YAML parse time.

**Cause**: the `script: |` block scalar started at 12-space indent at
its first content line. Subsequent JS lines (the `// 2. Categorize...`
comment block and below) were inserted at 0-space indent, falling below
the scalar's minimum indent. The YAML parser treats the scalar as
terminated at that point and the orphan JS at <12-space indent becomes
invalid YAML (e.g. `// ...` is not valid YAML; `const ...` is not valid
YAML), so the workflow file cannot be loaded.

**Excerpt from `cat -A` of the BROKEN file (line numbers preserved)**:

```text
            if (pr.isDraft) {
              console.log(`PR #${prNumber} is a draft. Refusing to auto-merge.`);
              return;
            }
$MISMATCH FROM HERE$
// 2. Categorize unresolved review threads by author type across ALL
//    comments in the thread (not just the first) ...
const isBotAuthor = (author) => {
  if (!author) return false;
  const t = author.__typename;
  return t === 'Bot' || t === 'App' || t === 'Organization';
};
```

Every line of the script body must remain at the scalar's first-content
indent (12 spaces in this file) or more. F8's fix is a full rewrite of
`.github/workflows/auto-merge-non-deps.yml` with consistent
indentation throughout the script body.

**Diagnosis methodology** (forward-looking guidance for future
workflow debugging):

- **Distinguish load-time failure from runtime failure.** When a
  workflow concludes `failure` with no log output from the script step,
  the failure is at workflow-load (YAML parse) time. Permissions and
  GraphQL errors would surface as JS-execution-time errors with stack
  traces in the step log.
- **Run log retrieval returned 404** for all 6+ failed runs. This is a
  GitHub Actions quirk: once a workflow fails at load time and is
  re-run, older run logs may be pruned or relocated. The
  `gh api /repos/.../actions/runs/<id>/logs` endpoint returned 404 for
  all attempts. Diagnosis therefore had to rely on static analysis
  (`cat -A`, `yaml.safe_load`) and cross-comparison with a working twin
  (`dependabot-auto-merge.yml`).
- **Validate YAML before pushing.** `python3 -c "import yaml; yaml.safe_load(open('.yaml'))"` parses the file. A 409-line workflow file
  with a 189-line script body is feasible for static review where
  dynamic debugging isn't available.
- **Correlational evidence is not causal.** F7 correctly observed that
  `dependabot-auto-merge.yml` works AND has `contents: write`. From
  this it inferred that `auto-merge-non-deps.yml` failing AND missing
  `contents: write` meant the permission was the cause. The inference
  was correlational, not causal. The real cause was orthogonal
  (indentation). A load-time error and a runtime permission error
  present identically but require different fixes — distinguishing
  them without logs required a different mental model.
