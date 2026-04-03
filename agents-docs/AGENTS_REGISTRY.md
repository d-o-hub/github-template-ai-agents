# Agents Registry

> Auto-generated registry of all sub-agents in this repository.
> Last updated: 2026-04-03 07:58 UTC

This file provides a centralized discovery mechanism for all available sub-agents.
Agents are organized by CLI tool and purpose.

---

## Quick Reference

| Agent | CLI | Purpose | Tools |
|-------|-----|---------|-------|
| `agent-creator` | Claude Code | Create new Claude Code agents with proper format, YAML front | Write, Read, Glob, Grep, Edit |
| `analysis-swarm` | Claude Code | Multi-persona code analysis orchestrator using RYAN (methodi | Read, Glob, Grep, Bash |
| `goap-agent` | Claude Code | Invoke for complex multi-step tasks requiring intelligent pl | Task, Read, Glob, Grep, TodoWrite |
| `loop-agent` | Claude Code | Execute workflow agents iteratively for refinement and progr | Task, Read, TodoWrite, Glob, Grep |
| `create-agent` | OpenCode | Create new opencode agents with proper format, YAML frontmat |  |
| `git-worktree-manager` | OpenCode | Manage git worktrees for efficient multi-branch development. |  |
| `github-action-editor` | OpenCode | Edit and create GitHub Actions workflows and composite actio |  |

---

## Available Skills

Skills are reusable knowledge modules with progressive disclosure.
See [`SKILLS.md`](SKILLS.md) for authoring guide.

| Skill | Location | Description |
|-------|----------|-------------|
| `agent-coordination` | `.agents/skills/agent-coordination` | Coordinate multiple agents for software development across a |
| `anti-ai-slop` | `.agents/skills/anti-ai-slop` | Apply this skill whenever the user wants to audit, fix, rede |
| `architecture-diagram` | `.agents/skills/architecture-diagram` | Generate or update a project architecture SVG diagram by sca |
| `codeberg-api` | `.agents/skills/codeberg-api` | Interact with Forgejo/Codeberg repositories via the REST API |
| `do-web-doc-resolver` | `.agents/skills/do-web-doc-resolver` | Python implementation for resolving URLs and queries into co |
| `github-readme` | `.agents/skills/github-readme` | Create human-focused GitHub README.md files with 2026 best p |
| `goap-agent` | `.agents/skills/goap-agent` | Invoke for complex multi-step tasks requiring intelligent pl |
| `iterative-refinement` | `.agents/skills/iterative-refinement` | Execute iterative refinement workflows with validation loops |
| `parallel-execution` | `.agents/skills/parallel-execution` | Execute multiple independent tasks simultaneously using para |
| `privacy-first` | `.agents/skills/privacy-first` | Prevent email addresses and personal data from entering the  |
| `shell-script-quality` | `.agents/skills/shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS. Use w |
| `skill-creator` | `.agents/skills/skill-creator` | Create new skills, modify and improve existing skills, and m |
| `skill-evaluator` | `.agents/skills/skill-evaluator` | Reusable skill for evaluating other skills with structure c |
| `task-decomposition` | `.agents/skills/task-decomposition` | Break down complex tasks into atomic, actionable goals with  |
| `triz-solver` | `.agents/skills/triz-solver` | Systematic problem-solving using TRIZ (Theory of Inventive P |
| `ui-ux-optimize` | `.agents/skills/ui-ux-optimize` | Swarm-powered UI/UX prompt optimizer with auto-research agen |
| `web-search-researcher` | `.agents/skills/web-search-researcher` | Research topics using web search to find accurate, current i |

---

## Adding New Agents

1. Create agent file in `.claude/agents/<agent-name>.md` (Claude Code) or `.opencode/agents/<agent-name>.md` (OpenCode)
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
    ".opencode/agents/**/*.md",
    ".agents/skills/**/SKILL.md"
  ]
}
```

Then use a task to run the update script on file changes.

### npm-based Watcher

```bash
npm install -g chokidar-cli

# Watch for changes and update registry
chokidar ".claude/agents/*.md" ".opencode/agents/*.md" ".agents/skills/*/SKILL.md" \
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
