# Quick Start Guide

> Get started with AI agent-powered development in 5 minutes.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Template Version](https://img.shields.io/badge/version-0.2.1-blue)](VERSION)

## Prerequisites

- Git installed
- One or more CLI coding agents:
  - [Claude Code](https://claude.ai/code) (recommended)
  - [Gemini CLI](https://github.com/google-gemini/gemini-cli)
  - [OpenCode](https://opencode.ai/)
  - [Qwen Code](https://github.com/QwenLM/Qwen-Coder)
  - Or any agent that supports the AGENTS.md format

## Platform-Specific Setup

### Windows (PowerShell / Git Bash)

On Windows, some commands differ from Unix/Linux. Here are the Windows equivalents:

**Using PowerShell:**
```powershell
# Clone repository
git clone https://github.com/your-org/your-project.git
cd your-project

# Create skill symlinks (requires Developer Mode or Admin)
# Run PowerShell as Administrator, or enable Developer Mode
./scripts/setup-skills.ps1

# Alternative: Use Git Bash which supports symlinks better
git clone -c core.symlinks=true https://github.com/your-org/your-project.git
```

**Using Git Bash (recommended):**
```bash
# Clone with symlinks enabled
git clone -c core.symlinks=true https://github.com/your-org/your-project.git
cd your-project

# Run setup script
./scripts/setup-skills.sh

# Install pre-commit hook (Git Bash uses Unix-style paths)
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Windows-specific notes:**
- Enable Developer Mode in Windows Settings (Settings → Update & Security → For Developers)
- Or run Git Bash as Administrator to create symlinks
- Alternative: Use WSL2 (Windows Subsystem for Linux) for full Linux compatibility

### macOS / Linux

Standard Unix commands work as documented below.

## Step 1: Use This Template

### Option A: GitHub UI

1. Click **"Use this template"** on GitHub
2. Enter your repository name
3. Click **"Create repository"**
4. Clone your new repository:

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
```

### Option B: CLI

```bash
git clone https://github.com/your-org/your-project.git
cd your-project
```

## Step 2: Setup (2 minutes)

### Unix / macOS / Linux

```bash
# Create skill symlinks for all CLI tools
./scripts/setup-skills.sh

# Install git pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

# Validate setup
./scripts/validate-skills.sh
```

### Windows (PowerShell as Administrator)

```powershell
# Create skill symlinks
./scripts/setup-skills.ps1

# Or manually copy files if symlinks fail
./scripts/setup-skills.sh --copy

# Validate setup
./scripts/validate-skills.sh
```

### Windows (WSL2) - Recommended

```bash
# Use WSL2 for full Linux compatibility
wsl

# Then follow Unix instructions above
cd /mnt/c/Users/YourName/your-project
./scripts/setup-skills.sh
```

Expected output:
```
✓ All skill validations passed
```

## Step 3: Configure for Your Project

Edit `AGENTS.md` to add your project details:

### 1. Update Project Overview

```markdown
## Project Overview

<!-- Replace this section -->
This is a [language] project that [does what].
Primary stack: [frameworks, libraries, tools]
```

### 2. Update Setup Commands

Replace the commands below with your project's actual setup steps:

**Node.js / TypeScript projects:**
```bash
# Install dependencies
pnpm install

# Start dev server
pnpm dev
```

**Rust projects:**
```bash
# Build the project
cargo build

# Run the application
cargo run
```

**Python projects:**
```bash
# Install dependencies (virtual environment recommended)
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run the application
python main.py
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

## Step 4: Test Your Setup

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

## Step 5: Start Coding

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
# Run quality gate manually
./scripts/quality_gate.sh

# Expected: All checks pass
```

## Next Steps

| Topic | Resource |
|-------|----------|
| Understanding skills | [`agents-docs/SKILLS.md`](agents-docs/SKILLS.md) |
| Creating sub-agents | [`agents-docs/SUB-AGENTS.md`](agents-docs/SUB-AGENTS.md) |
| Configuring hooks | [`agents-docs/HOOKS.md`](agents-docs/HOOKS.md) |
| Context management | [`agents-docs/CONTEXT.md`](agents-docs/CONTEXT.md) |
| Available agents | [`agents-docs/AGENTS_REGISTRY.md`](agents-docs/AGENTS_REGISTRY.md) |

## Troubleshooting

### Skills Not Found

```
Error: MISSING symlink: .claude/skills/task-decomposition
```

**Fix:** Run `./scripts/setup-skills.sh`

### Quality Gate Fails

```
Error: cargo fmt failed
```

**Fix:** Run `cargo fmt` to format code, then retry

### Agent Not Responding

**Fix:** Check agent installation:
- Claude Code: `claude --version`
- Gemini CLI: `gemini --version`
- OpenCode: `opencode --version`

## Common First Tasks

1. **Understand codebase**: "Summarize the project structure"
2. **Find files**: "Where is the authentication logic?"
3. **Add feature**: "Add input validation to the form"
4. **Fix bug**: "Fix the null pointer issue in handler.py"
5. **Write tests**: "Add tests for the user service"
6. **Refactor**: "Improve the code structure in module X"

---

**Need help?** See [`README.md`](README.md) for full documentation.
