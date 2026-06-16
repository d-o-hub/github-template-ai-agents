# Quick Start Guide

> Get started with AI agent-powered development in 5 minutes.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Prerequisites

- Git installed
- One or more CLI coding agents:
  - [Claude Code](https://claude.ai/code) (recommended)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli)
  - [OpenCode](https://opencode.ai/)
  - [Qwen Code](https://github.com/QwenLM/Qwen-Coder)
  - Or any agent that supports the AGENTS.md format

## Setup

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
./scripts/bootstrap.sh
```

**Expected output:**

```text
==> Checking environment
  ✓ git present and inside a repository
==> Setting up skills
  ✓ Skills ready
==> Installing pre-commit hook
  ✓ pre-commit hook installed
==> Validating skills
  ✓ Skills valid
==> Running quality gate
  ✓ Quality gate passed

Bootstrap complete. Repository is ready for AI agent workflows.
```

`bootstrap.sh` is idempotent — re-run it any time to repair the environment.

### Use this template on GitHub

If you are starting from scratch, click **"Use this template"** on GitHub before
cloning. The bootstrap step is the same.

## Configure for Your Project

Edit `AGENTS.md` to add your project details:

### 1. Update Project Overview

```markdown
## Project Overview

<!-- Replace this section -->
This is a [language] project that [does what].
Primary stack: [frameworks, libraries, tools]
```

### 2. Update Setup Commands

```markdown
## Setup

```bash
# Install dependencies
# TODO: Replace with your commands
pnpm install | cargo build | pip install -r requirements.txt

# Start dev server
# TODO: Replace with your commands
pnpm dev | cargo run | python main.py
```

```

### 3. Add Language-Specific Style

Uncomment and customize the relevant section:

```markdown
<!--
#### Rust
- Edition 2021, stable toolchain
- cargo fmt + cargo clippy -- -D warnings must pass
-->

<!--
#### TypeScript / JavaScript
- Strict mode, ESModules only, no implicit any
-->

<!--
#### Python
- Python 3.10+, async/await
- ruff + black; type hints on public functions
-->
```

## Test Your Setup

### With Claude Code

```bash
claude "Analyze this codebase and summarize its structure"
```

### With Gemini CLI

```bash
gemini "What are the main components of this project?"
```

### With OpenCode

```bash
opencode "Review the project structure"
```

## Start Coding

### Example: Implement a Feature

```bash
claude "Implement a function that validates user input"
```

The agent will:

1. Read relevant files
2. Implement the feature
3. Run quality gates automatically
4. Commit with proper message format

### Example: Fix a Bug

```bash
claude "Fix the bug in src/handler.py where null values cause crashes"
```

### Example: Refactor Code

```bash
claude "Refactor the authentication module to improve readability"
```

## Verify Everything Works

```bash
./scripts/quality_gate.sh
```

Expected: all checks pass.

### 4. Set Usage Policies & Eval Tracking

For production-grade repositories, copy and customize the policy templates:

```bash
cp templates/USE_RESTRICTIONS.md ./USE_RESTRICTIONS.md
cp templates/EVALS.md ./EVALS.md
```

- Edit `USE_RESTRICTIONS.md` to define what agents are allowed to do.
- Use `EVALS.md` to track performance and quality improvements over time.

## Troubleshooting

If bootstrap fails or the quality gate reports unexpected errors, run the doctor:

```bash
./scripts/doctor.sh
```

The doctor checks:

- Required tools (`git`, `bash`)
- Optional quality tools (`markdownlint-cli2`, `shellcheck`, `yamllint`)
- Git repository state
- Symlink support (critical on Windows)
- `.agents/skills` directory and expected symlinks
- Pre-commit hook installation
- Core file presence (`AGENTS.md`, `QUICKSTART.md`)

Share its output when filing a bug report.

### Common issues

| Symptom | Likely cause | Fix |
|---|---|---|
| Symlink errors during bootstrap | Windows without Developer Mode | Run inside WSL2 or enable Developer Mode |
| `pre-commit: command not found` after commit | Hook installed, tool missing | `pip install pre-commit` or `brew install pre-commit` |
| Skills validation fails | Symlinks not created | Re-run `./scripts/bootstrap.sh` |
| Quality gate fails on fresh clone | Missing optional tools | Run `./scripts/doctor.sh` to identify gaps |

### Per-agent verification

If the agent does not respond, check installation:

- Claude Code: `claude --version`
- Gemini CLI: `gemini --version`
- OpenCode: `opencode --version`
- Qwen Code: `qwen --version`

## Convention

| Command | Purpose |
|---|---|
| `./scripts/bootstrap.sh` | First-time setup (idempotent) |
| `./scripts/doctor.sh` | Environment diagnostics |
| `./scripts/quality_gate.sh` | Local quality enforcement |
| `./scripts/validate-skills.sh` | Low-level skill check (called by bootstrap) |
| `./scripts/setup-skills.sh` | Low-level symlink setup (called by bootstrap) |

## Next Steps

| Topic | Resource |
|-------|----------|
| Understanding skills | [`agents-docs/SKILLS.md`](agents-docs/SKILLS.md) |
| Creating sub-agents | [`agents-docs/SUB-AGENTS.md`](agents-docs/SUB-AGENTS.md) |
| Configuring hooks | [`agents-docs/HOOKS.md`](agents-docs/HOOKS.md) |
| Context management | [`agents-docs/CONTEXT.md`](agents-docs/CONTEXT.md) |
| Available agents | [`agents-docs/AGENTS_REGISTRY.md`](agents-docs/AGENTS_REGISTRY.md) |
| Evaluation Tracking | [`templates/EVALS.md`](templates/EVALS.md) |
| Usage Restrictions | [`templates/USE_RESTRICTIONS.md`](templates/USE_RESTRICTIONS.md) |
| Adopting in existing repo | [`agents-docs/MIGRATION.md`](agents-docs/MIGRATION.md) |

## Common First Tasks

1. **Understand codebase**: "Summarize the project structure"
2. **Find files**: "Where is the authentication logic?"
3. **Add feature**: "Add input validation to the form"
4. **Fix bug**: "Fix the null pointer issue in handler.py"
5. **Write tests**: "Add tests for the user service"
6. **Refactor**: "Improve the code structure in module X"

---

**Need help?** See [`README.md`](README.md) for full documentation.
