# github-template-ai-agents

> **A production-ready template for AI agent-powered development**  
> Supports: Claude Code, Gemini CLI, OpenCode, Windsurf, Cursor, Copilot Chat, and more

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Template Version](https://img.shields.io/badge/version-0.1.0-blue)](VERSION)

A comprehensive template repository for building AI agent-powered software projects. Provides a unified harness for multiple CLI coding agents with progressive disclosure, context isolation, and quality gates.

## ✨ Features

### Multi-Agent Support
| Agent | Status | Config |
|-------|--------|--------|
| **Claude Code** | ✅ Full support | `.claude/` |
| **Gemini CLI** | ✅ Full support | `.gemini/` |
| **OpenCode** | ✅ Full support | `.opencode/` |
| **Windsurf** | 🔶 Symlinks ready | `.windsurf/` |
| **Cursor** | 🔶 Symlinks ready | `.cursor/` |
| **Copilot Chat** | 🔶 Via MCP | `.copilot/` |

### Core Capabilities

- **📚 Skills System** - Progressive disclosure with canonical source in `.agents/skills/`
- **🤖 Sub-Agent Patterns** - Context isolation for complex multi-step tasks
- **🔗 MCP Integration** - Model Context Protocol support for tools and resources
- **✅ Quality Gates** - Automated validation before commits (lint, test, format)
- **🪝 Lifecycle Hooks** - Stop hooks, pre-tool approval, post-tool notifications
- **📊 Context Engineering** - Back-pressure mechanisms to prevent context rot
- **🔄 Iterative Refinement** - Loop patterns for progressive improvement

## 🚀 Quick Start

### 1. Use This Template

```bash
# Click "Use this template" on GitHub, or clone directly
git clone https://github.com/your-org/your-project.git
cd your-project
```

### 2. Setup (5 minutes)

```bash
# Create skill symlinks for all CLI tools
./scripts/setup-skills.sh

# Install git pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit

# Validate setup
./scripts/validate-skills.sh
```

### 3. Configure for Your Project

Edit `AGENTS.md` to add:
- Project overview (replace TODO section)
- Your tech stack setup commands
- Language-specific code style rules
- Project-specific quality gates

### 4. Start Coding with AI

```bash
# Claude Code
claude "Implement feature X"

# Gemini CLI
gemini "Refactor module Y"

# OpenCode
opencode "Fix bug in Z"
```

## 📁 Repository Structure

```
your-project/
├── AGENTS.md                 # Single source of truth for all agents
├── CLAUDE.md                 # Claude Code overrides (references AGENTS.md)
├── GEMINI.md                 # Gemini CLI overrides (references AGENTS.md)
├── opencode.json             # OpenCode configuration
├── README.md                 # This file
├── VERSION                   # Semantic version of template
├──
├── .agents/
│   └── skills/               # CANONICAL skill source (all agents read here)
│       ├── task-decomposition/
│       ├── code-quality/
│       ├── test-runner/
│       └── ...
├──
├── .claude/
│   ├── agents/               # Claude Code sub-agents
│   ├── commands/             # Custom slash commands
│   └── skills/               # Symlinks → ../../.agents/skills/
├── .gemini/
│   └── skills/               # Symlinks → ../../.agents/skills/
├── .opencode/
│   ├── agent/                # Symlinks → ../../.agents/skills/
│   └── command/
├──
├── agents-docs/              # Detailed reference docs (loaded on demand)
│   ├── HARNESS.md            # MCP, skills, sub-agents overview
│   ├── SKILLS.md             # Skill authoring guide
│   ├── SUB-AGENTS.md         # Context isolation patterns
│   ├── HOOKS.md              # Hook configuration
│   └── CONTEXT.md            # Context engineering & back-pressure
├──
├── scripts/
│   ├── setup-skills.sh       # Creates symlinks (run on clone)
│   ├── validate-skills.sh    # Validates symlinks + SKILL.md files
│   ├── quality_gate.sh       # Full quality gate (auto-detects language)
│   ├── pre-commit-hook.sh    # Git hook entry point
│   └── gh-labels-creator.sh  # Initialize GitHub labels
└──
└── .github/workflows/
    ├── ci-and-labels.yml     # CI pipeline + label initialization
    └── yaml-lint.yml         # YAML validation
```

## 🎯 Available Skills

Generic skills included in this template:

| Skill | Description | When to Use |
|-------|-------------|-------------|
| `task-decomposition` | Break complex tasks into atomic goals | Multi-step projects |
| `code-quality` | Code review and quality checks | Before commits, PRs |
| `test-runner` | Execute and manage tests | Validation loops |
| `shell-script-quality` | Lint/test shell scripts (ShellCheck + BATS) | Bash/sh development |
| `parallel-execution` | Coordinate parallel agent execution | Independent subtasks |
| `iterative-refinement` | Progressive improvement loops | Quality refinement |
| `agent-coordination` | Multi-agent orchestration | Complex workflows |
| `goap-agent` | Goal-oriented action planning | Intelligent task decomposition |
| `web-search-researcher` | Web research and synthesis | Documentation lookup |

### Adding Skills

```bash
# 1. Create skill folder in canonical location
mkdir -p .agents/skills/your-skill

# 2. Add SKILL.md (≤250 lines)
# 3. Run setup to create symlinks
./scripts/setup-skills.sh
```

See `agents-docs/SKILLS.md` for detailed authoring guide.

## 🤖 Available Sub-Agents

Sub-agents provide isolated context for complex tasks:

| Agent | Purpose | Tools | Model |
|-------|---------|-------|-------|
| `goap-agent` | Complex planning & coordination | Task, Read, Glob, Grep | sonnet |
| `loop-agent` | Iterative refinement workflows | Task, Read, TodoWrite | sonnet |
| `analysis-swarm` | Multi-perspective code analysis | Read, Grep, Glob | opus |
| `agent-creator` | Scaffold new sub-agent definitions | Write, Read, Glob | sonnet |

See `.claude/agents/` for full definitions.

## 🔧 Quality Gates

The template includes automatic quality validation:

### Auto-Detected Languages

| Language | Detection | Checks |
|----------|-----------|--------|
| **Rust** | `Cargo.toml` | fmt, clippy, test, audit |
| **TypeScript** | `package.json` | lint, typecheck, test |
| **Python** | `requirements.txt`, `pyproject.toml` | ruff, black, pytest |
| **Go** | `go.mod` | fmt, vet, test |
| **Shell** | `*.sh` files | shellcheck, bats |

### Running Quality Gates

```bash
# Manual run
./scripts/quality_gate.sh

# Pre-commit (automatic)
git commit -m "feat: add feature"
# → Runs quality_gate.sh automatically
```

### Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All checks passed (silent) |
| `2` | Errors surfaced to agent (remediate before commit) |

## 🪝 Hooks

Hooks enforce deterministic control flow:

### Stop Hook (Example)

```bash
#!/bin/bash
# .claude/hooks/stop.sh
cd "$CLAUDE_PROJECT_DIR"

# Run typecheck + lint
OUTPUT=$(cargo check && cargo clippy -- -D warnings 2>&1)

if [ $? -ne 0 ]; then
  echo "$OUTPUT" >&2
  exit 2  # Surface errors to agent
fi

# Success: exit 0 silently
exit 0
```

### Hook Types

| Type | Trigger | Use Case |
|------|---------|----------|
| **Stop Hook** | Agent stops | Typecheck, lint, format |
| **Pre-Tool** | Before tool call | Approve/deny destructive ops |
| **Post-Tool** | After tool call | Notifications, PR creation |

See `agents-docs/HOOKS.md` for configuration.

## 📚 Documentation

| Doc | Description |
|-----|-------------|
| [`AGENTS.md`](AGENTS.md) | Main agent instructions (single source of truth) |
| [`agents-docs/HARNESS.md`](agents-docs/HARNESS.md) | Harness engineering overview |
| [`agents-docs/SKILLS.md`](agents-docs/SKILLS.md) | Skill authoring guide |
| [`agents-docs/SUB-AGENTS.md`](agents-docs/SUB-AGENTS.md) | Context isolation patterns |
| [`agents-docs/HOOKS.md`](agents-docs/HOOKS.md) | Hook configuration |
| [`agents-docs/CONTEXT.md`](agents-docs/CONTEXT.md) | Context engineering & back-pressure |
| [`QUICKSTART.md`](QUICKSTART.md) | 5-minute setup guide |
| [`MIGRATION.md`](MIGRATION.md) | Adopting in existing projects |

## 🏷️ GitHub Labels

This template includes automatic label initialization:

```bash
# Run once to create standard labels
./scripts/gh-labels-creator.sh
```

Standard labels:
- `priority: critical`, `priority: high`, `priority: medium`, `priority: low`
- `type: feat`, `type: fix`, `type: docs`, `type: refactor`, `type: test`, `type: chore`
- `status: blocked`, `status: in-progress`, `status: review`, `status: done`

## 🔒 Security

- **No secrets in repo** - Use environment variables or `.env` (gitignored)
- **MCP server trust** - Only connect trusted servers (tool descriptions inject into system prompt)
- **Report vulnerabilities** - Use GitHub private security advisories

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`feature/your-feature`)
3. Write descriptive commit messages (Conventional Commits)
4. Ensure quality gates pass
5. Submit a pull request

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for details.

## 📄 License

MIT License - see [`LICENSE`](LICENSE) for details.

## 🙏 Acknowledgments

This template incorporates patterns from:
- [rust-self-learning-memory](https://github.com/d-o-hub/rust-self-learning-memory) - Episodic memory, GOAP patterns, quality gates
- [web-doc-resolver](https://github.com/d-oit/web-doc-resolver) - Cascade resolution, progressive disclosure

---

**Built with AI agents. Maintained by humans.**
