# AGENTS.md

> Single source of truth for all AI coding agents in this repository.

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

We use GOAP combined with ADRs and TRIZ for structured development.

**Prerequisites**:
- Fetch/pull latest default remote branch before beginning analysis.
- **Check CI Status**: Agents MUST check `ci-status.json`. If NOT "passing", pause until fixed.

1. **ANALYZE & STRATEGIZE (Phase 1)**: Use `triz-analysis` or `triz-solver`. Write an **ADR** in `plans/`.
2. **DECOMPOSE & PLAN (Phase 2)**: Use `goap-agent` to break down into tasks in `plans/GOAP_STATE.md`.
3. **EXECUTE & COORDINATE (Phase 3)**: Execute tasks systematically; use `self-fix-loop` for CI.
4. **SYNTHESIZE (Phase 4)**: Run `learn` skill to update project-specific `AGENTS.md`.

## ADR Status Convention

- **accepted**: Architectural decision defining an ongoing pattern.
- **complete**: Feature implementation with clear completion criteria.

## Setup

```bash
./scripts/setup-skills.sh # Create skill symlinks
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Version Management

**Single source of truth**: `VERSION` file at root. See `agents-docs/VERSION.md`.

## Quality Gate (Required Before Commit)

```bash
./scripts/quality_gate.sh # Fix all errors before committing
./scripts/update-all-docs.sh # Verify and update documentation
```

## CI State Artifacts

- `ci-status.json`: Machine-readable CI state file.
- `ci-summary.md`: Human/agent readable markdown summary.

## Maintenance & Verification

```bash
./scripts/analyze-codebase.sh   # Autonomous analysis and self-learning
./scripts/check-adr-compliance.sh # Verify ADR registration and patterns
./scripts/run-evals.py --skill dora-report # Mandatory monthly DORA + agentic report
./scripts/check-plan-numbering.sh # Ensure plan counters are consistent
./scripts/archive-stale-plans.sh # Archive plans older than 60 days
```

**Guard Rails:**
- **Temporary Files**: NEVER in root or source. Use `/tmp` or `mktemp`.
- **Secret Scanning**: Gitleaks enforced via CI.
- **Git Config**: Pre-commit validates git config. Use `SKIP_GLOBAL_HOOKS_CHECK=true` if needed.

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}`/source; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must have frontmatter, **Rationalizations**, and **Red Flags** sections.
- **No hardcoded values**: Use relative paths, environment variables, or named constants.
- Shell: `shellcheck` (error); Markdown: `markdownlint`; Diagrams: `mermaid`

## Repository Structure

- `agents-docs/`: Reference; `.agents/skills/`: Canonical skills; `scripts/`: Validation
- `plans/`: ADRs and implementation progress; `analysis/`: Generated outputs.

## PR & Commit Instructions

- PR Title: `type(scope): description` (max `${MAX_PR_TITLE_LENGTH}`)
- Commit Header: `type(scope): subject` (max `${MAX_COMMIT_SUBJECT_LENGTH}`, lowercase)
- Commit Body/Footer: max 1000 chars; wrap body at 100 chars/line
- Branch per feature; One concern per PR; Never commit to `main`

### Commit Workflow (Mandatory)

1. **Helper**: `./scripts/ai-commit.sh --type <type> --subject <subject> --body <body>`
2. **Manual**: Validated via `.githooks/commit-msg` (requires `./scripts/install-git-hooks.sh`)
3. **If Validation Fails**: Identify violation, then `git commit --amend` to fix.

### Commit Types

Allowed: `build` `chore` `ci` `docs` `feat` `fix` `perf` `refactor` `revert` `style` `test`
Security: `fix(security)` (patch), `feat(security)` (feature), `ci(security)` (tooling).

## Skills

See `agents-docs/skills-reference.md` for the full skill catalog (50+ skills).

## Security

- Gitleaks enforced via CI. No secrets in commits (use `.env`).
- Pin Actions to SHA (with `# vX.Y` comment). No untrusted MCPs.

## Agent Guidance

- **Rules**: Review `## Rationalizations` and `## Red Flags` in skills before use.
- **Plan**: Produce written plan; wait for confirmation for non-trivial tasks.
- **Policies**: See `agents-docs/WORKFLOW.md` for Atomic Commit & Issue resolution.
- **Learning**: After work, run `learn` or append discoveries to nearest `AGENTS.md`.
- **Context**: Delegate to sub-agents; Use `/clear`; Load skills only when needed.

## Post-Task Protocol

After **every** completed task, append a JSON entry to `.agents/metrics.jsonl`:

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

- JSONL format; Append-only; Never truncate.
- If task fails mid-way, still append with `"status": "failed"`.
- `dora-report` skill reads this file for its monthly summary.

#### Recent Project-Wide Learnings

- **Action SHA Pinning**: Pin to 40-char SHAs for security (LESSON-016)
- **Worktree Cleanup**: Use `trap cleanup EXIT ERR` and `CREATED_WORKTREES` (LESSON-010)

## Self-Learning Rules (Auto-Generated)

Updated by `./scripts/analyze-codebase.sh`. See `agents-docs/self-learning-rules.md`.

#### Integration Learnings

- **Optional Skills**: `SKILLS_OPTIONAL` in `setup-skills.sh` allows opt-in for specialized knowledge.
- **Compliance**: Established "Compliance & Governance" as a new skill category.
