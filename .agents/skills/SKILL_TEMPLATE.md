---
name: your-skill-name
description: |
  Use this skill when ...
category: <category>
license: MIT
version: "0.1.0"
metadata:
  author: your-name
---

# Skill Title

One-sentence purpose statement.

## When to Use

- Bullet trigger conditions (quote exact user phrases)
- Add `Not for <sibling>` guards for every near-miss sibling skill

## Evals Scaffold (required by validate-skills.sh: ≥3 cases in evals/evals.json)

- Author realistic prompts plus at least one should-not-trigger near-miss
- See `skill-creator/references/schemas.md` for the eval JSON schema

## Required Inputs

List what the caller must provide.

## Steps

Numbered workflow the agent follows.

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I don't need this because..." | "You do because..." |

## Red Flags

- [ ] Early warning behavior 1
- [ ] Early warning behavior 2

## References

- `references/` — link relevant sub-documents

## See Also

- Related skill — brief description of when to use it instead (mirrors the
  `Not for` guards above so routing stays consistent both directions)
