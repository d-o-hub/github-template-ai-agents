---
# Frontmatter policy: agents-docs/SKILLS.md, "Frontmatter Field Policy".
# Fields tagged "spec" are defined by the Agent Skills specification
# (https://agentskills.io/specification). Fields tagged "template-local" are a
# convention of this repository only: harnesses tolerate them, but claude.ai
# upload and the Skills API hard-error on them, so a packaging step must nest
# them under `metadata` before any such upload.
# Note: never write a triple-dash run in these comments; naive frontmatter
# splitters cut the block at the first two occurrences in the whole file.
name: your-skill-name # spec, REQUIRED
description: | # spec, REQUIRED
  Use this skill when ...
license: MIT # spec, RECOMMENDED
metadata: # spec, OPTIONAL - the spec's home for non-spec keys
  author: your-name
# template-local fields follow
category: <category> # REQUIRED - hard-enforced by scripts/validate-skills.sh
version: "0.1.0" # RECOMMENDED - release stamp, NOT per-skill semver
# template_version: "0.2" # OPTIONAL - derived from the root VERSION file
---

# Skill Title

One-sentence purpose statement.

## When to Use

- Bullet trigger conditions (quote exact user phrases)
- Add `Not for <sibling>` guards for every near-miss sibling skill
- Triggers belong in `description`; the legacy `trigger:` key is OPTIONAL
  and not read by any validator

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
