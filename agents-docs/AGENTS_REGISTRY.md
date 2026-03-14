# Agents Registry

> Auto-generated registry of all sub-agents in this repository.
> Last updated: 2026-03-14 15:31 UTC

This file provides a centralized discovery mechanism for all available sub-agents.
Agents are organized by CLI tool and purpose.

---

## Quick Reference

| Agent | CLI | Purpose | Tools |
|-------|-----|---------|-------|
| `description: Coordinate [type of workflow]. Invoke when you need to orchestrate [complex scenarios].` | Claude Code | Create new Claude Code agents with proper format, YAML front
Clear description of when to invoke this agent and what it d
Execute tests and diagnose failures in Rust projects. Invoke
Review code for quality, standards compliance, and performan
Helps with testing
A specialized testing agent
[What agent does]
Your detailed description here
Execute [specific tasks]
Analyze [specific domain]
Coordinate [type of workflow] | Write, Read, Glob, Grep, Edit
Tool1, Tool2, Tool3  # Optional - omit to inherit all tools
Read, Grep, Glob
Read, Write, Edit, Bash, Glob, Grep
Task, Read, TodoWrite, Glob, Grep
Tool1, Tool2, Tool3
Bash, Read, Grep, Edit
Read, Grep, Glob
Task, Read, TodoWrite, Glob, Grep |
| `description: Multi-persona code analysis orchestrator using RYAN (methodical analyst), FLASH (rapid innovator), and SOCRATES (questioning facilitator) for balanced decision-making. Invoke for complex architectural decisions, trade-off analysis, comprehensive code reviews, or when avoiding single-perspective blind spots is critical.` | Claude Code | Multi-persona code analysis orchestrator using RYAN (methodi | Read, Glob, Grep, Bash |
| `description: Invoke for complex multi-step tasks requiring intelligent planning and multi-agent coordination. Use when tasks need decomposition, dependency mapping, parallel/sequential/swarm/iterative execution strategies, or coordination of multiple specialized agents with quality gates and dynamic optimization.` | Claude Code | Invoke for complex multi-step tasks requiring intelligent pl | Task, Read, Glob, Grep, TodoWrite |
| `description: Execute workflow agents iteratively for refinement and progressive improvement. Invoke when you need repetitive refinement, multi-iteration tasks (code review loops, incremental improvements), progressive optimization, or feedback loops until quality criteria are met or max iterations reached.` | Claude Code | Execute workflow agents iteratively for refinement and progr | Task, Read, TodoWrite, Glob, Grep |
| `description: Clear description of when to invoke this agent and what it does (max 1024 chars)` | OpenCode | Create new opencode agents with proper format, YAML frontmat
Clear description of when to invoke this agent and what it d
Execute tests and diagnose failures in Rust projects. Invoke
Review code for quality, standards compliance, and performan
Helps with testing
A specialized testing agent
[What agent does] |  |
| `description: Manage git worktrees for efficient multi-branch development. Invoke when creating worktrees for feature branches, organizing worktree directories, cleaning up unused worktrees, or implementing worktree-based workflows.` | OpenCode | Manage git worktrees for efficient multi-branch development. |  |
| `description: Edit and create GitHub Actions workflows and composite actions. Invoke when you need to create new CI/CD pipelines, modify existing workflows, ensure syntax correctness, or incorporate current best practices for GitHub Actions.` | OpenCode | Edit and create GitHub Actions workflows and composite actio |  |

---

## Available Skills

Skills are reusable knowledge modules with progressive disclosure.
See [`agents-docs/SKILLS.md`](agents-docs/SKILLS.md) for authoring guide.

| Skill | Location | Description |
|-------|----------|-------------|
| `agent-coordination` | `.agents/skills/agent-coordination` | Coordinate multiple agents for software development across a |
| `goap-agent` | `.agents/skills/goap-agent` | Invoke for complex multi-step tasks requiring intelligent pl |
| `iterative-refinement` | `.agents/skills/iterative-refinement` | Execute iterative refinement workflows with validation loops |
| `parallel-execution` | `.agents/skills/parallel-execution` | Execute multiple independent tasks simultaneously using para |
| `shell-script-quality` | `.agents/skills/shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS. Use w |
| `skill-creator
skill-name
skill-name
$SKILL_NAME` | `.agents/skills/skill-creator` | Create new Claude Code skills with proper directory structur
Clear description of what this skill does and when to use it
Debug and fix failing tests in Rust projects. Use this skill
Implement new features systematically with proper testing an
Helps with testing
Provides guidance on building APIs
[Action] [what it does]. Use this when [specific scenarios].
Your description here
$DESCRIPTION |
| `task-decomposition` | `.agents/skills/task-decomposition` | Break down complex tasks into atomic, actionable goals with  |
| `web-doc-resolver
researcher` | `.agents/skills/web-doc-resolver` | Resolve queries or URLs into compact, LLM-ready markdown usi
Research topics using web search and documentation |
| `web-search-researcher` | `.agents/skills/web-search-researcher` | Research topics using web search and content fetching to fin |

---

## Adding New Agents

1. Create agent file in `.claude/agents/<agent-name>.md` (Claude Code) or `.opencode/agent/<agent-name>.md` (OpenCode)
2. Include YAML frontmatter with `name`, `description`, and `tools`
3. Run `./scripts/update-agents-registry.sh` to update this registry

### Agent File Template

```markdown
---
name: agent-name
description: What this agent does. Invoke when [specific scenarios].
tools: Read, Grep, Glob, Bash
---

# Agent Name

System prompt for the agent...
```

## Adding New Skills

1. Create skill folder in `.agents/skills/<skill-name>/`
2. Add `SKILL.md` with frontmatter (≤250 lines)
3. Run `./scripts/setup-skills.sh` to create symlinks
4. Run `./scripts/update-agents-registry.sh` to update this registry

### Skill File Template

```markdown
---
name: skill-name
description: What this skill does. Use when [specific scenarios].
---

# Skill Name

Skill instructions...
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
    ".opencode/agent/**/*.md",
    ".agents/skills/**/SKILL.md"
  ]
}
```

Then use a task to run the update script on file changes.

### npm-based Watcher

```bash
npm install -g chokidar-cli

# Watch for changes and update registry
chokidar ".claude/agents/*.md" ".opencode/agent/*.md" ".agents/skills/*/SKILL.md" \
  -c "./scripts/update-agents-registry.sh && git add AGENTS_REGISTRY.md"
```

### Git Hook (Post-Merge)

Add to `.git/hooks/post-merge`:

```bash
#!/bin/bash
./scripts/update-agents-registry.sh
git add AGENTS_REGISTRY.md
```

---

*This file is auto-generated. Do not edit manually.*
*Run `./scripts/update-agents-registry.sh` to regenerate.*
