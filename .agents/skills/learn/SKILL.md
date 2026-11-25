---
name: learn
version: "0.3.0"
description: >
  Extract non-obvious session learnings, patterns, and discoveries into scoped AGENTS.md files. Use this skill when the user wants to extract learnings after completing non-trivial tasks, or when they say "extract learnings", "save patterns", "update AGENTS.md", or whenever the session has produced insights that should be captured for future reference — even if they just say "what did we learn" or "save this for later". Also owns the git-hook docs-sync trigger mode: updating generated agent documentation on commit or merge events — even if they just say "update the docs" or "sync the agent docs". Not for agents-md, skill-creator.
category: knowledge-management
trigger: after non-trivial task completion
license: MIT
---

# Learn

Extract non-obvious session learnings into scoped `AGENTS.md` files to preserve knowledge across sessions — and keep generated project docs in sync when commit/merge hooks fire.

## When to Use

Activate after completing a non-trivial task to capture insights that would otherwise be lost; activate on commit or merge events when the docs-sync hook should run.

## Trigger modes

Two ways this skill is invoked; the git-hook mode was absorbed from docs-hook (ADR-038):

1. **Manual extraction** (default): after a non-trivial task, distill learnings per the scoping rules below.
2. **Git-hook docs-sync**: on commit or merge events, keep generated documentation current:
   - `scripts/post-commit-docs-sync.sh` — full sync: regenerates the AGENTS.md skill table, `llms.txt`/`llms-full.txt`, and `AGENTS_REGISTRY.md`, syncs changed docs, and amends the commit (GitHub-style installs go in `.githooks/post-commit` or run manually).
   - `scripts/docs-sync.sh <from> <to>` — lightweight pass that only lists changed markdown between two refs (e.g. `HEAD~1 HEAD`); no ML, no logging, no metrics.

Hook behavior is controlled by environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `DOCS_SYNC_ENABLED` | `true` | Enable/disable docs sync |
| `DOCS_SYNC_QUIET` | `false` | Suppress output messages |
| `DOCS_SYNC_LLM_TXT` | `true` | Regenerate LLM context files |

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
- Fits within `MAX_LINES_AGENTS_MD=200` constraint.
- Bulleted list under a "Learnings" or "Context" section.

## See Also

- `agents-md` — AGENTS.md best practices
- `skill-creator` — Create and improve skills

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "This is obvious, no need to record it" | What seems obvious today becomes non-obvious in a new session; document runtime discoveries. |
| "I'll remember this later" | Session context is lost on termination; if it's not written down, it's gone. |
| "Docs can sync manually, no need for automation" | Manual sync is forgotten within days; automation ensures consistency. (absorbed from docs-hook) |
| "The hook is slow, I'll skip it" | A few seconds of sync prevents hours of out-of-date documentation debt. (absorbed from docs-hook) |
| "Only production docs need syncing" | Stale developer docs cause onboarding confusion and incorrect assumptions. (absorbed from docs-hook) |

## Red Flags

- [ ] Capturing obvious or already-documented behavior as a new learning
- [ ] Placing learnings in the wrong scope (project-wide for script-specific insights)
- [ ] Skipping the dual-write to LESSONS.md for non-obvious findings
- [ ] Disabling the docs hook to speed up commits (absorbed from docs-hook)
- [ ] Manually copying docs instead of using the sync script (absorbed from docs-hook)
- [ ] Ignoring sync failures after documentation changes (absorbed from docs-hook)

## References

- `agents-docs/LESSONS.md` - Legacy project-wide lessons.
- `AGENTS.md` - Root agent guidance and constraints.

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
