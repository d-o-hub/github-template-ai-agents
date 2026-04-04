---
name: learn
description: Extract non-obvious session learnings into scoped AGENTS.md files
category: knowledge-management
trigger: after non-trivial task completion
---

# Learn

Extract non-obvious session learnings into scoped `AGENTS.md` files to preserve knowledge across sessions.

## When to Use

Activate after completing a non-trivial task to capture insights that would otherwise be lost.

## Instructions

### What to Capture (Non-Obvious Only)

- Hidden relationships between files or scripts not obvious from code.
- Execution paths that differ from what the code appears to do.
- Non-obvious config, env vars, or flags (see `agents-docs/ENVIRONMENT_VARIABLES.md`).
- Debugging breakthroughs where error messages were misleading.
- Files that must change together (e.g., `AGENTS.md` + `agents-docs/AVAILABLE_SKILLS.md` when adding skills).
- Build/test commands not documented in README.
- Architectural constraints discovered at runtime.

### What NOT to Capture

- Obvious documentation or standard behavior.
- Duplicates of existing entries.
- Verbose explanations or session-specific notes.

### Scoping Rules

Place learnings in the most specific `AGENTS.md` file:
- **Project-wide**: Root `AGENTS.md`.
- **Script-specific**: `scripts/AGENTS.md`.
- **Skill-specific**: `.agents/skills/<name>/AGENTS.md`.

### Format

- 1–3 lines per insight.
- Fits within `MAX_LINES_AGENTS_MD=150` constraint.
- Bulleted list under a "Learnings" or "Context" section.

## Reference Files

- `agents-docs/LESSONS.md` - Legacy project-wide lessons.
- `AGENTS.md` - Root agent guidance and constraints.
