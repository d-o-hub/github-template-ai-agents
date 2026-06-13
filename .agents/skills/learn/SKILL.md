---
name: learn
version: "0.2.10"
description: Extract non-obvious session learnings into scoped AGENTS.md files
category: knowledge-management
trigger: after non-trivial task completion
license: MIT
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

Place learnings in the most specific file:
- **Project-wide**: `agents-docs/self-learning-rules.md` (under `## Recent Project-Wide Learnings`).
- **Script-specific**: `scripts/AGENTS.md`.
- **Skill-specific**: `.agents/skills/<name>/AGENTS.md`.

Also write a fuller `LESSON-NNN` entry to `agents-docs/LESSONS.md` for archival.

### Triple-Write Requirement

Every new non-obvious insight must be recorded in three places:
1. **Verbose Log**: Add a full `LESSON-NNN` entry to `agents-docs/LESSONS.md` with Issue/Root Cause/Solution.
2. **Distilled Note (scoped)**: Add a 1–3 line note to the nearest `AGENTS.md` (this is what `learn` automates).
3. **Distilled Note (project-wide)**: Add a 1–3 line note to `agents-docs/self-learning-rules.md` under `## Recent Project-Wide Learnings`.

### Format

- 1–3 lines per insight in `AGENTS.md`.
- Fits within `MAX_LINES_AGENTS_MD=150` constraint.
- Bulleted list under a "Learnings" or "Context" section.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "This is obvious, no need to record it" | What seems obvious today becomes non-obvious in a new session; document runtime discoveries. |
| "I'll remember this later" | Session context is lost on termination; if it's not written down, it's gone. |

## Red Flags

- [ ] Capturing obvious or already-documented behavior as a new learning
- [ ] Placing learnings in the wrong scope (project-wide for script-specific insights)
- [ ] Skipping the dual-write to LESSONS.md for non-obvious findings

## Reference Files

- `agents-docs/LESSONS.md` - Legacy project-wide lessons.
- `AGENTS.md` - Root agent guidance and constraints.
