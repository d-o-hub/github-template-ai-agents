# Workflow Reference

> Detailed workflow procedures referenced by AGENTS.md.
> Keep procedures here, not in AGENTS.md, to stay within `MAX_LINES_AGENTS_MD=200`.

## Pre-Existing Issue Resolution

Scope depends on your process mode (see `AGENTS.md`):

- **Light mode (default for adopters):** fix pre-existing issues that are
  **related to your change**. Flag unrelated failures to the user instead of
  silently expanding scope — change-scoped work keeps PRs reviewable.
- **Full mode (template maintainers):** fix ALL pre-existing issues before
  completing the task.

**Process (Full mode):**

1. Run quality gate: `./scripts/quality_gate.sh`
2. Note all failures (even unrelated to your changes)
3. Fix ALL issues
4. Re-run quality gate to confirm zero failures

## Atomic Commit Workflow

The atomic commit pattern validates, commits, pushes, creates PR, and verifies CI.

```bash
# Create feature branch
git checkout -b feat/your-feature-name

# Make changes

# Run quality gate (validates changes before commit)
./scripts/quality_gate.sh

# If checks fail, fix and retry
```

See `.agents/skills/git-github-workflow/SKILL.md` for the full command specification.

## Post-Task Learning

After non-trivial work, capture non-obvious discoveries:

1. **Run the `learn` skill** if available, or manually append to the nearest relevant `AGENTS.md`
2. **Capture only**: hidden file relationships, surprising execution behavior, undocumented commands, fragile config, files that must change together
3. **Never write**: obvious facts, duplicates, verbose explanations, session-specific notes
4. **Scoping**: project-wide → root `AGENTS.md`; script-specific → `scripts/AGENTS.md`; skill-specific → `.agents/skills/<name>/AGENTS.md`

This ensures the template self-improves over time as projects evolve. See `agents-docs/LESSONS.md` for the verbose historical record.

## Quality Gate Usage

```bash
# Full quality gate (required before commit)
./scripts/quality_gate.sh

# Skip specific checks (only these are implemented in quality_gate.sh)
SKIP_TESTS=true ./scripts/quality_gate.sh            # skip test runs
SKIP_CLIPPY=true ./scripts/quality_gate.sh           # skip Rust clippy
SKIP_GLOBAL_HOOKS_CHECK=true ./scripts/quality_gate.sh

# Minimal quality gate (fast path for CI debugging)
./scripts/minimal_quality_gate.sh
```

## Waiting for CI

The **2026-09-28** inspection of this template's branch ruleset recorded
`Codacy Static Code Analysis` as a required status check, bound to its app
integration. This contradicts the older no-required-status-check snapshot in
ADR-034/ADR-040-era guidance. It is not a permanent inventory: query live
rulesets (including inherited rules) and classic branch protection before
acting. Do not change or delete `.github/main-branch-protection.json` to resolve
a discrepancy; it is a snapshot and changing it does not change live protection.

Adopters must configure their own product-relevant required checks. Confirm
that a copied CI-status artifact's `workflow_url` names the intended repository,
then inspect the actual run and current head. A template artifact is advisory,
not proof of an adopter's CI or merge eligibility. See [CI Status Contract](CI_STATUS.md).

Codacy is posted by the Codacy GitHub App from a cloud analysis, **not** by a
GitHub Actions job, so it cannot be re-run from the Actions tab and does not
appear until the analysis finishes. Actions-only inspection is insufficient.

Measured latency from PR creation to check posted: **8–26 minutes**. Codacy scans
only changed files, and the check lands when the cloud analysis concludes. A PR
sitting `BLOCKED` with every *visible* check green is usually this, not a failure.

```bash
# Is the required check present yet?
REPO=$(gh repo view --json nameWithOwner --jq '.nameWithOwner')
DEFAULT_BRANCH=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
gh api --paginate "repos/$REPO/rules/branches/$DEFAULT_BRANCH"
gh pr checks <n> --repo "$REPO" --required

# Inspect check-runs on the current PR head, including names and app identities.
gh api --paginate "repos/$REPO/commits/<sha>/check-runs" \
  --jq '.check_runs[] | {name, status, conclusion, head_sha, app: .app.slug}'

# What does Codacy itself think? Reports the analysed head SHA.
codacy pull-request <n>
```

Procedure:

1. Verify source repository, current head, and live required checks. Missing or
   pending checks are not success, even if every visible Actions job is green.
2. If shipping is authorized, arm auto-merge (`gh pr merge <n> --squash --auto`)
   and let it wait for all live requirements. Poll through the observed
   **26-minute** latency window before treating absence alone as abnormal.
3. If Codacy reports the head as already analysed but no check-run exists, ask it
   to re-report — do not rewrite the branch:
   `codacy pull-request <n> --reanalyze`
4. If the live rules require an up-to-date branch,
   `strict_required_status_checks_policy: true` also reports `BEHIND`. With
   authorization, update the branch and recheck the new head's requirements.

Do not bypass Codacy or remove a valid required check just because it is slow
or conflicts with an old ADR. Investigate the live policy first; removing a
protection requires an explicit user decision, not an inference from a blocked PR.

Never `git commit --amend` to strip `[skip ci]` in order to coax the check out.
That was the original prescribed workaround in LESSON-046 and it is wrong — see
that entry, which also records why `[skip ci]` on a bot artifact PR head is
deliberate.

## Dependabot PRs

Dependabot PRs are auto-merged via CI when all checks pass. Do not manually merge or close Dependabot PRs.
