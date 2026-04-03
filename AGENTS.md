# AGENTS.md

> Single source of truth for all AI coding agents in this repository.
> Supported by: Claude Code, Windsurf, Gemini CLI, Codex, Copilot, OpenCode, Devin, Amp, Zed, Warp, RooCode, Jules or reference with @AGENTS.md in cli .md
> See the open spec: https://agents.md

## Named Constants

```bash
# File size limits (lines)
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_PER_SKILL_MD=250

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

# Validate skill format
./scripts/validate-skill-format.sh
```

Always run the full quality gate before committing. Fix all errors before finishing a task.

## Code Style

- **Max `${MAX_LINES_PER_SOURCE_FILE}` lines per source file** - split into focused sub-modules if exceeded
- **Max `${MAX_LINES_PER_SKILL_MD}` lines per SKILL.md** - move detailed content to `references/` folder
- **SKILL.md must start with frontmatter** (--- on line 1, no content before)
- **Required frontmatter fields**: `name`, `description`
- **Recommended frontmatter fields**: `license`
- Conventional Commits: `feat:`, `fix:`, `docs:`, `ci:`, `test:`, `refactor:`
- All public APIs must be documented
- **No hardcoded magic numbers** - use named constants (see Named Constants section above) or config
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
│           ├── SKILL.md   # <= ${MAX_LINES_PER_SKILL_MD} lines, frontmatter required
│           ├── evals/     # Test cases (evals.json)
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
│   ├── validate-skill-format.sh # Validates SKILL.md format
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

- Title format: `[type(scope)] short description` (max `${MAX_PR_TITLE_LENGTH}` chars)
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

### Available Skills

| Skill | Description | Category |
|-------|-------------|----------|
| `accessibility-auditor` | Audit web applications for WCAG 2.2 compliance, screen reade | Security |
| `agent-coordination` | Coordinate multiple agents for software development across a | Coordination |
| `anti-ai-slop` | Apply this skill whenever the user wants to audit, fix, rede | UI/UX |
| `api-design-first` | Design and document RESTful APIs using design-first principl | APIDevelopment |
| `architecture-diagram` | Generate or update a project architecture SVG diagram by sca | Documentation |
| `cicd-pipeline` | Design and implement CI/CD pipelines with GitHub Actions, Gi | DevOps |
| `code-review-assistant` | Automated code review with PR analysis, change summaries, an | General |
| `codeberg-api` | - Interact with Forgejo/Codeberg repositories via the REST A | DevOps |
| `database-devops` | Database design, migration, and DevOps automation with safet | DevOps |
| `do-web-doc-resolver` | Python resolver for URLs and queries into compact, LLM-ready | Research |
| `docs-hook` | Lightweight git hook integration for updating agents-docs wi | Documentation |
| `github-readme` | Create human-focused GitHub README.md files with 2026 best p | Documentation |
| `goap-agent` | Invoke for complex multi-step tasks requiring intelligent pl | Coordination |
| `intent-classifier` | Classify user intents and route to appropriate skills, comma | Coordination |
| `iterative-refinement` | Execute iterative refinement workflows with validation loops | Quality |
| `migration-refactoring` | Automate complex code migrations and refactorings with safet | Migration |
| `parallel-execution` | Execute multiple independent tasks simultaneously using para | Coordination |
| `privacy-first` | Prevent email addresses and personal data from entering the | Security |
| `security-code-auditor` | Perform security audits on code to identify vulnerabilities, | Security |
| `shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS. Use w | CodeQuality |
| `skill-creator` | Create new skills, modify and improve existing skills, and m | Meta |
| `skill-evaluator` | "Reusable skill for evaluating other skills with structure c | Meta |
| `task-decomposition` | Break down complex tasks into atomic, actionable goals with | Planning |
| `testing-strategy` | Design comprehensive testing strategies with modern techniqu | Quality |
| `triz-solver` | Systematic problem-solving using TRIZ (Theory of Inventive P | Innovation |
| `ui-ux-optimize` | Swarm-powered UI/UX prompt optimizer with auto-research agen | UI/UX |
| `web-search-researcher` | Research topics using web search to find accurate, current i | Research |

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
| Docs hook skill | `.agents/skills/docs-hook/SKILL.md` |