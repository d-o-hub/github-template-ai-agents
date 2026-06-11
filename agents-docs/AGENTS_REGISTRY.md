# Agents Registry

> Auto-generated registry of all sub-agents in this repository.
> Last updated: 2026-06-11 09:55 UTC

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
| `git-worktree-manager` | OpenCode | Manage git worktrees for efficient multi-branch development |  |
| `github-action-editor` | OpenCode | Edit and create GitHub Actions workflows and composite actio |  |

---

## Available Skills

Skills are reusable knowledge modules with progressive disclosure.
See [`agents-docs/SKILLS.md`](agents-docs/SKILLS.md) for authoring guide.

| Skill | Location | Description |
|-------|----------|-------------|
| `accessibility-auditor` | `.agents/skills/accessibility-auditor` | Audit web applications for WCAG 2.2 compliance, screen reade |
| `agent-browser` | `.agents/skills/agent-browser` | Browser automation CLI for AI agents. Use when the user need |
| `agent-coordination` | `.agents/skills/agent-coordination` | Coordinate multiple agents for software development across a |
| `agents-md` | `.agents/skills/agents-md` | Create AGENTS.md files with production-ready best practices. |
| `anti-ai-slop` | `.agents/skills/anti-ai-slop` | Apply this skill to avoid generic "AI slop" in UI, UX, and c |
| `api-design-first` | `.agents/skills/api-design-first` | Design and document RESTful APIs using design-first principl |
| `architecture-diagram` | `.agents/skills/architecture-diagram` | Generate or update a project architecture SVG diagram by sca |
| `atomic-commit` | `.agents/skills/atomic-commit` | Atomic git workflow - validates, commits, pushes, creates PR |
| `cicd-pipeline` | `.agents/skills/cicd-pipeline` | Design and implement CI/CD pipelines with GitHub Actions, Gi |
| `cloudflare-worker-api` | `.agents/skills/cloudflare-worker-api` | Structure Worker API routes and handlers. Activate for route |
| `codacy-analysis-cli` | `.agents/skills/codacy` | Uses the Codacy Analysis CLI to run local static analysis on |
| `code-quality` | `.agents/skills/code-quality` | Review and improve code quality across any programming langu |
| `code-review-assistant` | `.agents/skills/code-review-assistant` | Automated code review with PR analysis, change summaries, an |
| `codeberg-api` | `.agents/skills/codeberg-api` | Interact with Forgejo/Codeberg repositories via the REST API |
| `css-render-performance` | `.agents/skills/css-render-performance` | Guide CSS render performance analysis and optimization. Use  |
| `database-devops` | `.agents/skills/database-devops` | Database design, migration, and DevOps automation with safet |
| `database-schema-migrations` | `.agents/skills/database-schema-migrations` | Design database schema and write migrations. Activate for ta |
| `delegate` | `.agents/skills/delegate` | Lightweight retrieval and context agent skill for rapid info |
| `dist-channel-selection` | `.agents/skills/dist-channel-selection` | Guide for selecting the correct distribution channel (npm, C |
| `do-web-doc-resolver` | `.agents/skills/do-web-doc-resolver` | Python resolver for URLs and queries into compact, LLM-ready |
| `docs-hook` | `.agents/skills/docs-hook` | Lightweight git hook integration for updating agents-docs wi |
| `document-rendering-and-locators` | `.agents/skills/document-rendering-and-locators` | Implement resilient document rendering and annotation anchor |
| `dogfood` | `.agents/skills/dogfood` | Systematically explore and test a web application to find bu |
| `dora-report` | `.agents/skills/dora-report` | Monthly DORA + agentic metrics reporting skill. Triggers on  |
| `durable-objects` | `.agents/skills/durable-objects` | Create and review Cloudflare Durable Objects. Use when build |
| `eu-ai-act-compliance` | `.agents/skills/eu-ai-act-compliance` | EU AI Act compliance logging and requirements. Use for ensur |
| `git-github-workflow` | `.agents/skills/git-github-workflow` | Unified atomic git workflow with GitHub integration - commit |
| `github-pr-sentinel` | `.agents/skills/github-pr-sentinel` | Monitor a GitHub pull request until it's merged, green, or b |
| `github-workflow` | `.agents/skills/github-workflow` | Complete GitHub workflow automation - push, create branch/PR |
| `goap-agent` | `.agents/skills/goap-agent` | Invoke for complex multi-step tasks requiring intelligent pl |
| `implementer` | `.agents/skills/implementer` | Execution agent skill focused on implementing changes based  |
| `intent-classifier` | `.agents/skills/intent-classifier` | Classify user intents and route to appropriate skills, comma |
| `iterative-refinement` | `.agents/skills/iterative-refinement` | Execute iterative refinement workflows with validation loops |
| `jules-delegator` | `.agents/skills/jules-delegator` | Use this skill to delegate complex coding tasks by creating  |
| `learn` | `.agents/skills/learn` | Extract non-obvious session learnings into scoped AGENTS.md  |
| `lifecycle-management` | `.agents/skills/lifecycle-management` | Manage application lifecycle, error handling, and resource c |
| `memory-context` | `.agents/skills/memory-context` | Retrieve semantically relevant past learnings and analysis o |
| `migration-refactoring` | `.agents/skills/migration-refactoring` | Automate complex code migrations and refactorings with safet |
| `parallel-execution` | `.agents/skills/parallel-execution` | Execute multiple independent tasks simultaneously using para |
| `privacy-first` | `.agents/skills/privacy-first` | Prevent email addresses and personal data from entering the  |
| `pwa-offline-sync` | `.agents/skills/pwa-offline-sync` | Design Cache Storage + IndexedDB strategy and sync queue. Ac |
| `reader-ui-ux` | `.agents/skills/reader-ui-ux` | Build localized, accessible reader/admin UI with responsive  |
| `readme-best-practices` | `.agents/skills/readme-best-practices` | Create, audit, and improve GitHub README.md files following  |
| `secure-invite-and-access` | `.agents/skills/secure-invite-and-access` | Implement access control, authentication, and authorization  |
| `security-code-auditor` | `.agents/skills/security-code-auditor` | Perform security audits on code to identify vulnerabilities, |
| `self-fix-loop` | `.agents/skills/self-fix-loop` | Self-learning fix loop - commit, push, monitor CI, auto-fix  |
| `shell-script-quality` | `.agents/skills/shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS. Use w |
| `skill-creator` | `.agents/skills/skill-creator` | Create new skills, modify and improve existing skills, and m |
| `skill-evaluator` | `.agents/skills/skill-evaluator` | Reusable skill for evaluating other skills with structure ch |
| `static-analysis` | `.agents/skills/static-analysis` | Language-agnostic static analysis and linter triage skill fo |
| `task-decomposition` | `.agents/skills/task-decomposition` | Break down complex tasks into atomic, actionable goals with  |
| `test-runner` | `.agents/skills/test-runner` | Execute tests, analyze results, and diagnose failures across |
| `testdata-builders` | `.agents/skills/testdata-builders` | Maintain deterministic builders/factories for test entities. |
| `testing-strategy` | `.agents/skills/testing-strategy` | Design and implement comprehensive testing strategies for so |
| `triz-analysis` | `.agents/skills/triz-analysis` | Run a systematic TRIZ contradiction audit against a codebase |
| `triz-solver` | `.agents/skills/triz-solver` | Systematic problem-solving using TRIZ (Theory of Inventive P |
| `turso-db` | `.agents/skills/turso-db` | Use this skill for Turso (LibSQL/Limbo) database development |
| `ui-ux-optimize` | `.agents/skills/ui-ux-optimize` | Swarm-powered UI/UX prompt optimizer with auto-research agen |
| `verification-template` | `.agents/skills/verification-template` | Template for creating portable domain-specific verification  |
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
