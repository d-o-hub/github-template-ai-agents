# AGENTS.md

> Single source of truth for all AI coding agents in this repository.
> Supported by: Claude Code, Windsurf, Gemini CLI, Codex, Copilot, OpenCode, Devin, Amp, Zed, Warp, RooCode, Jules or reference with @AGENTS.md in cli .md
> See the open spec: https://agents.md

## Project Overview

Production-ready template for AI agent-powered development with Claude Code, Gemini CLI, OpenCode, and more.
Primary stack: Bash scripts, Markdown documentation, GitHub Actions CI/CD.

## Setup

```bash
# Create skill symlinks after cloning (single source: .agents/skills/)
./scripts/setup-skills.sh

# Install git pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Run Tests

```bash
# Run quality gate (run before every commit)
./scripts/quality_gate.sh
```

Always run the full quality gate before committing. Fix all errors before finishing a task.

## Code Style

- **Max 500 lines per source file** - split into focused sub-modules if exceeded
- Conventional Commits: `feat:`, `fix:`, `docs:`, `ci:`, `test:`, `refactor:`
- All public APIs must be documented
- No hardcoded magic numbers - use named constants or config
- Render architecture diagrams as fenced ```mermaid``` blocks, never raw ASCII art
- Shell scripts: Use `shellcheck` for linting, `bats` for testing
- Markdown: Use `markdownlint` for consistency

## Repository Structure

```
<project-root>/
├── AGENTS.md              # This file - agent instructions (single source of truth)
├── CLAUDE.md              # Claude Code-specific overrides only (@AGENTS.md)
├── GEMINI.md              # Gemini CLI-specific overrides only (@AGENTS.md)
├── QWEN.md                # Qwen Code-specific overrides only (@AGENTS.md)
├── agents-docs/           # Detailed reference docs (loaded on demand, not by default)
│   ├── HARNESS.md         # MCP, skills, sub-agents, hooks overview
│   ├── SKILLS.md          # Skill authoring and progressive disclosure
│   ├── SUB-AGENTS.md      # Context isolation patterns
│   ├── HOOKS.md           # Hook configuration and verification
│   ├── CONTEXT.md         # Context engineering and back-pressure
│   ├── RUST.md            # Rust-specific patterns (remove if not Rust)
│   └── AGENTS_REGISTRY.md # Auto-generated registry of all sub-agents
├── .agents/
│   └── skills/            # CANONICAL skill source - all agents read from here
│       └── <skill-name>/
│           ├── SKILL.md   # <= 250 lines
│           ├── reference/ # Detailed docs linked from SKILL.md
│           ├── scripts/   # Executable scripts
│           └── assets/    # Templates, examples
├── .claude/
│   ├── agents/            # Claude Code sub-agent definitions
│   ├── commands/          # Custom slash commands
│   └── skills/            # Symlinks -> ../../.agents/skills/<name>
├── .opencode/
│   ├── agents/            # OpenCode-specific agents (real files, not symlinks)
│   └── commands/
├── .gemini/
│   └── skills/            # Symlinks -> ../../.agents/skills/<name>
├── .qwen/
│   └── skills/            # Symlinks -> ../../.agents/skills/<name>
├── scripts/
│   ├── setup-skills.sh    # Creates all symlinks (run on clone)
│   ├── validate-skills.sh # Validates all symlinks are intact
│   ├── quality_gate.sh    # Full pre-commit quality gate
│   ├── pre-commit-hook.sh # Git hook entry point
│   ├── gh-labels-creator.sh # GitHub label initialization
│   └── update-agents-registry.sh # Regenerates AGENTS_REGISTRY.md
├── README.md
└── .github/workflows/
```

## Testing Instructions

- Write or update tests for every code change, even if not explicitly requested
- Tests must be deterministic - use seeded RNG where randomness is needed
- Success is silent; only surface failures (context-efficient back-pressure)
- See `agents-docs/CONTEXT.md` for back-pressure patterns

## PR Instructions

- Title format: `[type(scope)] short description`
- Always run lint and tests before committing
- Create a new branch per feature/fix - never commit directly to `main`
- Keep PRs focused; one concern per PR

## Security

- Never commit secrets or API keys - use environment variables or `.env` (gitignored)
- Never connect to untrusted MCP servers - tool descriptions inject into the system prompt
- Report vulnerabilities via GitHub private advisories

## Agent Guidance

### Plan Before Executing
For non-trivial tasks: produce a written plan first, pause, and wait for confirmation
before writing code.

### Skills: Single Source in .agents/skills/
All skills live canonically in `.agents/skills/`. Claude Code and Gemini CLI use
symlinks pointing back to `.agents/skills/`. OpenCode reads skills directly from
`.agents/skills/` - no symlinks needed. Run `./scripts/setup-skills.sh` after
cloning to create symlinks for Claude Code and Gemini CLI. See `agents-docs/SKILLS.md`.

### Context Discipline
- Delegate isolated research and analysis to sub-agents
- Use `/clear` between unrelated tasks
- Load skills only when needed, not upfront

### Nested AGENTS.md
For monorepos, place an additional `AGENTS.md` inside each sub-package.
The agent reads the nearest file in the directory tree - closest one takes precedence.

### Reference Docs

| Topic | File |
|---|---|
| Harness engineering overview | `agents-docs/HARNESS.md` |
| Skill authoring | `agents-docs/SKILLS.md` |
| Sub-agent patterns | `agents-docs/SUB-AGENTS.md` |
| Hooks | `agents-docs/HOOKS.md` |
| Context / back-pressure | `agents-docs/CONTEXT.md` |
| Rust patterns | `agents-docs/RUST.md` |