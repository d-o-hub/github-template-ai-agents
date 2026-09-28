# Agents Registry

> Auto-generated registry of all sub-agents in this repository.
> Last updated: 2026-09-28 15:30 UTC

This file provides a centralized discovery mechanism for all available sub-agents.
Agents are organized by CLI tool and purpose.

---

## Quick Reference

| Agent | CLI | Purpose | Tools |
|-------|-----|---------|-------|
| `agent-creator` | Claude Code | Create new Claude Code agents with proper format, YAML | Write, Read, Glob, Grep, Edit |
| `analysis-swarm` | Claude Code | Multi-persona code analysis orchestrator using RYAN | Read, Glob, Grep, Bash |
| `goap-agent` | Claude Code | Invoke for complex multi-step tasks requiring intelligent | Task, Read, Glob, Grep, TodoWrite |
| `loop-agent` | Claude Code | Execute workflow agents iteratively for refinement and | Task, Read, TodoWrite, Glob, Grep |
| `github-action-editor` | OpenCode | Edit and create GitHub Actions workflows and composite |  |
| `git-worktree-manager` | OpenCode | Manage git worktrees for efficient multi-branch development |  |

---

## Available Skills

Skills are reusable knowledge modules with progressive disclosure.
See [Creating or Updating Skills](../CONTRIBUTING.md#creating-or-updating-skills) for the authoring guide.

| Skill | Location | Description |
|-------|----------|-------------|
| `accessibility-auditor` | `.agents/skills/accessibility-auditor` | Audit web applications for WCAG 2.2 compliance, screen |
| `agent-browser` | `.agents/skills/agent-browser` | Browser automation CLI for AI agents. Use when the user |
| `agentic-abstention` | `.agents/skills/agentic-abstention` | Encode CONVOLVE-style stopping rules: decide when to stop |
| `agents-md` | `.agents/skills/agents-md` | Create AGENTS.md files with production-ready best |
| `api-design-first` | `.agents/skills/api-design-first` | Design and document RESTful APIs using design-first |
| `architecture-diagram` | `.agents/skills/architecture-diagram` | Generate or update a project architecture SVG diagram by |
| `avoid-ai-writing` | `.agents/skills/avoid-ai-writing` | Audit and rewrite content to remove AI writing patterns |
| `cicd-pipeline` | `.agents/skills/cicd-pipeline` | Design and configure CI/CD pipelines with GitHub Actions, |
| `cloudflare-worker-api` | `.agents/skills/cloudflare-worker-api` | Structure Worker API routes and handlers. Use this skill |
| `codacy` | `.agents/skills/codacy` | Use the Codacy CLI for local static analysis and cloud data |
| `codeberg-api` | `.agents/skills/codeberg-api` | Interact with Forgejo/Codeberg repositories via the REST |
| `code-review-assistant` | `.agents/skills/code-review-assistant` | Automated code review with PR analysis, change summaries, |
| `css-render-performance` | `.agents/skills/css-render-performance` | Guide CSS render performance analysis and optimization. Use |
| `database-devops` | `.agents/skills/database-devops` | Database design, migration, and DevOps automation with |
| `debugger` | `.agents/skills/debugger` | Diagnose failing builds and runtime errors with root-cause |
| `delegate` | `.agents/skills/delegate` | Lightweight retrieval and context agent skill for rapid |
| `dependency-upgrades` | `.agents/skills/dependency-upgrades` | Perform routine, low-risk dependency version bumps and |
| `dist-channel-selection` | `.agents/skills/dist-channel-selection` | Guide for selecting the correct distribution channel (npm, |
| `docs-hook` | `.agents/skills/docs-hook` | Lightweight git hook integration for updating agents-docs |
| `document-rendering-and-locators` | `.agents/skills/document-rendering-and-locators` | Implement resilient document rendering and annotation |
| `dogfood` | `.agents/skills/dogfood` | Systematically explore and test a web application to find |
| `dora-report` | `.agents/skills/dora-report` | Generate monthly DORA and agentic metrics reports. Use this |
| `do-web-doc-resolver` | `.agents/skills/do-web-doc-resolver` | Python resolver for URLs and queries into compact, |
| `durable-objects` | `.agents/skills/durable-objects` | Create and review Cloudflare Durable Objects. Use when |
| `eu-ai-act-compliance` | `.agents/skills/eu-ai-act-compliance` | EU AI Act compliance logging and requirements. Use this |
| `git-github-workflow` | `.agents/skills/git-github-workflow` | Orchestrates the full git-to-merge lifecycle: validate → |
| `goap-agent` | `.agents/skills/goap-agent` | Orchestrates complex multi-step tasks with intelligent |
| `implementer` | `.agents/skills/implementer` | Execution agent skill focused on implementing changes based |
| `intent-classifier` | `.agents/skills/intent-classifier` | Classify user intents and route to appropriate skills, |
| `iterative-refinement` | `.agents/skills/iterative-refinement` | Execute iterative refinement workflows with validation |
| `jules-delegator` | `.agents/skills/jules-delegator` | Use this skill to delegate complex coding tasks by creating |
| `learn` | `.agents/skills/learn` | Extract non-obvious session learnings, patterns, and |
| `lifecycle-management` | `.agents/skills/lifecycle-management` | Manage application lifecycle, error handling, and resource |
| `memory-context` | `.agents/skills/memory-context` | Retrieve semantically relevant past learnings, analysis |
| `migration-refactoring` | `.agents/skills/migration-refactoring` | Automate complex code migrations and refactorings with |
| `privacy-first` | `.agents/skills/privacy-first` | Prevent email addresses and personal data from entering the |
| `progressive-delivery` | `.agents/skills/progressive-delivery` | Remediate a live production failure through a gated loop: |
| `pwa-offline-sync` | `.agents/skills/pwa-offline-sync` | Design Cache Storage + IndexedDB strategy and sync queue. |
| `reader-ui-ux` | `.agents/skills/reader-ui-ux` | Build localized, accessible reader/admin UI with responsive |
| `readme-best-practices` | `.agents/skills/readme-best-practices` | Create, audit, and improve GitHub README.md files following |
| `secrets-management` | `.agents/skills/secrets-management` | Own the secret lifecycle: detect leaked secrets, rotate |
| `secure-invite-and-access` | `.agents/skills/secure-invite-and-access` | Implement access control, authentication, and authorization |
| `security-code-auditor` | `.agents/skills/security-code-auditor` | Perform security audits on code to identify |
| `shell-script-quality` | `.agents/skills/shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS. Use |
| `skill-creator` | `.agents/skills/skill-creator` | Create new skills, modify and improve existing skills, and |
| `skill-evaluator` | `.agents/skills/skill-evaluator` | Reusable skill for evaluating other skills with structure |
| `static-analysis` | `.agents/skills/static-analysis` | Triage and fix static analysis findings across any |
| `testing-strategy` | `.agents/skills/testing-strategy` | Design and implement comprehensive testing strategies for |
| `test-runner` | `.agents/skills/test-runner` | Execute tests, analyze results, and diagnose failures |
| `triz-solver` | `.agents/skills/triz-solver` | Systematic problem-solving using TRIZ (Theory of Inventive |
| `turso-db` | `.agents/skills/turso-db` | Use this skill for Turso (LibSQL/Limbo) database |
| `ui-ux-optimize` | `.agents/skills/ui-ux-optimize` | Swarm-powered UI/UX prompt optimizer with auto-research |
| `voice-profiles` | `.agents/skills/voice-profiles` | Adapt writing tone and style based on target audience and |
| `web-search-researcher` | `.agents/skills/web-search-researcher` | Research topics using web search to find accurate, current |

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
