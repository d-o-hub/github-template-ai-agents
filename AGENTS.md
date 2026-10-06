# AGENTS.md

<!-- Agent-specific guidance: CLAUDE.md, GEMINI.md, QWEN.md -->

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
readonly MAX_PR_BODY_LENGTH=1000
```

## Process modes

**This repository uses Full (template maintainer) policy.** Downstream product
repositories should choose Minimal or Standard and rewrite this file for their stack.

| Profile | Default mode | Scope |
|---------|--------------|-------|
| **Minimal** (adopter) | **Light** | Product instructions, relevant checks, basic CI |
| **Standard** (adopter) | **Light** | Minimal + selected skills and agent workflows |
| **Full** (current repository) | **Full** | Template orchestration, generators, metrics/DORA, CI-status maintenance |

Light: understand → change → verify → report. Commit/PR steps apply only when
requested. Architectural changes still need a proportionate plan and decision
record; they do not require adopting the entire Full telemetry/automation stack.
See `agents-docs/ADOPTION_PROFILES.md` for downstream cleanup and optional packs.

## Planning & Delegation

- **Route:** retrieval (`delegate`) → planning (`goap-agent` when complex) → implementation (`implementer`) → verification (`test-runner` / `code-review-assistant`). Parallelize independent work, not dependent stages.
- Small fixes/docs: use a short plan and relevant checks; no new ADR or tests just for ceremony.
- Architecture, new subsystems, or broad refactors: use `triz-solver`, record the decision in a `plans/` ADR, obtain approval, then decompose with GOAP before implementation.
- Full: keep `plans/GOAP_STATE.md` current and capture reusable discoveries with `learn`.
- Check branch/upstream state before work; do not pull over local changes. Full CI-status is an advisory signal, not a merge gate: `passing` / `failing` / `unknown`; a required job that did not run is not proof of success. Confirm the actual run. Contract: `agents-docs/CI_STATUS.md`.
- Team/worktree patterns: `agents-docs/AGENT_TEAMS_GUIDE.md`.

## Behavioral Defaults

Act autonomously within the requested scope, but **do not commit, push, open/close
PRs or issues, or merge without user intent**. Fix introduced regressions; Full's
pre-existing-issue remediation policy is not a downstream Light default.
For requested GitHub triage, judge impact by adopter value, including consumed
metadata, catalogs, safety, and automation—not just product source changes.
Do not close consumed metadata updates as “no impact.” Details:
`agents-docs/BEHAVIORAL_DEFAULTS.md`.

## Setup

```bash
./scripts/bootstrap.sh # One-command setup: skills + hook + validate + quality gate
./scripts/doctor.sh    # Run anytime to diagnose environment issues
./bin/agent-toolkit    # Unified CLI: setup, doctor, quality, validate, analyze, fix, eval, docs
```

These are template commands, not inferred product install/test commands.
Bootstrap configures local git hooks; run it deliberately. Adopters replace CI
and local checks for their language and package manager. Session context uses
`./hooks/session-start.sh`, configured by `docflow.json` and tool settings.

## Version Management

Here `VERSION=0.0.0` is the consumer placeholder; template releases are recorded
in `.template/CHANGELOG-TEMPLATE.md`. Downstream `VERSION` is the product's
source of truth. The bump script does not reset it. See
`agents-docs/template-versioning/version-flow.md` before using release tooling.

## Quality Gate (Required Before Commit)

Use `static-analysis` to triage findings. Full maintainers run:

```bash
./scripts/quality_gate.sh # Required before an authorized commit
./scripts/update-all-docs.sh # Full-only generated documentation maintenance
```

Light adopters retain a product-relevant quality gate, not mandatory template
generators, metrics, or ADR-registration checks. Match verification to risk:
low-impact docs need inventory/link/Markdown checks, not new behavioral tests.
**Static validation ≠ behavioral proof.** Skill structure/schema/fixture checks
and `./scripts/run-evals.py` smoke runs do not invoke a model or prove skill
behavior. Report skipped checks and use representative behavioral evals when
claiming effectiveness. Full maintenance references: `agents-docs/SCRIPTS.md`.

**Guard rails:** Temporary files in `/tmp` only; no debug/report files in the
repository root. Gitleaks runs in CI. Respect task ownership and write boundaries.

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}`/file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must start with frontmatter and include **Rationalizations** and **Red Flags** sections.
- **No hardcoded values**: Use relative paths, runtime derivation, env vars, or named constants.
- Shell: `shellcheck` (severity=error); Markdown: `markdownlint`; Diagrams: `mermaid`
- **YAML workflows**: Put `# yamllint disable-line rule:truthy` on the `on:` line. CI yamllint: line-length 120, indentation 2 spaces.

## Repository Structure

- `agents-docs/`: Detailed reference; `.agents/skills/`: Canonical skills
- `llms.txt` & `llms-full.txt`: Machine-readable project context for LLMs
- `scripts/`: Setup/validation; `analysis/` & `reports/`: Generated outputs
- `.claude/`: Agent-specific symlinks (see `scripts/setup-skills.sh`)
- `plans/`: ADRs define decisions; progress updates track implementation status.

## PR & Commit Instructions

- Apply only to requested shipping work; never treat implementation as permission to publish.
- **MANDATORY (ADR-008)**: PR titles and commit headers follow `type(scope): subject`.
- PR Title: `type(scope): description` (max `${MAX_PR_TITLE_LENGTH}` chars)
- Commit Header: `type(scope): subject` (max `${MAX_COMMIT_SUBJECT_LENGTH}` chars total, lowercase)
- PR body: max `${MAX_PR_BODY_LENGTH}` chars; squash merges concatenate title/body. Wrap at 100 chars per line.
- Branch per feature; One concern per PR; Never commit to `main`.
- Inspect status/diff/history; stage only owned changes. Do not change git config, bypass hooks, rewrite history, or force-push without explicit authorization.

### Commit Type Mapping

| Intent                        | Type     | Scope suggestion |
|-------------------------------|----------|------------------|
| Security patch / hardening    | `fix`    | `security`       |
| New security feature/control  | `feat`   | `security`       |
| Security-related CI/tooling   | `ci`     | `security`       |

Before an authorized PR, check for existing overlapping work (`gh pr list` +
`gh pr diff --name-only`); prefer extending it over duplicates (ADR-035).
Use `git-github-workflow` for a requested end-to-end shipping task, not an
automatic commit/push/merge loop. Details: `agents-docs/WORKFLOW.md`.

## Skill Guidance

> **Authoring or updating a skill?** Load `skill-creator` for authoring and
> `skill-evaluator` for validation. Verdict must be `PASS` before merging.
> See `CONTRIBUTING.md → Creating or Updating Skills`. Use `.agents/skills/SKILL_TEMPLATE.md`.

- **Rules**: Review `## Rationalizations` and `## Red Flags` in skills before use.
- **Selection**: Load relevant skills progressively; optional packs are product choices, not all default-unlinked skills. See `agents-docs/ADOPTION_PROFILES.md`.
- **Inventory**: Keep the curated table below aligned with canonical skills when pruning; run all affected generators, not just symlink setup.

## Metrics & Post-Task Protocol

**Full only:** log tasks with `./scripts/log-metric.sh '<json>'` to
`.agents/metrics/metrics-{agent}.jsonl` (not legacy `.agents/metrics.jsonl`).
Respect scoped ownership; the coordinating agent handles shared post-task
bookkeeping. Schema/DORA: `agents-docs/METRICS.md`.
**Minimal/Standard Light:** metrics, DORA, and always-fix maintenance are optional;
do not inherit them or copied telemetry as product policy.

## Recovery & Advanced Topics

- **Local CI rehearsal with `act`**: `agents-docs/ACT.md` + `./scripts/run_act_local.sh` (never blocks the quality gate; opt-in).
- **Harness architecture**: `agents-docs/HARNESS.md`
- **Context engineering**: `agents-docs/CONTEXT.md`

## Skills

| Category | Skills |
|----------|--------|
| **Agent** | `agentic-abstention`, `delegate`, `implementer`, `intent-classifier`, `jules-delegator` |
| **Analysis** | `triz-solver` (solve + audit modes, TRIZ contradiction analysis) |
| **Code Quality** | `codacy`, `code-review-assistant`, `css-render-performance`, `debugger`, `iterative-refinement`, `migration-refactoring`, `shell-script-quality`, `static-analysis` |
| **Compliance** | `eu-ai-act-compliance` |
| **Database** | `database-devops`, `turso-db` |
| **DevOps** | `dependency-upgrades`, `dora-report` |
| **Documentation** | `agents-md`, `architecture-diagram`, `readme-best-practices` |
| **Knowledge** | `memory-context` |
| **Knowledge Management** | `learn` |
| **Platform** | `api-design-first`, `codeberg-api`, `durable-objects` |
| **Quality** | `avoid-ai-writing`, `dogfood`, `lifecycle-management`, `skill-creator`, `skill-evaluator`, `voice-profiles` |
| **Security** | `privacy-first`, `secrets-management`, `security-code-auditor` |
| **Testing** | `test-runner`, `testing-strategy` |
| **Tool** | `agent-browser`, `dist-channel-selection`, `do-web-doc-resolver`, `web-search-researcher` |
| **UI/UX** | `accessibility-auditor`, `ui-ux-optimize` |
| **Workflow** | `cicd-pipeline`, `cloudflare-worker-api`, `docs-hook`, `document-rendering-and-locators`, `git-github-workflow`, `goap-agent`, `progressive-delivery`, `pwa-offline-sync`, `reader-ui-ux`, `secure-invite-and-access` |
