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

**Guard Rails:**
- **Temporary Files**: NEVER in root or source. Use system temporary directories (e.g., `/tmp`).
- **Secret Scanning**: Gitleaks is enforced via CI only.
- **Git Config**: Pre-commit validates git config. Use `SKIP_GLOBAL_HOOKS_CHECK=true` if needed.

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

  CI yamllint uses strict rules (line-length: 120, indentation: 2 spaces). Use `# yamllint disable-line rule:truthy` on the `on:` line, and `# yamllint disable-next-line rule:line-length` for long lines that cannot be split.

## Repository Structure

- `agents-docs/`: Detailed reference; `.agents/skills/`: Canonical skills
- `llms.txt` & `llms-full.txt`: Machine-readable project context for LLMs
- `scripts/`: Setup/validation; `analysis/` & `reports/`: Generated outputs
- `.claude/`: Agent-specific symlinks (see `scripts/setup-skills.sh`)
- `plans/`: ADRs define decisions; progress updates track implementation status.

## PR & Commit Instructions

- PR Title: `type(scope): description` (max `${MAX_PR_TITLE_LENGTH}` chars)
- Commit Header: `type(scope): subject` (max `${MAX_COMMIT_SUBJECT_LENGTH}` chars total, lowercase)
- Commit Body: max 1000 chars; wrap at 100 chars per line. Footer: max 1000 chars.
- Branch per feature; One concern per PR; Never commit to `main`.

### Commit Type Mapping

| Intent                        | Type     | Scope suggestion |
|-------------------------------|----------|------------------|
| Security patch / hardening    | `fix`    | `security`       |
| New security feature/control  | `feat`   | `security`       |
| Security-related CI/tooling   | `ci`     | `security`       |

If `commitlint` fails, reword: `git commit --amend -m "<type>(<scope>): <subject>"` or use `git rebase -i`.

## Skill Guidance

- **Rules**: Review `## Rationalizations` and `## Red Flags` in skills before use.
- **Plan**: Produce written plan, wait for confirmation for non-trivial tasks.
- **Policies**: See `agents-docs/WORKFLOW.md` for Atomic Commit & Issue resolution.
- **Learning**: After work, run `learn` or append discoveries to nearest `AGENTS.md`.

## Delegation Routing

- **Self-Execute**: 1 trivial isolated edit (e.g., typos, single-line constants).
- **Delegate**: 2+ files, architectural changes, or tasks requiring judgment.
- **Swarm**: 5+ similar independent tasks (e.g., batch doc normalization, multi-file refactors).
- **Route to**: `delegate` (retrieval/context) → `implementer` (execution) → `parallel-execution` (parallel batch).

## Post-Task Protocol

After **every** completed task, the agent MUST append a JSON entry to `.agents/metrics.jsonl`:

```json
{
  "timestamp": "<ISO-8601>",
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

- **Dependabot Actor on Synchronize**: Use `github.event.pull_request.user.login` not `github.actor` for Dependabot auto-merge guards; on synchronize events, `github.actor` is the human who triggered the sync (LESSON-020)
- **CI Status File Staleness**: Verify CI via `gh run list` before trusting `.github/ci-status/ci-status.json`, which can be stale after direct pushes (LESSON-021)
- **Locale-Independent Sort**: Use `LC_ALL=C sort` for committed generator output to prevent CI drift (LESSON-018)
- **Nested node_modules**: Use `*/node_modules/*` in `find` to exclude at any depth, not just root (LESSON-019)
- **CI Symlink Dependency**: Always run `setup-skills.sh` before `validate-skills.sh` in CI workflows (LESSON-017)
- **Action SHA Pinning**: Pin to 40-char SHAs for security (LESSON-016)
- **Worktree Cleanup**: Use `trap cleanup EXIT ERR` and `CREATED_WORKTREES` (LESSON-010)
- **Dependabot Auto-Merge**: Use `enablePullRequestAutoMerge` (GraphQL) not `pulls.merge()` (REST); Dependabot's restricted token can't push branches, but GitHub native auto-merge uses system privileges for linear history + branch updates (LESSON-023)
- **Update CI Status on Dependabot**: Skip `update-ci-status` job with `github.actor != 'dependabot[bot]'` guard; Dependabot's read-only token causes git push failures that block auto-merge (LESSON-023)
- **ADR Compliance Gate**: The quality gate already runs `check-adr-compliance.sh` — no new gate needed. After creating an ADR in `plans/adr-*.md`, always register it in `plans/_status.json` entries and bump `nextAvailable.adr` (LESSON-024)
- **Markdown Test Fixtures**: BATS tests creating `.md` fixture files via `printf` must end with `\n` to pass markdownlint MD047/single-trailing-newline (LESSON-025)
- **act CI Simulation**: `act` requires Docker + act binary; if unavailable, skip local CI simulation and rely on `gh run list` for CI status (LESSON-026)
- **CI Status PR Auto-Detection**: Automated `ci-status-update` PRs are the monitoring system working as designed — fix the root CI failure, not the PR (LESSON-027)
- **Codacy SonarPython Suppression**: Codacy ignores `# NOSONAR`, `# noqa`, `# nosec` for S-prefixed rules; use constant extraction for literal patterns or `.codacy.yml` file exclusion (LESSON-028)
- **Bots Bypass Commit Conventions**: `google-labs-jules[bot]`, `dependabot[bot]`, and `github-copilot[bot]` produce prose-style commit subjects that fail commitlint. Layered defense: (1) `scripts/commit-msg-hook.sh` for local contributors, (2) `lint-pr-title` job in `commitlint.yml` to fail the PR title, (3) `normalize-commits.sh` rewriter for bot branches, (4) sentinel auto-fix with `chore(commit): normalize bot commits to conventional format`. See ADR-008 (LESSON-029)
- **wagoid/commitlint-github-action v6 Inputs**: v6 dropped `from`/`to` inputs and now infers the range from the PR/push event. Passing them produces `Unexpected input(s)` warnings. Use `commitDepth: 0` (push) or omit (PR) — see ADR-008 (LESSON-030)

## Self-Learning Rules (Auto-Generated)

Updated by `./scripts/analyze-codebase.sh`. See `agents-docs/self-learning-rules.md`.

#### Integration Learnings

- **Optional Skills**: Implemented `SKILLS_OPTIONAL` in `setup-skills.sh` for opt-in knowledge.
- **Compliance Category**: Established "Compliance & Governance" for regulatory patterns.
