# Migration Guide

> Adopting this template in an existing project.

[![Template Version](https://img.shields.io/badge/version-0.2.1-blue)](VERSION)

## Overview

This guide helps you integrate AI agent support into an existing codebase incrementally. You can adopt features progressively - no need to do everything at once.

**Current Version:** 0.2.1 (2026-04-03)

## Adoption Levels

| Level | Description | Time |
|-------|-------------|------|
| **Level 1** | Basic AGENTS.md setup | 10 min |
| **Level 2** | Skills + Quality Gates | 30 min |
| **Level 3** | Sub-agents + Hooks | 1 hour |
| **Level 4** | Full harness optimization | 2+ hours |

---

## Level 1: Basic Setup (10 minutes)

### Step 1: Add AGENTS.md

Create `AGENTS.md` in your project root:

```markdown
# AGENTS.md

## Project Overview

[Brief description of your project]

## Setup

```bash
# Install dependencies
[Your install command]

# Run project
[Your run command]
```

## Code Style

[Your code style guidelines]
```

### Step 2: Create CLI-Specific Override (Optional)

For Claude Code, create `.claude/`:

```bash
mkdir -p .claude
echo '@AGENTS.md' > .claude/CLAUDE.md
```

### Step 3: Test

```bash
claude "What does this project do?"
```

**Done!** You now have basic AI agent support.

---

## Level 2: Skills + Quality Gates (30 minutes)

### Step 1: Add Scripts Directory

```bash
mkdir -p scripts
```

Copy these scripts from the template:
- `scripts/setup-skills.sh`
- `scripts/validate-skills.sh`
- `scripts/quality_gate.sh`
- `scripts/pre-commit-hook.sh`

### Step 2: Create Skills Directory

```bash
mkdir -p .agents/skills
```

Add at least one skill (copy from template or create your own):

```bash
# Example: Copy task-decomposition skill
mkdir -p .agents/skills/task-decomposition
# Add SKILL.md file
```

### Step 3: Create CLI Symlinks

```bash
mkdir -p .claude/skills
./scripts/setup-skills.sh
```

### Step 4: Install Pre-commit Hook

```bash
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Step 5: Customize Quality Gate

Edit `scripts/quality_gate.sh` to match your tech stack:

```bash
# Uncomment relevant section:
# - Rust: cargo fmt, clippy, test
# - TypeScript: pnpm lint, typecheck, test
# - Python: ruff, black, pytest
# - Go: gofmt, go vet, go test
```

### Step 6: Test

```bash
# Validate skills
./scripts/validate-skills.sh

# Run quality gate
./scripts/quality_gate.sh
```

**Done!** You now have skills and automated quality checks.

---

## Level 3: Sub-agents + Hooks (1 hour)

### Step 1: Create Sub-agents Directory

```bash
mkdir -p .claude/agents
```

### Step 2: Add Your First Sub-agent

Create `.claude/agents/code-reviewer.md`:

```markdown
---
name: code-reviewer
description: Review code for quality and standards. Invoke when conducting code reviews or pre-commit checks.
tools: Read, Grep, Glob
---

# Code Reviewer

You are a code review specialist...
```

### Step 3: Create Hooks Directory

```bash
mkdir -p .claude/hooks
```

### Step 4: Add Stop Hook

Create `.claude/hooks/stop.sh`:

```bash
#!/bin/bash
cd "$CLAUDE_PROJECT_DIR"

# Run typecheck + lint
OUTPUT=$(cargo check && cargo clippy -- -D warnings 2>&1)

if [ $? -ne 0 ]; then
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
```

### Step 5: Test

```bash
claude "Review the authentication module"
```

**Done!** You now have specialized sub-agents and automated hooks.

---

## Level 4: Full Harness Optimization (2+ hours)

### Step 1: Add Documentation

```bash
mkdir -p agents-docs
```

Add reference docs:
- `agents-docs/HARNESS.md` - Harness overview
- `agents-docs/SKILLS.md` - Skill authoring guide
- `agents-docs/SUB-AGENTS.md` - Sub-agent patterns
- `agents-docs/HOOKS.md` - Hook configuration
- `agents-docs/CONTEXT.md` - Context management

### Step 2: Expand Skills

Add more skills based on your workflow:
- `code-quality/` - Code review patterns
- `test-runner/` - Test execution
- `debug-troubleshoot/` - Debugging workflows
- `feature-implement/` - Feature implementation

### Step 3: Add More Sub-agents

Common sub-agents:
- `test-runner` - Execute tests
- `debugger` - Debug issues
- `refactorer` - Code improvement
- `documentation` - Write docs

### Step 4: Configure MCP Servers (Optional)

Create `.mcp.json`:

```json
{
  "mcpServers": {
    "your-server": {
      "url": "https://your-mcp-server.com/mcp"
    }
  }
}
```

### Step 5: Optimize Context Management

- Add `/clear` usage to AGENTS.md
- Configure progressive skill loading
- Set up context-efficient hooks

---

## Incremental Adoption Path

### Week 1: Foundation
- [ ] Add AGENTS.md
- [ ] Create basic folder structure
- [ ] Test with simple queries

### Week 2: Quality
- [ ] Add quality gate script
- [ ] Install pre-commit hook
- [ ] Customize for your stack

### Week 3: Skills
- [ ] Add 2-3 core skills
- [ ] Create symlinks
- [ ] Test skill activation

### Week 4: Agents
- [ ] Add first sub-agent
- [ ] Configure hooks
- [ ] Optimize workflows

---

## Migration Checklist

### Files to Add

| File | Required | Purpose |
|------|----------|---------|
| `AGENTS.md` | ✓ | Single source of truth |
| `scripts/setup-skills.sh` | ✓ | Create symlinks |
| `scripts/validate-skills.sh` | ✓ | Validate setup |
| `scripts/quality_gate.sh` | ✓ | Quality checks |
| `scripts/pre-commit-hook.sh` | ✓ | Git integration |
| `.agents/skills/` | Optional | Skill definitions |
| `.claude/agents/` | Optional | Sub-agents |
| `agents-docs/` | Optional | Reference docs |

### Configuration Updates

| Config | Update |
|--------|--------|
| `.gitignore` | Add `.env`, `*.log`, `node_modules/`, etc. |
| `package.json` / `Cargo.toml` / etc. | Add lint/test scripts |
| `.github/workflows/` | Add CI integration |

---

## Common Migration Scenarios

### Scenario 1: Existing Rust Project

```bash
# 1. Add AGENTS.md with Rust-specific config
# 2. Copy quality_gate.sh (uncomment Rust section)
# 3. Add rust-code-quality skill
# 4. Install pre-commit hook
# 5. Test: claude "Run cargo clippy"
```

### Scenario 2: Existing TypeScript Project

```bash
# 1. Add AGENTS.md with TypeScript config
# 2. Copy quality_gate.sh (uncomment TypeScript section)
# 3. Add typescript-quality skill
# 4. Configure pnpm scripts
# 5. Test: claude "Run the linter"
```

### Scenario 3: Existing Python Project

```bash
# 1. Add AGENTS.md with Python config
# 2. Copy quality_gate.sh (uncomment Python section)
# 3. Add python-quality skill
# 4. Install ruff, black, pytest
# 5. Test: claude "Run the tests"
```

### Scenario 4: Multi-language Monorepo

```bash
# 1. Add root AGENTS.md
# 2. Add per-package AGENTS.md files
# 3. Configure quality_gate.sh for all languages
# 4. Use nested AGENTS.md pattern
# 5. Test: claude "Analyze the project structure"
```

---

## Troubleshooting

### Issue: Skills Not Found

```
Error: No skills in .agents/skills/
```

**Solution:** Run `./scripts/setup-skills.sh`

### Issue: Quality Gate Always Fails

```
Error: cargo fmt failed
```

**Solution:** Run the formatter manually first: `cargo fmt`

### Issue: Agent Ignores AGENTS.md

**Solution:** Ensure file is at root level and starts with `# AGENTS.md`

### Issue: Symlinks Broken After Move

**Solution:** Re-run `./scripts/setup-skills.sh`

---

## Before and After Comparison

### Before

```
my-project/
├── src/
├── tests/
├── package.json
└── README.md
```

### After (Level 2)

```
my-project/
├── AGENTS.md              # ← New
├── src/
├── tests/
├── package.json
├── README.md
├── scripts/               # ← New
│   ├── setup-skills.sh
│   ├── validate-skills.sh
│   ├── quality_gate.sh
│   └── pre-commit-hook.sh
├── .agents/               # ← New
│   └── skills/
├── .claude/               # ← New
│   └── skills/ → ../.agents/skills/
└── .opencode/             # ← New (reads from .agents/skills/ directly)
    ├── agents/
    └── commands/
```

### After (Level 4)

```
my-project/
├── AGENTS.md
├── CLAUDE.md
├── src/
├── tests/
├── package.json
├── README.md
├── QUICKSTART.md          # ← New
├── scripts/
├── .agents/
│   └── skills/
├── .claude/
│   ├── agents/            # ← New
│   ├── commands/          # ← New
│   ├── hooks/             # ← New
│   └── skills/
├── .opencode/             # ← New (reads from .agents/skills/ directly)
│   ├── agents/
│   └── commands/
└── agents-docs/           # ← New
    ├── HARNESS.md
    ├── SKILLS.md
    ├── SUB-AGENTS.md
    ├── HOOKS.md
    └── CONTEXT.md
```

---

## Next Steps

After migration:

1. **Train your team** - Share QUICKSTART.md
2. **Iterate on AGENTS.md** - Add project-specific guidance
3. **Expand skills** - Add domain-specific knowledge
4. **Optimize hooks** - Fine-tune quality gates
5. **Monitor usage** - Track agent effectiveness

---

**Questions?** See [`README.md`](README.md) or [`QUICKSTART.md`](QUICKSTART.md).
