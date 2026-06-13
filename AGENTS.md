# AGENTS.md

<!-- Agent-specific guidance: CLAUDE.md, GEMINI.md, QWEN.md, JULES.md -->

## Named Constants

```bash
# File size limits (lines)
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_PER_SKILL_MD=250
readonly MAX_LINES_AGENTS_MD=200

# Retry and polling configuration
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_DELAY_SECONDS=5
readonly DEFAULT_POLL_INTERVAL_SECONDS=5
readonly DEFAULT_MAX_POLL_ATTEMPTS=12
readonly DEFAULT_TIMEOUT_SECONDS=1800

# Git/PR configuration
readonly MAX_COMMIT_SUBJECT_LENGTH=150
readonly MAX_PR_TITLE_LENGTH=150
```

## Development Phases

We use a GOAP approach combined with ADRs and TRIZ for structured development.

**Prerequisites**:
- Fetch/pull latest default remote branch before beginning.
- **Check CI Status**: Agents MUST check `.github/ci-status/ci-status.json`. If NOT "passing", pause until fixed.

1. **ANALYZE & STRATEGIZE (Phase 1)**
   - **Action**: Use `triz-analysis` or `triz-solver`. Write an **ADR** in `plans/`.
   - **Human Gate**: Review and approve the ADR and analysis before proceeding. *Only human gate.*

2. **DECOMPOSE & PLAN (Phase 2)**
   - **Action**: Use the `goap-agent` to break down in `plans/GOAP_STATE.md`.

3. **EXECUTE & COORDINATE (Phase 3)**
   - **Action**: Execute tasks systematically using atomic commit workflow.
   - **Action**: Use `self-fix-loop` or equivalent until all CI checks pass.

4. **SYNTHESIZE (Phase 4)**
   - **Action**: Run `learn` skill to extract discoveries and update `AGENTS.md`.

## Setup

```bash
./scripts/bootstrap.sh # One-command setup: skills + hook + validate + quality gate
./scripts/doctor.sh    # Run anytime to diagnose environment issues
```

## Session Bootstrap

Agents use a `SessionStart` hook to auto-inject project context (docs map + latest changelog) at startup.
This is configured via `docflow.json` and agent-specific settings (e.g., `.claude/settings.json`).

```bash
./hooks/session-start.sh # Manual execution to verify context injection
```

## Version Management

**Single source of truth**: `VERSION` file at root. Never edit version strings elsewhere.

## Quality Gate (Required Before Commit)

Use the `static-analysis` skill to triage and fix any findings before committing.

```bash
./scripts/quality_gate.sh # Always run before committing. Fix all errors.
./scripts/update-all-docs.sh # Verify and update documentation
```

## Maintenance & Verification

```bash
./scripts/analyze-codebase.sh   # Autonomous analysis and self-learning
./scripts/check-adr-compliance.sh # Verify ADR registration and patterns
./scripts/run-evals.py --skill dora-report # Mandatory monthly report
./scripts/check-plan-numbering.sh # Ensure plan counters are consistent
./scripts/archive-stale-plans.sh # Archive plans older than 60 days
```

**Guard Rails:** Temporary files in `/tmp` only. Gitleaks enforced via CI. Pre-commit validates git config (`SKIP_GLOBAL_HOOKS_CHECK=true` to bypass).

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}`/file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must start with frontmatter and include **Rationalizations** and **Red Flags** sections.
- **No hardcoded values**: Use relative paths, runtime derivation, env vars, or named constants.
- Shell: `shellcheck` (severity=error); Markdown: `markdownlint`; Diagrams: `mermaid`
- **YAML Workflow Files**: All new `.github/workflows/*.yml` files must include `# yamllint disable-line rule:truthy` on the `on:` line (line 4) to suppress the PyYAML boolean interpretation warning. Example:

  ```yaml
  on:  # yamllint disable-line rule:truthy
    pull_request:
  ```

  CI yamllint uses strict rules (line-length: 120, indentation: 2 spaces).

## Repository Structure

- `agents-docs/`: Detailed reference; `.agents/skills/`: Canonical skills
- `llms.txt` & `llms-full.txt`: Machine-readable project context for LLMs
- `scripts/`: Setup/validation; `analysis/` & `reports/`: Generated outputs
- `.claude/`: Agent-specific symlinks (see `scripts/setup-skills.sh`)
- `plans/`: ADRs define decisions; progress updates track implementation status.

## PR & Commit Instructions

- **MANDATORY (ADR-008)**: PR titles MUST follow `type(scope): subject`.
- **Validation**: `echo "title" | npx commitlint --config commitlint.config.cjs` (or `gh pr edit`)
- PR Title: `type(scope): description` (max `${MAX_PR_TITLE_LENGTH}` chars)
- Commit Header: `type(scope): subject` (max `${MAX_COMMIT_SUBJECT_LENGTH}` chars total, lowercase)
- Commit Body: no hard limit (body-max-length disabled in commitlint; enforced at PR level as 1000 chars). Wrap at 100 chars per line. Footer: max 1000 chars.
- Branch per feature; One concern per PR; Never commit to `main`.

### Commit Type Mapping

| Intent                        | Type     | Scope suggestion |
|-------------------------------|----------|------------------|
| Security patch / hardening    | `fix`    | `security`       |
| New security feature/control  | `feat`   | `security`       |
| Security-related CI/tooling   | `ci`     | `security`       |

If `commitlint` fails, reword: `git commit --amend -m "<type>(<scope>): <subject>"` or use `git rebase -i`.

## Skill Guidance

> **Authoring or updating a skill?** Load `skill-creator` for authoring and
> `skill-evaluator` for validation. Verdict must be `PASS` before merging.
> See `CONTRIBUTING.md → Creating or Updating Skills`. Use `.agents/skills/SKILL_TEMPLATE.md`.

- **Rules**: Review `## Rationalizations` and `## Red Flags` in skills before use.
- **Plan**: Produce written plan, wait for confirmation for non-trivial tasks.
- **Policies**: See `agents-docs/WORKFLOW.md` for Atomic Commit & Issue resolution.
- **Learning**: After work, run `learn` or append discoveries to nearest `AGENTS.md`.

## Delegation Routing

- **Self-Execute**: 1 trivial isolated edit (e.g., typos, single-line constants).
- **Delegate**: 2+ files, architectural changes, or tasks requiring judgment.
- **Swarm**: 5+ similar independent tasks (e.g., batch doc normalization, multi-file refactors).
- **Route to**: `delegate` (retrieval/context) → `implementer` (execution) → `parallel-execution` (parallel batch).

## Metrics File

Append to `.agents/metrics.jsonl` after every task (see Post-Task Protocol).

- **Timestamp format**: `YYYY-MM-DDTHH:MM:SSZ` (UTC, no microseconds, no offset)
- **Merge conflicts**: `.gitattributes` sets `merge=union` — the CI bot auto-resolves
  positional conflicts. If you see conflict markers locally, run:
  `git fetch origin main && git merge origin/main`
- **Never sort or rewrite** the file; append-only, insertion order preserved.

## Post-Task Protocol

After **every** completed task, the agent MUST append a JSON entry to `.agents/metrics.jsonl`:

```json
{
  "timestamp": "YYYY-MM-DDTHH:MM:SSZ",
  "agent": "<agent-id>",
  "task": "<description>",
  "skill_used": "<skill or null>",
  "status": "completed" | "failed" | "partial",
  "tokens_used": <int>,
  "duration_seconds": <int>,
  "notes": "<text>"
}
```

- JSONL format; Append-only; Never truncate or delete.
- If task fails mid-way, still append with `"status": "failed"`.
- `dora-report` skill reads this file for its monthly summary.

#### Recent Project-Wide Learnings

- **act CI Simulation**: `act` requires Docker + act binary; if unavailable, skip local CI simulation and rely on `gh run list` for CI status (LESSON-026)
- **CI Status PR Auto-Detection**: Automated `ci-status-update` PRs are the monitoring system working as designed — fix the root CI failure, not the PR (LESSON-027)
- **Codacy SonarPython Suppression**: Codacy ignores `# NOSONAR`, `# noqa`, `# nosec` for S-prefixed rules; use constant extraction for literal patterns or `.codacy.yml` file exclusion (LESSON-028)
- **Bots Bypass Commit Conventions**: `google-labs-jules[bot]`, `dependabot[bot]`, and `github-copilot[bot]` produce prose-style commit subjects that fail commitlint. Layered defense: (1) `scripts/commit-msg-hook.sh` for local contributors, (2) `lint-pr-title` job in `commitlint.yml` to fail the PR title, (3) `normalize-commits.sh` rewriter for bot branches, (4) sentinel auto-fix with `chore(commit): normalize bot commits to conventional format`. See ADR-008 (LESSON-029)
- **wagoid/commitlint-github-action v6 Inputs**: v6 dropped `from`/`to` inputs and now infers the range from the PR/push event. Passing them produces `Unexpected input(s)` warnings. Use `commitDepth: 0` (push) or omit (PR) — see ADR-008 (LESSON-030)
- **Squash Merge Body-Length Failures**: Disable `body-max-length` in commitlint config (`[0]`) for repos using squash merges; GitHub concatenates PR title+body as the commit message, causing recurring failures on main. Enforce body length at PR level instead via a step in the commitlint workflow that fails if body >1000 chars (LESSON-031)
- **Automated PR Auto-Merge**: All workflows that create PRs (ci.yml, update-llms-txt.yml) MUST auto-merge with `gh pr merge --squash --admin --delete-branch=false` immediately after creation/reuse. Without auto-merge, automated PRs linger as open and require manual cleanup. Use `--admin` to bypass required status checks that would deadlock (LESSON-032)
- **BATS Subshell Variable Loss**: Piped `while read` loops run in subshells; variables modified inside are lost. Use heredoc `<<< "$var"` instead of `printf ... | while read` to keep the loop in the current shell (LESSON-033)
- **gh pr create Does Not Support --json**: `gh pr create` does not accept `--json`/`--jq` flags. To get the PR number after creation, capture the URL from stdout: `PR_URL=$(gh pr create ...) && PR_NUM=$(gh pr view "$PR_URL" --json number --jq '.number')`. This caused the CI + Labels Setup job to fail silently on main (LESSON-034)
- **Metrics JSONL Merge Conflicts**: Concurrent PRs often conflict on the tail of `.agents/metrics.jsonl`. Resolved via `merge=union` in `.gitattributes` and an automated CI rebase bot. See `agents-docs/runbooks/resolve-metrics-conflict.md` (LESSON-035)

## Self-Learning Rules

#### Integration Learnings

- **Optional Skills**: Implemented `SKILLS_OPTIONAL` in `setup-skills.sh` for opt-in knowledge.
- **Compliance Category**: Established "Compliance & Governance" for regulatory patterns.
