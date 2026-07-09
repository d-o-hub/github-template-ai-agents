---
name: delegate
version: "0.1.1"
category: agent
description: Lightweight retrieval and context agent skill for rapid information gathering and environment assessment. Use this skill when you need quick context lookups, finding code patterns, or assessing current state without full implementation overhead — even if they just say "find where X is defined" or "what's the current state of Y".
changelog:
  - 0.1.1: Initial stable version for opencode-processing-skills adaptation.
  - 0.1.0: Draft version. Not for implementer, goap-agent.
license: MIT
---

# Delegate Skill

The Delegate skill provides a lightweight tier for rapid retrieval and context gathering.

## When to Use

- Quick context lookups and pattern matching
- Finding specific code implementations or documentation
- Assessing the current state of a repository before planning
- Identifying potential areas for modification without deep analysis
- Even if they just say "find where X is defined" or "what's the current state of Y"

## Workflow

1. **Context Retrieval**: Use `grep` and `glob` to locate files matching the query.
2. **Summarization**: Read relevant files and synthesize findings into a concise summary.
3. **Handoff**: Pass gathered context to the primary agent or an Implementer.

## What to Retrieve

| Query Type | Tools | Example |
|-----------|-------|---------|
| "Where is X defined?" | `grep -rn "def X\|class X\|function X"` | Find function/class definitions |
| "What uses X?" | `grep -rn "import X\|require.*X\|from X"` | Find all consumers of a module |
| "Show me the structure" | `find . -type f -name "*.py" \| head -30` | Map directory layout |
| "What changed recently?" | `git log --oneline -10` | Recent commit history |
| "What's in this config?" | Read the file directly | Parse configuration files |

## When to Hand Off

Delegate should hand off to an Implementer when:
- The task requires modifying code, not just reading it
- The user's intent is clearly "fix" or "change" rather than "find" or "show"
- The retrieved context reveals a bug or issue that needs a code fix

## Gotchas

- Avoid deep file reads when a targeted grep would suffice — saves tokens and context.
- When searching for patterns, use the narrowest regex possible to avoid noise.
- If the query is ambiguous, retrieve first, then ask for clarification with context.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can find this faster myself" | Using the Delegate skill ensures systematic coverage and reduces cognitive load during discovery. |
| "Just grep for it inline" | Structured retrieval with handoff ensures findings are captured and passed to the right agent. |

## Red Flags

- [ ] Modifying files while in a "Delegate" context
- [ ] Spending too much time on retrieval when implementation is the goal
- [ ] Reading entire files when targeted grep would answer the question

## See Also

- `implementer` — Execute code changes after delegation
- `goap-agent` — Orchestrator that uses delegate for context gathering

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
