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

We use a GOAP approach combined with ADRs and TRIZ for structured development.

**Prerequisites**:
- Fetch/pull latest default remote branch before beginning.
- **Check CI Status**: Agents MUST check `ci-status.json`. If NOT "passing", pause until fixed.

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
./scripts/setup-skills.sh # Create skill symlinks
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Version Management

**Single source of truth**: `VERSION` file at root. Never edit version strings elsewhere.

## Quality Gate (Required Before Commit)

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

## Repository Structure

- `agents-docs/`: Reference; `.agents/skills/`: Canonical skills; `scripts/`: Setup/validation.
- `llms.txt` & `llms-full.txt`: Machine-readable project context for LLMs
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

## Agent Guidance

- **Rules**: Review `## Rationalizations` and `## Red Flags` in skills before use.
- **Plan**: Produce written plan, wait for confirmation for non-trivial tasks.
- **Policies**: See `agents-docs/WORKFLOW.md` for Atomic Commit & Issue resolution.
- **Learning**: After work, run `learn` or append discoveries to nearest `AGENTS.md`.

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

- **Action SHA Pinning**: Pin to 40-char SHAs for security (LESSON-016)
- **Worktree Cleanup**: Use `trap cleanup EXIT ERR` and `CREATED_WORKTREES` (LESSON-010)

## Self-Learning Rules (Auto-Generated)

Updated by `./scripts/analyze-codebase.sh`. See `agents-docs/self-learning-rules.md`.

#### Integration Learnings

- **Optional Skills**: Implemented `SKILLS_OPTIONAL` in `setup-skills.sh` for opt-in knowledge.
- **Compliance Category**: Established "Compliance & Governance" for regulatory patterns.

