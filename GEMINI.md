@AGENTS.md

<!-- Gemini-specific instructions only. Do not duplicate content from AGENTS.md. -->

## Gemini CLI Features

### Sub-Agents
Gemini sub-agent definitions live in `.gemini/agents/`. Each is a TOML file with fields for `name`, `description`, `prompt`, and `tools`.

Delegate context-heavy research to sub-agents to keep the parent session focused.
See `agents-docs/SUB-AGENTS.md`.

### Skills
Skills live canonically in `.agents/skills/`. Gemini CLI loads skills directly from `.agents/skills/` and no symlinks are required. Run `./scripts/setup-skills.sh` once after cloning to setup other agents, but Gemini CLI natively uses the `.agents/skills/` folder.

Skills use progressive disclosure - `SKILL.md` is injected only when the agent
decides the skill is needed. Do not pre-load all skills at session start.
See `agents-docs/SKILLS.md`.

### Custom Commands
Project-specific commands live in `.gemini/commands/` as `.toml` files.
These commands follow the official Gemini CLI schema:

```toml
description = "Brief description of the command"
prompt = "The full instructions for the agent"
```

Available commands:
- `build` - Incremental build and implementation
- `test` - TDD workflow and bug reproduction
- `review` - Five-axis code quality review
- `commit` - Atomic git workflow and PR creation
- `self-fix-loop` - Automated fix cycles based on CI feedback

### Context Management
- Use `Glob`/`Grep` to find code instead of reading whole file trees
- Prefer sub-agents for multi-step research tasks
- See `agents-docs/CONTEXT.md`
