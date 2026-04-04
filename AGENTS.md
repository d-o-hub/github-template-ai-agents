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

## Project Overview

Production-ready template for AI agent-powered development.
Primary stack: Bash scripts, Markdown documentation, GitHub Actions CI/CD.

## Setup

```bash
# Create skill symlinks (run after clone)
./scripts/setup-skills.sh

# Install git pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Quality Gate (Required Before Commit)

```bash
./scripts/quality_gate.sh
```

**Always run before committing. Fix all errors.**

**Guard Rails:** The pre-commit hook validates git config to prevent global hooks from overriding local. If global hooks detected, run `git config --global --unset core.hooksPath` or use `SKIP_GLOBAL_HOOKS_CHECK=true git commit -m "..."` to skip.

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}` lines per source file; `${MAX_LINES_PER_SKILL_MD}` per `SKILL.md`; `${MAX_LINES_AGENTS_MD}` per `AGENTS.md`
- `SKILL.md` must start with frontmatter (`---` on line 1)
- **Reference format**: `` `reference/filename.md` - Description `` (no @ prefix, no markdown links)
- Conventional Commits: `feat:`, `fix:`, `docs:`, `ci:`, `test:`, `refactor:`
- Shell scripts: `shellcheck` for linting, `bats` for testing
- Markdown: `markdownlint` for consistency
- No magic numbers - use named constants; Use `mermaid` for diagrams

## Repository Structure

**Fixed Infrastructure** (Required, never changes):
```
<project-root>/
├── AGENTS.md              # Single source of truth (this file)
├── agents-docs/           # Detailed reference (loaded on demand)
├── .agents/skills/        # Canonical skill source
└── scripts/               # Setup, validation, quality gates
```

**Dynamic Folders** (Created as needed):
- `.claude/`, `.gemini/`, `.qwen/` - Agent-specific symlinks → `.agents/skills/`
- `<agent-name>.md` - Override files for specific agents

**Principle**: Document only fixed structure. Tool-specific folders follow the symlink pattern and are created by `./scripts/setup-skills.sh`.

## Testing

- Write/update tests for every change; Tests must be deterministic
- Success is silent; surface only failures. See `agents-docs/CONTEXT.md`

## PR Instructions

- Title: `[type(scope)] description` (max `${MAX_PR_TITLE_LENGTH}` chars)
- Create branch per feature - never commit to `main`; One concern per PR

## Security

- Never commit secrets/API keys - use `.env` (gitignored)
- Never connect to untrusted MCP servers; Report vulnerabilities via GitHub private advisories

## Agent Guidance

### Plan Before Executing
For non-trivial tasks: produce a written plan first, pause, wait for confirmation.

### Atomic Commit Policy (Optional / Customizable)
You MAY customize the atomic commit workflow for your project needs. The template provides documentation for this pattern at `.opencode/commands/atomic-commit.md` but implementation is left to individual projects.

**Example workflow pattern:**

```bash
# Create feature branch
git checkout -b feat/your-feature-name

# Make changes

# Run atomic commit (validates, commits, pushes, creates PR, verifies)
./scripts/atomic-commit/run.sh

# If checks fail, fix and retry
```

### Pre-Existing Issue Policy (REQUIRED)
**Fix ALL pre-existing issues before completing:**

- [ ] Lint warnings (shellcheck, markdownlint), Test failures, Security vulnerabilities
- [ ] Documentation gaps (broken links, missing files), Code style violations

**Process:**
1. Run quality gate: `./scripts/quality_gate.sh`
2. Note all failures (even unrelated to your changes)
3. Fix ALL issues
4. Re-run quality gate to confirm zero issues

### Context Discipline
- Delegate research to sub-agents; Use `/clear` between unrelated tasks
- Load skills only when needed; See `agents-docs/SKILLS.md` for skill framework

### Nested AGENTS.md
For monorepos, place additional `AGENTS.md` inside each sub-package. Nearest file takes precedence.

## Reference Docs

| Topic | File |
|---|---|
| Skill authoring | `agents-docs/SKILLS.md` |
| Sub-agent patterns | `agents-docs/SUB-AGENTS.md` |
| Context/back-pressure | `agents-docs/CONTEXT.md` |
| Architecture | `agents-docs/HARNESS.md` |
| Available skills | `agents-docs/AVAILABLE_SKILLS.md` |
| AGENTS.md authoring | `.agents/skills/agents-md/SKILL.md` |
| Configuration | `agents-docs/CONFIG.md` |
| Migration guide | `agents-docs/MIGRATION.md` |
