# ADR-009: SessionStart Hook for Agent Context Injection

## Status
Accepted

## Context
AI agents often start a session without awareness of the project's documentation structure, leading to a "cold-start" problem where they don't know where to find specs, decisions, or plans.

## Decision
Implement a `SessionStart` hook that auto-injects project context (documentation map and latest changelog entry) into agent sessions at startup.

## Implementation Details

### File: `hooks/session-start.sh`
A read-only shell script that:
1.  Identifies the documentation root (default: `agents-docs`).
2.  Prints a map of documentation files (up to 2 levels deep).
3.  Prints the latest entry from `CHANGELOG.md`.

### File: `docflow.json`
A configuration pointer for agents:
```json
{
  "docs_root": "agents-docs",
  "changelog": "CHANGELOG.md",
  "hook": "hooks/session-start.sh"
}
```

### Agent Integration
- **Claude**: Registered in `.claude/settings.json` under `hooks.SessionStart`.
- **OpenCode/Qwen**: Referenced in startup configurations.
- **Windsurf**: Referenced in rules.

## Consequences
- Agents will have immediate awareness of project documentation at the start of every session.
- Minimal overhead (~50 lines of shell script).
- Read-only; no impact on the working tree.
