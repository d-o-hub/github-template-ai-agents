# ADR-008: Enforce Conventional Commits for All Contributors (including bots)

- **Status:** accepted
- **Date:** 2026-06-07
- **Deciders:** @d-o-hub
- **Related:** PR #505, run 27086771117

## Context

PR #505 was opened by `google-labs-jules[bot]` with four prose-style commit
subjects (376–433 chars) that violated every commitlint rule in
`commitlint.config.cjs`:

- `header-max-length: 150` (all commits 2.5–3× over)
- `type-empty`, `subject-empty`, `subject-full-stop`

The `commitlint` job on `.github/workflows/commitlint.yml` correctly failed the
PR. A secondary warning also surfaced:

> `Unexpected input(s) 'from', 'to', valid inputs are ['entryPoint', 'args',
> 'configFile', 'failOnWarnings', 'failOnErrors', 'helpURL', 'commitDepth',
> 'token']`

This is because the workflow still passes `from`/`to` to
`wagoid/commitlint-github-action@v6.2.1`, which dropped those inputs in v6
(it now uses `commitDepth` and infers the range from the PR).

The repo's documented convention (`AGENTS.md` "PR & Commit Instructions",
`scripts/ai-commit.sh`, `scripts/validate-commit-message.sh`) is enforced only
when an agent or human runs the helper. **No commit-time hook blocks
non-conventional messages** for *any* contributor, including bots that bypass
local hooks (Jules, Dependabot, Copilot, etc.).

## Decision

Add **layered defenses** so non-conventional commits are caught at the
earliest possible stage and the workflow self-cleans:

1. **Workflow self-fix.** Drop the legacy `from`/`to` inputs from
   `.github/workflows/commitlint.yml` (v6 infers the range).
2. **PR-time guard.** Add a `lint-pr-title` job that runs commitlint over
   the PR title (squash-merge subject). Prevents merges whose title would
   itself fail lint.
3. **Commit-time hook.** Add `scripts/commit-msg-hook.sh` that runs
   `validate-commit-message.sh` for every contributor (local or CI-side),
   including bots that have no local git environment. Install it from
   `bootstrap.sh` and `install-git-hooks.sh` alongside the existing
   pre-commit hook.
4. **Bot guardrails.** Update `jules-delegator/SKILL.md` with a mandatory
   "Post-Pull Normalization" step that rewrites non-conventional commit
   messages in a Jules branch before opening a PR. Add a Red Flag and a
   Rationalization row.
5. **Sentinel auto-fix.** Extend `github-pr-sentinel/SKILL.md` with a
   `chore(commit): normalize bot commits to conventional format` template
   the sentinel can use to amend the head branch when it detects prose-style
   commits.
6. **Lesson.** Record LESSON-029 and LESSON-030 in root `AGENTS.md`.

## Consequences

**Positive:**

- Future Jules/Copilot/Dependabot PRs can no longer open with non-conventional
  commits silently: the PR title job fails, and the commit-msg hook blocks
  bad local commits.
- The sentinel gains a known escape hatch for prose-style commits, reducing
  the number of PRs that need human rewording.
- The v6 workflow no longer emits a misleading `from`/`to` warning.

**Negative / trade-offs:**

- The PR title is a *separate* source of truth from the commits; a bot that
  bypasses both still gets caught only at merge time by branch protection
  (assuming the repo sets `required_status_checks` for the new job).
- `install-git-hooks.sh` becomes mandatory on `bootstrap.sh`; existing clones
  that haven't re-run bootstrap will lack the commit-msg hook until next
  setup.
- The jules-delegator skill grows by ~20 lines; we re-validate via
  `validate-skill-format.sh` (already in the quality gate).

## Alternatives Considered

- **Auto-rewrite every bot PR via GitHub Action.** Rejected: rewrites the
  history, breaks Jules's own audit trail, and hides real authorship.
- **Add a "merge: normalize" commit.** Rejected: pollutes history with
  empty diff commits and confuses `git bisect`.
- **Disable commitlint on PRs from bots.** Rejected: that's a regression -
  bots are exactly where convention violations cluster.

## References

- PR #505 run: <https://github.com/d-o-hub/github-template-ai-agents/actions/runs/27086771117>
- `commitlint.config.cjs`
- `scripts/ai-commit.sh`, `scripts/validate-commit-message.sh`
- `wagoid/commitlint-github-action@v6.2.1` `action.yml`
- `.agents/skills/jules-delegator/SKILL.md`
- `.agents/skills/github-pr-sentinel/SKILL.md`
