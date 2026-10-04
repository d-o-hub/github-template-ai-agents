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

`Codacy Static Code Analysis` is the branch ruleset's one required status check
(plus `Codacy Static Code Analysis`'s app integration). It is posted by the Codacy
GitHub App from a cloud analysis, **not** by a GitHub Actions job, so it cannot be
re-run from the Actions tab and does not appear until the analysis finishes.

Measured latency from PR creation to check posted: **8–26 minutes**. Codacy scans
only changed files, and the check lands when the cloud analysis concludes. A PR
sitting `BLOCKED` with every *visible* check green is usually this, not a failure.

```bash
# Is the required check present yet?
gh pr checks <n>

# Has Codacy reported for this head?
gh api repos/:owner/:repo/commits/<sha>/check-runs \
  --jq '[.check_runs[]|select(.name=="Codacy Static Code Analysis")]|length'

# What does Codacy itself think? Reports the analysed head SHA.
codacy pull-request <n>
```

Procedure:

1. Arm auto-merge (`gh pr merge <n> --squash --auto`) and let it wait. It merges
   when the required check passes.
2. Poll for **at least 25 minutes** before treating the absence as abnormal.
3. If Codacy reports the head as already analysed but no check-run exists, ask it
   to re-report — do not rewrite the branch:
   `codacy pull-request <n> --reanalyze`
4. `strict_required_status_checks_policy: true` also reports `BEHIND`, which
   refuses a merge on its own. Update the branch before diagnosing anything else.

Never `git commit --amend` to strip `[skip ci]` in order to coax the check out.
That was the original prescribed workaround in LESSON-046 and it is wrong — see
that entry, which also records why `[skip ci]` on a bot artifact PR head is
deliberate.

## Dependabot PRs

Dependabot PRs are auto-merged via CI when all checks pass. Do not manually merge or close Dependabot PRs.
