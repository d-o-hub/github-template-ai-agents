# Skills - Authoring Guide

> Reference doc - not loaded by default.

## Canonical Location

All skills live in `.agents/skills/` (the canonical source).
Claude Code and Gemini CLI use symlinks; OpenCode reads directly from `.agents/skills/`:

```
.agents/skills/<name>/          <- CANONICAL (all agents read from here)
.claude/skills/<name>           -> symlink -> ../../.agents/skills/<name>
.gemini/skills/<name>           -> symlink -> ../../.agents/skills/<name>
```

Run `./scripts/setup-skills.sh` after cloning to create symlinks for Claude Code and Gemini CLI.
Run `./scripts/validate-skills.sh` to verify integrity.

## Why .agents/ as Canonical?

`.claude/` is Claude Code-specific. `.agents/` is tool-agnostic - it works when you
add Gemini CLI, OpenCode, Codex, or any future harness without moving files.

## Progressive Disclosure

Skills prevent instruction budget exhaustion: a skill's `SKILL.md` is loaded only
when the agent decides it is needed. Do not pre-load all skills at session start.

## Directory Structure

```
.agents/skills/
+-- skill-name/
    +-- SKILL.md          # Primary instructions (<= 250 lines)
    +-- reference/        # Detailed docs linked from SKILL.md
    +-- scripts/          # Executable scripts the agent can run directly
    +-- assets/           # Templates, examples
```

## SKILL.md Template

```markdown
# Skill Name

Brief description.

## When to Use
Activate when: [specific triggers]

## Instructions
[Concise, universally applicable instructions]

## Reference Files
- `reference/guide.md` - [when to read]
- `scripts/run.sh` - [what it does]

## Examples
[Concrete usage]
```

## Rules

- `SKILL.md` <= 250 lines - detailed content in `reference/`
- Include executable scripts so the agent can validate directly
- Cite sources as `filepath:line` so the parent agent can find context
- Do not duplicate content already in `AGENTS.md`
- Never install skills from untrusted registries - read them first

## Agent vs Skill

| Use a Skill | Use a Sub-Agent |
|---|---|
| Reusable reference knowledge | Complex multi-step execution |
| Main agent executes with guidance | Needs isolated context window |
| No context isolation needed | Different tool access than parent |