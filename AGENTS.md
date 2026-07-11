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
   - **Action**: Use `git-github-workflow` or run `./scripts/self-fix-loop.sh` until all CI checks pass.

4. **SYNTHESIZE (Phase 4)**
   - **Action**: Run `learn` skill to extract discoveries and update `AGENTS.md`.

## Behavioral Defaults

See `agents-docs/BEHAVIORAL_DEFAULTS.md` for automation-first, parallelism, direct action, diff-oriented, voice, and pre-existing issue handling rules.

## Setup

```bash
./scripts/bootstrap.sh # One-command setup: skills + hook + validate + quality gate
./scripts/doctor.sh    # Run anytime to diagnose environment issues
./bin/agent-toolkit    # Unified CLI: setup, doctor, quality, validate, analyze, fix, eval, docs
# Optional domain skill packs (Cloudflare, Turso, reader, compliance, …):
LINK_OPTIONAL=true ./scripts/setup-skills.sh
```

**Versions:** template release history is `.template/CHANGELOG-TEMPLATE.md` (README
badge in this repo). Project version is the root `VERSION` file (use that after
adopting the template).

## Session Bootstrap

Agents use a `SessionStart` hook to auto-inject project context (docs map + latest changelog) at startup; configured via `docflow.json` and agent-specific settings (e.g., `.claude/settings.json`).

```bash
./hooks/session-start.sh # Manual execution to verify context injection
```

## Version Management

**Single source of truth**: `VERSION` file at root. Never edit version strings elsewhere.

## Quality Gate (Required Before Commit)

Use the `static-analysis` skill to triage and fix any findings before committing. For `Codacy Static Code Analysis` CI failures, load the `codacy` skill (`.agents/skills/codacy/SKILL.md`); inspect with `codacy pull-request <N>`, re-trigger with `codacy repository --reanalyze-and-wait`. Drift policy: `agents-docs/codacy-triage-2026-06.md`.

```bash
./scripts/quality_gate.sh # Always run before committing. Fix all errors.
./scripts/update-all-docs.sh # Verify and update documentation
```

## Maintenance & Verification

```bash
./scripts/analyze-codebase.sh   # Autonomous analysis and self-learning
./scripts/check-adr-compliance.sh # Verify ADR registration and patterns
./scripts/run-evals.py --skill dora-report # Mandatory monthly report
```

**Guard Rails:** Temporary files in `/tmp` only. Never create debug, scripts, reports, or similar temporary files in the repository root. Gitleaks enforced via CI. Pre-commit validates git config (`SKIP_GLOBAL_HOOKS_CHECK=true` to bypass).

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}`/file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must start with frontmatter and include **Rationalizations** and **Red Flags** sections.
- **No hardcoded values**: Use relative paths, runtime derivation, env vars, or named constants.
- Shell: `shellcheck` (severity=error); Markdown: `markdownlint`; Diagrams: `mermaid`
- **YAML Workflow Files**: All new `.github/workflows/*.yml` files must include `# yamllint disable-line rule:truthy` on the `on:` line (line 4). CI yamllint uses strict rules (line-length: 120, indentation: 2 spaces).

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

- **Route to**: `delegate` (retrieval/context) → `implementer` (execution) → `agent-coordination` (swarm dispatch).
- **Parallel agents**: See `agents-docs/AGENT_TEAMS_GUIDE.md` for Agent Teams, Dynamic Workflows, and Worktrees.

## Metrics & Post-Task Protocol

See `agents-docs/METRICS.md` for metrics logging (`.agents/metrics.jsonl`), DORA reports, and post-task protocol.

## Recovery & Advanced Topics

- **Local CI rehearsal with `act`**: `agents-docs/ACT.md` + `./scripts/run_act_local.sh` (never blocks the quality gate; opt-in).
- **Harness architecture**: `agents-docs/HARNESS.md`
- **Context engineering**: `agents-docs/CONTEXT.md`

## Skills

| Category | Skills |
|----------|--------|
| **Agent** | `agentic-abstention`, `agent-coordination`, `delegate`, `implementer`, `intent-classifier`, `jules-delegator` |
| **Analysis** | `triz-analysis` |
| **Code Quality** | `codacy`, `code-review-assistant`, `css-render-performance`, `iterative-refinement`, `migration-refactoring`, `shell-script-quality`, `static-analysis` |
| **Compliance** | `eu-ai-act-compliance` |
| **Database** | `database-devops`, `turso-db` |
| **DevOps** | `dora-report` |
| **Documentation** | `agents-md`, `architecture-diagram`, `readme-best-practices` |
| **Innovation Problem Solving** | `triz-solver` |
| **Knowledge** | `memory-context` |
| **Knowledge Management** | `learn` |
| **Platform** | `api-design-first`, `codeberg-api`, `durable-objects` |
| **Quality** | `avoid-ai-writing`, `dogfood`, `lifecycle-management`, `skill-creator`, `skill-evaluator`, `testdata-builders`, `verification-template`, `voice-profiles` |
| **Security** | `privacy-first`, `security-code-auditor` |
| **Testing** | `test-runner`, `testing-strategy` |
| **Tool** | `agent-browser`, `dist-channel-selection`, `do-web-doc-resolver`, `template-version-management`, `web-search-researcher` |
| **UI/UX** | `accessibility-auditor`, `ui-ux-optimize` |
| **Workflow** | `cicd-pipeline`, `cloudflare-worker-api`, `docs-hook`, `document-rendering-and-locators`, `git-github-workflow`, `github-pr-sentinel`, `goap-agent`, `pwa-offline-sync`, `reader-ui-ux`, `secure-invite-and-access` |
