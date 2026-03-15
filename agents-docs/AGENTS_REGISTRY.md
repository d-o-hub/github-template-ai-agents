# Agents Registry

> Auto-generated registry of all sub-agents in this repository.
> Last updated: 2026-03-15

This file provides centralized discovery for all available sub-agents.
Agents are organized by CLI tool and purpose.

---

## Quick Reference

### Claude Code Agents

| Agent | Purpose | Tools |
|-------|---------|-------|
| [`agent-creator`](../.claude/agents/agent-creator.md) | Create new sub-agents with proper format | Write, Read, Glob, Grep, Edit |
| [`analysis-swarm`](../.claude/agents/analysis-swarm.md) | Multi-persona code analysis (RYAN, FLASH, SOCRATES) | Read, Glob, Grep, Bash |
| [`goap-agent`](../.claude/agents/goap-agent.md) | Goal-oriented action planning & coordination | Task, Read, Glob, Grep, TodoWrite |
| [`loop-agent`](../.claude/agents/loop-agent.md) | Iterative workflow execution & refinement | Task, Read, TodoWrite, Glob, Grep |

### OpenCode Agents

| Agent | Purpose | Mode |
|-------|---------|------|
| [`analysis-swarm`](../.opencode/agents/analysis-swarm.md) | Multi-persona code analysis | subagent |
| [`goap-agent`](../.opencode/agents/goap-agent.md) | GOAP planning & coordination | all |
| [`git-worktree-manager`](../.opencode/agents/git-worktree-manager.md) | Git worktree management | - |
| [`github-action-editor`](../.opencode/agents/github-action-editor.md) | GitHub Actions workflow editing | - |
| [`perplexity-researcher-pro`](../.opencode/agents/perplexity-researcher-pro.md) | Web research via Perplexity | - |
| [`perplexity-researcher-reasoning-pro`](../.opencode/agents/perplexity-researcher-reasoning-pro.md) | Enhanced reasoning research | - |

---

## Available Skills

Skills are reusable knowledge modules with progressive disclosure.
See [`agents-docs/SKILLS.md`](SKILLS.md) for authoring guide.

| Skill | Location | Description |
|-------|----------|-------------|
| [`agent-coordination`](../.agents/skills/agent-coordination/) | `.agents/skills/` | Multi-agent orchestration patterns (hybrid, iterative, parallel, sequential, swarm) |
| [`github-readme`](../.agents/skills/github-readme/) | `.agents/skills/` | Create human-focused README.md files with 2026 best practices |
| [`goap-agent`](../.agents/skills/goap-agent/) | `.agents/skills/` | Goal-Oriented Action Planning execution strategies |
| [`iterative-refinement`](../.agents/skills/iterative-refinement/) | `.agents/skills/` | Iterative code improvement patterns with validation loops |
| [`parallel-execution`](../.agents/skills/parallel-execution/) | `.agents/skills/` | Parallel task execution patterns |
| [`shell-script-quality`](../.agents/skills/shell-script-quality/) | `.agents/skills/` | Shell script linting (ShellCheck) and testing (BATS) |
| [`skill-creator`](../.agents/skills/skill-creator/) | `.agents/skills/` | Create new skills with proper structure |
| [`task-decomposition`](../.agents/skills/task-decomposition/) | `.agents/skills/` | Break complex tasks into manageable steps |
| [`web-doc-resolver`](../.agents/skills/web-doc-resolver/) | `.agents/skills/` | Resolve and fetch web documentation |
| [`web-search-researcher`](../.agents/skills/web-search-researcher/) | `.agents/skills/` | Research topics using web search |

---

## Adding New Agents

### Claude Code Format

Create `.claude/agents/<agent-name>.md`:

```markdown
---
name: agent-name
description: What this agent does. Invoke when [specific scenarios].
tools: Read, Grep, Glob, Bash
---

# Agent Name

System prompt for the agent...
```

### OpenCode Format

Create `.opencode/agents/<agent-name>.md`:

```markdown
---
description: What this agent does.
mode: subagent
tools:
  read: true
  glob: true
---

# Agent Name

System prompt...
```

### After Creating

1. Run `./scripts/update-agents-registry.sh` to update this file
2. Update `README.md` agents table if needed

---

## Adding New Skills

1. Create `.agents/skills/<skill-name>/SKILL.md` (≤250 lines)
2. Add `reference/` folder for detailed docs if needed
3. Run `./scripts/setup-skills.sh` to create symlinks
4. Run `./scripts/update-agents-registry.sh` to update this file

### Skill Template

```markdown
---
name: skill-name
description: What this skill does. Use when [scenarios].
---

# Skill Name

Skill instructions...

## When to Use
Activate when: [specific triggers]

## Instructions
[Concise, universally applicable instructions]
```

---

## File Watcher Setup

### VS Code

Add to `.vscode/settings.json`:

```json
{
  "files.watcherExclude": {
    "**/.git/**": true
  },
  "files.watcherInclude": [
    ".claude/agents/**/*.md",
    ".opencode/agents/**/*.md",
    ".agents/skills/**/SKILL.md"
  ]
}
```

### npm-based Watcher

```bash
npm install -g chokidar-cli

# Watch for changes and update registry
chokidar ".claude/agents/*.md" ".opencode/agents/*.md" ".agents/skills/*/SKILL.md" \
  -c "./scripts/update-agents-registry.sh && git add agents-docs/AGENTS_REGISTRY.md"
```

### Git Hook (Post-Merge)

Add to `.git/hooks/post-merge`:

```bash
#!/bin/bash
./scripts/update-agents-registry.sh
git add agents-docs/AGENTS_REGISTRY.md
```

---

*This file is auto-generated. Do not edit manually.*
*Run `./scripts/update-agents-registry.sh` to regenerate.*
