# .agents/skills/ - Canonical Skill Source

This is the **single canonical location** for all skills in this repository.

CLI-specific folders contain only symlinks pointing here:

```
.claude/skills/<name>      -> ../../.agents/skills/<name>
.opencode/agent/<name>     -> ../../.agents/skills/<name>
.gemini/skills/<name>      -> ../../.agents/skills/<name>
```

## Setup

After cloning, run once to create all symlinks:

```bash
./scripts/setup-skills.sh
```

Validate symlinks are intact:

```bash
./scripts/validate-skills.sh
```

## Adding a New Skill

1. Create `.agents/skills/<skill-name>/SKILL.md` (see `agents-docs/SKILLS.md`)
2. Run `./scripts/setup-skills.sh` to create symlinks for all CLI tools
3. The skill is now available in Claude Code, OpenCode, and Gemini CLI

## Skills in This Repository

<!-- TODO: List your skills here as they are added -->
<!-- Example:
- `agent-coordination/` - Multi-agent orchestration patterns
- `shell-script-quality/` - Shell script best practices
-->