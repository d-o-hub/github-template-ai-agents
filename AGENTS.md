# AGENTS.md

> Single source of truth for all AI coding agents in this repository.
> Supported by: Claude Code, Windsurf, Gemini CLI, Codex, Copilot, OpenCode, Devin, Amp, Zed, Warp, RooCode, Jules or reference with @AGENTS.md in cli .md
> See the open spec: https://agents.md

## Project Overview

<!-- TODO: Replace with 2-3 sentences describing this project, its purpose, and primary tech stack. -->
This is a generic template repository. Replace this section with your project overview.

## Setup

```bash
# Install dependencies
# TODO: pnpm install | cargo build | pip install -r requirements.txt

# Start dev server / run project
# TODO: pnpm dev | cargo run | python main.py

# Create skill symlinks after cloning (single source: .agents/skills/)
./scripts/setup-skills.sh

# Install git pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Run Tests

```bash
# Unit tests
# TODO: cargo test --lib | pnpm test:unit | pytest tests/unit

# Integration tests
# TODO: cargo test --test '*' | pnpm test:integration | pytest tests/integration

# Full quality gate (run before every commit)
./scripts/quality_gate.sh
```

Always run the full quality gate before committing. Fix all errors before finishing a task.

## Code Style

- **Max 500 lines per source file** - split into focused sub-modules if exceeded
- Conventional Commits: `feat:`, `fix:`, `docs:`, `ci:`, `test:`, `refactor:`
- All public APIs must be documented
- No hardcoded magic numbers - use named constants or config
- Render architecture diagrams as fenced ```mermaid``` blocks, never raw ASCII art

<!-- TODO: Uncomment the language block(s) relevant to your project -->

<!--
#### Rust
- Edition 2021, stable toolchain; `cargo fmt` + `cargo clippy -- -D warnings` must pass
- Errors via `thiserror`; propagation via `anyhow` or `?`
- Async I/O via Tokio; CPU parallelism via Rayon
- All fallible public APIs return `Result<T, Error>`
- See agents-docs/RUST.md for patterns and anti-patterns
-->

<!--
#### TypeScript / JavaScript
- Strict mode; ESModules only; no implicit `any`
- Functional patterns preferred; single quotes, no semicolons
-->

<!--
#### Python
- Python 3.10+, async/await; `ruff` + `black`; type hints on all public functions
-->

## Repository Structure

```
<project-root>/
├── AGENTS.md              # This file - agent instructions (single source of truth)
├── CLAUDE.md              # Claude Code-specific overrides only (@AGENTS.md)
├── GEMINI.md              # Gemini CLI-specific overrides only (@AGENTS.md)
├── agents-docs/           # Detailed reference docs (loaded on demand, not by default)
│   ├── HARNESS.md         # MCP, skills, sub-agents, hooks overview
│   ├── SKILLS.md          # Skill authoring and progressive disclosure
│   ├── SUB-AGENTS.md      # Context isolation patterns
│   ├── HOOKS.md           # Hook configuration and verification
│   ├── CONTEXT.md         # Context engineering and back-pressure
│   └── RUST.md            # Rust-specific patterns (remove if not Rust)
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
├── scripts/
│   ├── setup-skills.sh    # Creates all symlinks (run on clone)
│   ├── validate-skills.sh # Validates all symlinks are intact
│   ├── quality_gate.sh    # Full pre-commit quality gate
│   └── pre-commit-hook.sh # Git hook entry point
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