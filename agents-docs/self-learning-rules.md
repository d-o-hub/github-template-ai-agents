# Self-Learning Rules

> Centralized repository of project-wide learnings extracted from non-obvious discoveries.
>
> Managed by `scripts/analyze-codebase.sh` and the `learn` skill.
> `learn` writes here (project-wide) + scoped `AGENTS.md` files + `agents-docs/LESSONS.md`.

## Guidelines

- **Non-obvious only** — do not capture standard behavior or documented APIs.
- **Dual-write** — full LESSON-NNN entry in `agents-docs/LESSONS.md`, distilled note here.
- **Append-only** — add new entries at the bottom; never remove or reorder.

---

## Recent Project-Wide Learnings

- **LESSON-026 — act CI Simulation**: `act` requires Docker + act binary; if unavailable, skip local CI simulation and rely on `gh run list` for CI status.
- **LESSON-027 — CI Status PR Auto-Detection**: Automated `ci-status-update` PRs are the monitoring system working as designed — fix the root CI failure, not the PR.
- **LESSON-028 — Codacy SonarPython Suppression**: Codacy ignores `# NOSONAR`, `# noqa`, `# nosec` for S-prefixed rules; use constant extraction for literal patterns or `.codacy.yml` file exclusion.
- **LESSON-029 — Bots Bypass Commit Conventions**: `google-labs-jules[bot]`, `dependabot[bot]`, and `github-copilot[bot]` produce prose-style commit subjects that fail commitlint. Layered defense: (1) `scripts/commit-msg-hook.sh` for local contributors, (2) `lint-pr-title` job in `commitlint.yml` to fail the PR title, (3) `normalize-commits.sh` rewriter for bot branches, (4) sentinel auto-fix with `chore(commit): normalize bot commits to conventional format`. See ADR-008.
- **LESSON-030 — wagoid/commitlint-github-action v6 Inputs**: v6 dropped `from`/`to` inputs and now infers the range from the PR/push event. Passing them produces `Unexpected input(s)` warnings. Use `commitDepth: 0` (push) or omit (PR) — see ADR-008.
- **LESSON-031 — Squash Merge Body-Length Failures**: Disable `body-max-length` in commitlint config (`[0]`) for repos using squash merges; GitHub concatenates PR title+body as the commit message, causing recurring failures on main. Enforce body length at PR level instead via a step in the commitlint workflow that fails if body >1000 chars.
- **LESSON-032 — Automated PR Auto-Merge**: All workflows that create PRs (ci.yml, update-llms-txt.yml) MUST auto-merge with `gh pr merge --squash --admin --delete-branch=false` immediately after creation/reuse. Without auto-merge, automated PRs linger as open and require manual cleanup. Use `--admin` to bypass required status checks that would deadlock.
- **LESSON-033 — BATS Subshell Variable Loss**: Piped `while read` loops run in subshells; variables modified inside are lost. Use heredoc `<<< "$var"` instead of `printf ... | while read` to keep the loop in the current shell.
- **LESSON-034 — gh pr create Does Not Support --json**: `gh pr create` does not accept `--json`/`--jq` flags. To get the PR number after creation, capture the URL from stdout: `PR_URL=$(gh pr create ...) && PR_NUM=$(gh pr view "$PR_URL" --json number --jq '.number')`.
- **LESSON-035 — Metrics JSONL Merge Conflicts**: Concurrent PRs often conflict on the tail of `.agents/metrics.jsonl`. Resolved via `merge=union` in `.gitattributes` and an automated CI rebase bot. See `agents-docs/runbooks/resolve-metrics-conflict.md`.

---

## Integration Learnings

- **Optional Skills**: Implemented `SKILLS_OPTIONAL` in `setup-skills.sh` for opt-in knowledge.
- **Compliance Category**: Established "Compliance & Governance" for regulatory patterns.
