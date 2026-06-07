---
name: delegate
version: "0.1.1"
description: Lightweight retrieval and context agent skill for rapid information gathering and environment assessment. Use for quick context lookups, finding code patterns, or assessing current state without full implementation overhead.
changelog:
  - 0.1.1: Initial stable version for opencode-processing-skills adaptation.
  - 0.1.0: Draft version.
---

# Delegate Skill

The Delegate skill provides a lightweight tier for rapid retrieval and context gathering.

## When to Use

- Quick context lookups and pattern matching.
- Finding specific code implementations or documentation.
- Assessing the current state of a repository before planning.
- Identifying potential areas for modification without deep analysis.

## Workflow

1. **Context Retrieval**: Use `grep` and `glob` to locate files.
2. **Summarization**: Read relevant files and synthesize findings.
3. **Handoff**: Pass gathered context to the primary agent or an Implementer.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can find this faster myself" | Using the Delegate skill ensures systematic coverage and reduces cognitive load during discovery. |

## Red Flags

- [ ] Modifying files while in a "Delegate" context.
- [ ] Spending too much time on retrieval when implementation is the goal.
