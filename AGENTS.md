# AGENTS.md

> Single source of truth for all AI coding agents in this repository.
> Supported by: Claude Code, Windsurf, Gemini CLI, Codex, Copilot, OpenCode, Devin, Amp, Zed, Warp, RooCode, Jules
> See: https://agents.md

## Named Constants

```bash
# File size limits (lines)
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_PER_SKILL_MD=250
readonly MAX_LINES_AGENTS_MD=150

# Retry and polling configuration
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_DELAY_SECONDS=5
readonly DEFAULT_POLL_INTERVAL_SECONDS=5
readonly DEFAULT_MAX_POLL_ATTEMPTS=12
readonly DEFAULT_TIMEOUT_SECONDS=1800

# Git/PR configuration
readonly MAX_COMMIT_SUBJECT_LENGTH=72
readonly MAX_PR_TITLE_LENGTH=72

```

## Setup

```bash
./scripts/setup-skills.sh # Create skill symlinks
# Install custom git pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Version Management

**Single source of truth**: `VERSION` file at root. Never edit version strings elsewhere.
```bash
echo "0.3.0" > VERSION && git add VERSION && git commit -m "chore: bump version to 0.3.0"
```
See `agents-docs/VERSION.md` for full workflow details.

## Quality Gate (Required Before Commit)

```bash
./scripts/quality_gate.sh # Always run before committing. Fix all errors.
./scripts/update-all-docs.sh # Verify and update documentation
```
**Guard Rails:**
- **Temporary Files**: NEVER create temporary files or debug outputs in the repository root or source directories. Always use system temporary directories (e.g., `/tmp` or via `mktemp`).
- **Secret Scanning**: Gitleaks is enforced via CI only to prevent credential leakage.
- **Git Config**: Pre-commit validates git config. If global hooks detected, run `git config --global --unset core.hooksPath` or use `SKIP_GLOBAL_HOOKS_CHECK=true`.

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}` lines/file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must start with frontmatter; No magic numbers - use named constants
- **Reference format**: `` `references/filename.md` - Description ``
- Shell: `shellcheck` (severity=error); Markdown: `markdownlint`; Diagrams: `mermaid`



## PR & Commit Instructions

- Title/Commit: `type(scope): description` (max `${MAX_PR_TITLE_LENGTH}` chars)
- Branch per feature; One concern per PR; Never commit to `main`

### Commit Workflow (Mandatory)

1. **Use Helper (Preferred)**: Run `./scripts/ai-commit.sh --type <type> --subject <subject> --body <body>`
2. **Manual Commits**: Validated via `.githooks/commit-msg` (requires `./scripts/install-git-hooks.sh`)
3. **If Validation Fails**: Identify violation, then `git commit --amend` to fix message.



### Commit Type Mapping

| Intent                        | Type     | Scope suggestion |
|-------------------------------|----------|------------------|
| Security patch / hardening    | `fix`    | `security`       |
| New security feature/control  | `feat`   | `security`       |
| Security-related CI/tooling   | `ci`     | `security`       |



## Security

- **Secret Scanning**: Gitleaks is enforced via CI only to prevent credential leakage.
- No secrets in commits (use `.env`); Pin Actions to SHA (with `# vX.Y` comment)
- No untrusted MCPs; Report vulnerabilities via Private Advisories

## Agent Concepts and Memory

Agents working in this codebase share a common mental model for memory and learning:

- **Episode**: One unit of work an agent performs (e.g., a single task, PR review, or refactor).
- **Reward**: How the "goodness" of an episode is judged (e.g., tests passing, reduced complexity, user feedback).
- **Reflection**: A short written summary of what worked, what failed, and what should change next time.
- **Skill evolution**: Agents can update their own guidelines (in `agents-docs/`) when recurring patterns are discovered.

## Behavioral Expectations

All agents must adhere to the following behaviors:
- Always log what was done and why.
- Prefer small, reversible changes and attach a short reflection for risky changes.
- Use project state (plans/progress/docs) as context before acting, and update it afterwards. (See [Planning and Progress Surfaces](#planning-and-progress-surfaces)).

## Standard Cross-Agent Patterns

- **Planner → Worker → Reviewer**: This is the default multi-agent pattern. Work should be planned, executed, and then reviewed by separate roles or distinct phases.
- **Explicit Handoffs**: Pass work to another agent when specialized context is needed. Escalate to a human when blocked, unsure, or if changes touch restricted areas (e.g., secrets, infrastructure).

## Planning and Progress Surfaces

Each repository should maintain surfaces for agents to coordinate:
- **Planning Surface**: A place (like a `PLANS.md` or `plans/` folder) tracking high-level goals and pending tasks.
- **Progress Surface**: A place (like a `PROGRESS.md` or `progress/` folder) tracking completed work, state, and reflections.
- **Agent Duty**: Read from the planning surface before acting; append updates to the progress surface after acting.

## Memory & Concepts

- **Episode**: Agent work unit.
- **Reward**: Success metric.
- **Reflection**: Post-task summary.
- **Evolution**: Updating docs when patterns emerge.

## Behaviors

- Always log actions/reasons. Prefer small, reversible changes.
- Read `plans/`, update `progress/`. (Planner → Worker → Reviewer pattern).
- Escalate to human if blocked or touching secrets.

## Agent Guidance

- **Plan**: Produce written plan, wait for confirmation for non-trivial tasks.
- **Policies**: See `agents-docs/WORKFLOW.md` for Atomic Commit & Pre-Existing Issue resolution.
- **Learning**: After work, run `learn` or append discoveries to nearest `AGENTS.md`.
- **Context**: Delegate to sub-agents; Use `/clear`; Load skills only when needed.

#### Recent Project-Wide Learnings
- **Action SHA Pinning**: Pin to 40-char SHAs for security (LESSON-016)
- **Worktree Cleanup**: Use `trap cleanup EXIT ERR` and `CREATED_WORKTREES` (LESSON-010)

See `agents-docs/` for detailed reference documentation.
