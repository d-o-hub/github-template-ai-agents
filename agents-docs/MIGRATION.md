# Migration Guide

> Step-by-step guide for adopting the AI agent template in existing projects.

---

## Overview

This template provides a **unified harness for AI coding agents** that enables consistent, high-quality AI-assisted development across multiple CLI tools.

### What This Template Provides

| Component | Purpose | Benefit |
|-----------|---------|---------|
| **AGENTS.md** | Single source of truth for all AI agents | Consistent instructions across Claude, Gemini, OpenCode, etc. |
| **Skills System** | Reusable knowledge modules in `.agents/skills/` | Domain-specific expertise on demand |
| **Quality Gates** | Automated lint, test, format before commits | Prevents bad code from entering codebase |
| **Sub-Agents** | Specialized agent definitions for specific tasks | Context isolation and parallel execution |
| **Hooks** | Pre/post tool execution scripts | Custom validation and automation |
| **Scripts** | Setup, validation, and maintenance utilities | One-command project maintenance |

### Supported AI Agents

- [Claude Code](https://claude.ai/code)
- [Gemini CLI](https://github.com/google-gemini/gemini-cli)
- [OpenCode](https://opencode.ai/)
- [Qwen Code](https://github.com/QwenLM/Qwen-Coder)
- Windsurf, Cursor, Copilot Chat

---

## Prerequisites

Before starting migration, ensure you have:

| Requirement | Version | Purpose |
|-------------|---------|---------|
| **Git** | 2.30+ | Version control and hook installation |
| **Bash** | 4.0+ | Script execution |
| **One AI CLI tool** | Latest | Primary agent for testing |

### Optional but Recommended

| Tool | Purpose |
|------|---------|
| `shellcheck` | Bash script validation |
| `bats` | Bash testing framework |
| `markdownlint` | Markdown consistency |

### Verify Prerequisites

```bash
# Check Git
git --version  # Should show 2.30+

# Check Bash
bash --version  # Should show 4.0+

# Check AI CLI (example: Claude Code)
claude --version
```

---

## Step-by-Step Migration Process

### Step 1: Backup Existing Project

Before making any changes, create a backup:

```bash
# Option A: Create a backup branch
cd /path/to/your-project
git checkout -b backup/pre-ai-agents
git push -u origin backup/pre-ai-agents
git checkout main  # or your default branch

# Option B: Create a local archive
cd /path/to/parent-dir
cp -r your-project your-project-backup-$(date +%Y%m%d)
```

### Step 2: Copy Template Files

Download the template files to a temporary location:

```bash
# Option A: Clone the template repository
git clone https://github.com/d-o-hub/github-template-ai-agents.git /tmp/ai-agent-template

# Option B: Download as zip
curl -L -o /tmp/ai-agent-template.zip https://github.com/d-o-hub/github-template-ai-agents/archive/main.zip
unzip /tmp/ai-agent-template.zip -d /tmp/ai-agent-template
```

Copy the essential files to your project:

```bash
# Create directory structure
mkdir -p your-project/.agents/skills
mkdir -p your-project/.claude/skills

# Copy the ENTIRE scripts tree (including scripts/lib/) — quality_gate.sh and
# validate-skills.sh depend on shared libraries and helper validators; copying
# individual scripts yields a broken gate.
cp -r /tmp/ai-agent-template/scripts your-project/scripts

# Copy version-controlled hooks and validation configs
cp -r /tmp/ai-agent-template/.githooks your-project/.githooks
cp /tmp/ai-agent-template/.shellcheckrc your-project/ 2>/dev/null || true
cp /tmp/ai-agent-template/markdownlint.toml your-project/ 2>/dev/null || true

# Make scripts executable
chmod +x your-project/scripts/*.sh
```

### Step 3: Create AGENTS.md

Create the main instruction file at your project root:

```bash
cat > your-project/AGENTS.md << 'EOF'
# AGENTS.md

> Single source of truth for all AI coding agents in this repository.

## Project Overview

[Replace with: Brief description of your project]
[Replace with: Primary language and framework]
[Replace with: Key architectural decisions]

## Setup

```bash
# Install dependencies
[Replace with: your install command - e.g., npm install, cargo build, pip install -r requirements.txt]

# Run the project
[Replace with: your run command - e.g., npm start, cargo run, python main.py]
```

## Code Style

- [Replace with: your style guidelines]
- [Replace with: linting rules]
- [Replace with: testing requirements]

## Testing

```bash
# Run all tests
[Replace with: your test command]
```

## Agent Guidance

### Plan Before Executing

For non-trivial tasks: produce a written plan first, pause, and wait for confirmation
before writing code.

### Context Discipline

- Delegate isolated research and analysis to sub-agents
- Use `/clear` between unrelated tasks
- Load skills only when needed, not upfront
EOF

```

### Step 4: Setup Skills

Copy default skills from the template:

```bash
# Copy example skills (select based on your needs)
cp -r /tmp/ai-agent-template/.agents/skills/goap-agent your-project/.agents/skills/
cp -r /tmp/ai-agent-template/.agents/skills/shell-script-quality your-project/.agents/skills/

# Copy skill rules
cp /tmp/ai-agent-template/.agents/skills/skill-rules.json your-project/.agents/skills/
```

Create symlinks for CLI tools:

```bash
cd your-project
./scripts/setup-skills.sh
```

Verify the setup:

```bash
./scripts/validate-skills.sh
```

Expected output:

```
✓ All skill symlinks intact
✓ SKILL.md files valid
```

### Step 5: Configure Agents

#### 5.1 Create CLI-Specific Override Files

For Claude Code:

```bash
mkdir -p your-project/.claude
cat > your-project/.claude/CLAUDE.md << 'EOF'
@AGENTS.md

# Claude-Specific Overrides

## Additional Context

- Claude Code is the primary agent for this project
- Use `claude` command for all AI-assisted tasks
EOF
```

For Gemini CLI:

```bash
mkdir -p your-project/.gemini
cat > your-project/.gemini/GEMINI.md << 'EOF'
@AGENTS.md

# Gemini-Specific Overrides

## Additional Context

- Gemini CLI is the secondary agent for this project
- Use `gemini` command for research tasks
EOF

# Create commands directory (Gemini CLI uses TOML schema)
mkdir -p your-project/.gemini/commands
```

#### 5.2 Install Pre-Commit Hook

Use the version-controlled `.githooks` directory (matches `bootstrap.sh`);
do not write into `.git/hooks/` directly:

```bash
cd your-project
git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true
```

#### 5.3 Customize Quality Gate

`quality_gate.sh` auto-detects your stack from project files (`Cargo.toml`,
`package.json`, `requirements.txt`/`pyproject.toml`, `go.mod`) — there are no
commented language sections to uncomment. Supported skip flags:

```bash
SKIP_TESTS=true ./scripts/quality_gate.sh             # skip test runs
SKIP_CLIPPY=true ./scripts/quality_gate.sh            # skip Rust clippy
SKIP_GLOBAL_HOOKS_CHECK=true ./scripts/quality_gate.sh
```

> Note: Python and Go are currently *detected* but do not yet run ecosystem
> checks, and Rust tests run `cargo test --lib` only. See
> `plans/adr-032-template-audit-remediation.md` for planned work.

### Step 6: Update Documentation

#### 6.1 Update README.md

Add a section about AI agent support:

```markdown
## AI Agent Development

This project supports AI-assisted development with Claude Code, Gemini CLI, and OpenCode.

### Quick Start

\`\`\`bash
# Setup skills
./scripts/setup-skills.sh

# Run quality gate
./scripts/quality_gate.sh
\`\`\`

### Available Commands

\`\`\`bash
# Analyze codebase
claude "Analyze this codebase"

# Implement feature
claude "Implement user authentication"

# Review code
claude "Review the changes in src/"
\`\`\`

See [AGENTS.md](../AGENTS.md) for detailed instructions.
```

#### 6.2 Create MIGRATION.md (Optional)

If your project will have other contributors migrate to this setup:

```bash
# Document your migration process for future reference
cat > your-project/MIGRATION_NOTES.md << 'EOF'
# Migration Notes

Migration completed on: $(date +%Y-%m-%d)
Template version: <copy from your-project/VERSION>  # VERSION is the single source of truth

## Changes Made

- Added AGENTS.md with project-specific instructions
- Added .agents/skills/ with [list skills]
- Added scripts/ for quality gates and setup
- Configured pre-commit hooks

## Customizations

- Quality gate configured for: [language/framework]
- Custom skills added: [if any]
- Additional agents configured: [Claude/Gemini/etc.]
EOF
```

### Step 7: Test the Setup

Run the quality gate:

```bash
cd your-project
./scripts/quality_gate.sh
```

Test with an AI agent:

```bash
# With Claude Code
claude "Analyze this codebase and summarize its structure"

# With Gemini CLI
gemini "What are the main components of this project?"

# With OpenCode
opencode "Review the project structure"
```

### Step 8: Commit Changes

```bash
cd your-project
git add .
git commit -m "feat(tooling): integrate AI agent template

- Add AGENTS.md for unified agent instructions
- Add .agents/skills/ for reusable knowledge
- Add scripts/ for quality gates and setup
- Configure pre-commit hooks
- Update README with AI agent documentation"
```

---

## Common Migration Scenarios

### Scenario 1: Existing Python Project

```bash
# 1. Backup
git checkout -b backup/pre-ai-agents

# 2. Copy template files
cp -r /tmp/ai-agent-template/.agents/skills/goap-agent .agents/skills/
cp -r /tmp/ai-agent-template/scripts scripts/

# 3. Customize AGENTS.md
cat >> AGENTS.md << 'EOF'

## Python-Specific Guidelines

- Python 3.10+ required
- Use ruff for linting: ruff check .
- Use black for formatting: black .
- Type hints required on public functions
- pytest for testing with coverage >= 80%
EOF

# 4. Quality gate auto-detects Python — no edits needed

# 5. Setup
./scripts/setup-skills.sh
./scripts/quality_gate.sh

# 6. Test
claude "Run the tests and check coverage"
```

### Scenario 2: Existing TypeScript/JavaScript Project

```bash
# 1. Backup
git checkout -b backup/pre-ai-agents

# 2. Copy template files
cp -r /tmp/ai-agent-template/.agents/skills/goap-agent .agents/skills/
cp -r /tmp/ai-agent-template/.agents/skills/iterative-refinement .agents/skills/
cp -r /tmp/ai-agent-template/scripts scripts/

# 3. Customize AGENTS.md
cat >> AGENTS.md << 'EOF'

## TypeScript-Specific Guidelines

- Strict mode enabled, no implicit any
- ESModules only, no CommonJS
- pnpm as package manager
- ESLint + Prettier for formatting
- Vitest for testing
EOF

# 4. Quality gate auto-detects TypeScript — no edits needed

# 5. Setup
./scripts/setup-skills.sh
./scripts/quality_gate.sh

# 6. Test
claude "Check for TypeScript errors"
```

### Scenario 3: Existing Rust Project

```bash
# 1. Backup
git checkout -b backup/pre-ai-agents

# 2. Copy template files
cp -r /tmp/ai-agent-template/.agents/skills/goap-agent .agents/skills/
cp -r /tmp/ai-agent-template/.agents/skills/iterative-refinement .agents/skills/
cp -r /tmp/ai-agent-template/scripts scripts/

# 3. Customize AGENTS.md
cat >> AGENTS.md << 'EOF'

## Rust-Specific Guidelines

- Edition 2021, stable toolchain
- cargo fmt + cargo clippy -- -D warnings must pass
- cargo test for testing
- Documentation required for public APIs
EOF

# 4. Quality gate auto-detects Rust — no edits needed

# 5. Setup
./scripts/setup-skills.sh
./scripts/quality_gate.sh

# 6. Test
claude "Run cargo clippy and fix any warnings"
```

### Scenario 4: Multi-Language Monorepo

```bash
# 1. Backup
git checkout -b backup/pre-ai-agents

# 2. Copy template files to root
cp -r /tmp/ai-agent-template/.agents/skills/goap-agent .agents/skills/
cp -r /tmp/ai-agent-template/scripts scripts/

# 3. Create root AGENTS.md with monorepo structure
cat > AGENTS.md << 'EOF'
# AGENTS.md

## Project Overview

Multi-language monorepo with packages in:
- packages/frontend (TypeScript/React)
- packages/backend (Python/FastAPI)
- packages/shared (Rust)

## Setup

```bash
# Install all dependencies
pnpm install  # root dependencies
pnpm -r install  # workspace packages
cd packages/backend && pip install -r requirements.txt
cd packages/shared && cargo build
```

## Nested AGENTS.md

Each package has its own AGENTS.md for package-specific instructions:
- packages/frontend/AGENTS.md
- packages/backend/AGENTS.md
- packages/shared/AGENTS.md

## Code Style

### Global

- Conventional commits required
- PRs must pass quality gate

### Frontend (TypeScript)

- Strict mode, ESModules
- pnpm lint, pnpm typecheck

### Backend (Python)

- ruff + black
- pytest with coverage

### Shared (Rust)

- cargo fmt + cargo clippy
EOF

# 4. Create per-package AGENTS.md files

for pkg in packages/frontend packages/backend packages/shared; do
  cat > "$pkg/AGENTS.md" << EOF

# AGENTS.md for $pkg

@../../AGENTS.md

## Package-Specific Instructions

[Add package-specific guidance here]
EOF
done

# 5. Customize quality_gate.sh for all languages

# Edit scripts/quality_gate.sh to include all language checks

# 6. Setup

./scripts/setup-skills.sh
./scripts/quality_gate.sh

```

### Scenario 5: Minimal Setup (Documentation Only)

For projects that only need basic AI agent support:

```bash
# 1. Just create AGENTS.md
cat > AGENTS.md << 'EOF'
# AGENTS.md

## Project Overview

[Brief description]

## Setup

```bash
[Install command]
```

## Code Style

[Basic guidelines]
EOF

# 2. Test

claude "What does this project do?"

```

---

## Troubleshooting

### Issue: Skills Not Found

**Symptom:**
```

Error: No skills in .agents/skills/

```

**Solution:**
```bash
# Create the skills directory
mkdir -p .agents/skills

# Add at least one skill
cp -r /tmp/ai-agent-template/.agents/skills/goap-agent .agents/skills/

# Re-run setup
./scripts/setup-skills.sh
```

### Issue: Broken Symlinks After Move

**Symptom:**

```
Error: MISSING symlink: .claude/skills/goap-agent
```

**Solution:**

```bash
# Re-create all symlinks
./scripts/setup-skills.sh

# Validate
./scripts/validate-skills.sh
```

### Issue: Quality Gate Always Fails

**Symptom:**

```
Error: cargo fmt failed
```

**Solution:**

```bash
# Run the formatter manually first
cargo fmt  # for Rust
black .    # for Python
pnpm lint --fix  # for TypeScript

# Then re-run quality gate
./scripts/quality_gate.sh
```

### Issue: Agent Ignores AGENTS.md

**Symptom:**
Agent doesn't follow instructions from AGENTS.md

**Solution:**
1. Ensure file is at project root: `ls AGENTS.md`
2. Ensure file starts with `# AGENTS.md` header
3. Check file is not in `.gitignore`
4. For Claude Code: ensure `.claude/CLAUDE.md` contains `@AGENTS.md`

### Issue: Pre-Commit Hook Not Running

**Symptom:**
Git commits without running quality gate

**Solution:**

```bash
# Confirm Git uses the version-controlled hooks dir
git config core.hooksPath        # expect .githooks

# Ensure hooks are executable
chmod +x .githooks/* 2>/dev/null || true

# Check hook content
cat .githooks/pre-commit
```

### Issue: Permission Denied on Scripts

**Symptom:**

```
bash: ./scripts/setup-skills.sh: Permission denied
```

**Solution:**

```bash
chmod +x scripts/*.sh
```

> Note: `setup-skills.sh` no longer requires `realpath` — it implements its own
> portable relative-path resolution, so no coreutils installation is needed on macOS.

### Issue: Agent Can't Read Skills

**Symptom:**

```
Error: Skill not accessible
```

**Solution:**
1. Check symlinks exist: `ls -la .claude/skills/`
2. Verify target exists: `ls .agents/skills/`
3. For OpenCode: ensure it reads from `.agents/skills/` directly (no symlinks needed)

---

## Before and After

### Before Migration

```
my-project/
├── src/
├── tests/
├── package.json
└── README.md
```

### After Migration (Basic)

```
my-project/
├── AGENTS.md              # New: Agent instructions
├── src/
├── tests/
├── package.json
├── README.md
└── .githooks/
    └── pre-commit         # New: Quality gate hook
```

### After Migration (Full)

```
my-project/
├── AGENTS.md              # New
├── CLAUDE.md              # New: Claude overrides
├── src/
├── tests/
├── package.json
├── README.md
├── scripts/               # New
│   ├── setup-skills.sh
│   ├── validate-skills.sh
│   ├── quality_gate.sh
│   └── pre-commit-hook.sh
├── .agents/               # New
│   └── skills/
│       ├── goap-agent/
│       └── shell-script-quality/
├── .claude/               # New
│   └── skills/ → ../.agents/skills/
└── .githooks/
    └── pre-commit
```

---

## Next Steps

After migration:

1. **Train Your Team**: Share this guide and [QUICKSTART.md](../QUICKSTART.md)
2. **Customize AGENTS.md**: Add project-specific patterns and conventions
3. **Add More Skills**: Copy additional skills from the template as needed
4. **Create Sub-Agents**: Define specialized agents for common tasks
5. **Monitor Usage**: Track which AI agents and skills are most effective

---

## Resources

| Resource | Purpose |
|----------|---------|
| [README.md](../README.md) | Template overview |
| [QUICKSTART.md](../QUICKSTART.md) | 5-minute setup guide |
| [AGENTS.md](../AGENTS.md) | Agent instruction format |
| [SKILLS.md](SKILLS.md) | Skill authoring guide |
| [SUB-AGENTS.md](SUB-AGENTS.md) | Sub-agent patterns |
| [HOOKS.md](HOOKS.md) | Hook configuration |

---

**Need Help?** Open an issue on [GitHub](https://github.com/d-o-hub/github-template-ai-agents/issues).
