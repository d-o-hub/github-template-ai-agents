---
name: skill-creator
description: Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy. Not for skill-evaluator, intent-classifier.
license: MIT
version: "0.2.10"
category: quality
---

# Skill Creator

Create and improve skills following the Agent Skills specification. A skill extends agent capabilities with specialized knowledge, workflows, and tools.

## When to Use

- User wants to create a skill from scratch, edit, or optimize an existing skill
- Need to run evals to test a skill or benchmark performance
- Even if they just say "create a skill" or "optimize this skill's description"

## Core Loop

1. **Capture intent** - What should the skill do? When should it trigger?
2. **Write draft** - Create SKILL.md with frontmatter and instructions
3. **Create test cases** - Realistic prompts covering 4 buckets: explicit, implicit, contextual, and negative
4. **Run evals via `skill-evaluator`** - Static structure check default; opt-in paired behavioral evaluation via `python3 scripts/run-paired-eval.py --skill <name>` or GitHub Actions `paired-eval.yml`
5. **Review results** - Use eval-viewer or paired artifact reports for human review + benchmarks
6. **Iterate** - Improve based on feedback until satisfied
7. **Optimize description** - Fine-tune frontmatter for better triggering
8. **Check trigger uniqueness** - Grep sibling descriptions for shared trigger phrases; add `Not for <sibling>` until no collisions remain

---

## Skill Specification

### Directory Structure

```
skill-name/
├── SKILL.md          # Required: metadata + instructions
├── scripts/          # Optional: executable code
├── references/       # Optional: documentation
├── assets/           # Optional: templates, resources
├── agents/           # Optional: subagent instructions
├── eval-viewer/      # Optional: review page generation
└── evals/evals.json  # Required in this template: at least 3 test cases
```

### Frontmatter Fields

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | Max 64 chars. Lowercase letters, numbers, hyphens only. |
| `description` | Yes | Max 1024 chars. Describes what the skill does AND when to use it. |
| `category` | Yes | Existing category slug; required by `validate-skills.sh`. |
| `version` | No (recommended) | Optional release stamp for the skill set, not required per-skill SemVer. Missing values warn only. |
| `license` | No | License name or reference to bundled license file. |
| `compatibility` | No | Max 500 chars. Environment requirements. |
| `metadata` | No | Arbitrary key-value mapping. |
| `allowed-tools` | No | Space-delimited list of pre-approved tools. |

### SKILL.md Body

- Keep under **250 lines**
- Use progressive disclosure: move detailed content to `references/`
- Include step-by-step instructions, examples, and common edge cases
- **Mandatory**: Include `## Rationalizations` table to counter common agent excuses
- **Mandatory**: Include `## Red Flags` checklist for early warning behaviors

---

## Optimizing Skill Descriptions

### Core Writing Principles

1. **Use imperative phrasing** — "Use this skill when..." rather than "This skill does..."
2. **Focus on user intent, not implementation** — Describe what the user is trying to achieve
3. **Err on the side of being pushy** — Explicitly list contexts where the skill applies
4. **Keep it concise** — A few sentences; max 1024 characters

### Testing & Evaluation

5. **Design trigger eval queries** — Create ~20 realistic prompts (8-10 should-trigger, 8-10 should-not-trigger)
6. **Vary should-trigger queries** along multiple axes: phrasing, explicitness, detail, complexity
7. **Create strong should-not-trigger queries** — Use near-misses that share keywords but need something different
8. **Run each query multiple times** — Model behavior is nondeterministic; run 3 times
9. **Use train/validation splits** — ~60% train / ~40% validation

---

## Creating Test Cases

Store in `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "bucket": "explicit",
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": [],
      "assertions": ["The output includes X"]
    }
  ]
}
```

### Test Case Guidelines & 4-Bucket Taxonomy

- **Template-local requirement**: Every skill needs `evals/evals.json` with at least 3 cases.
- **Buckets**: Tag each case with an optional `bucket` field:
  - `explicit`: Request directly names the skill's domain/job.
  - `implicit`: Request requires the skill's capabilities without naming it explicitly.
  - `contextual`: Request is adjacent to the skill domain; tests boundary awareness.
  - `negative`: Request is out-of-scope; target skill must stay unloaded and avoid false activation.
- **Shape**: Matching `skill_name`, unique integer IDs, non-empty `prompt` and `expected_output` strings, checkable `assertions` string array.
- **Opt-in Paired Behavioral Evaluation**: Request paired runs via `python3 scripts/run-paired-eval.py --skill <name>` or GitHub Actions workflow `paired-eval.yml`. Do not confuse static structure PASS with behavioral efficacy.

---

## See Also

- `skill-evaluator` — Evaluate and score skills statically or in paired runs
- `intent-classifier` — Route requests to appropriate skills

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I don't need evals, the skill works fine" | Without evals there is no evidence the skill triggers correctly or produces quality output. |
| "The description is good enough, no need to optimize" | A poorly tuned description causes false triggers or missed invocations, wasting tokens and degrading user experience. |
| "I'll add Rationalizations and Red Flags later" | These sections are mandatory; they prevent common failure modes and make the skill self-defending. |

## Red Flags

- [ ] Creating a skill without running static checks or designing eval cases.
- [ ] Skipping the description optimization step and shipping a vague or broad trigger.
- [ ] Hardcoding project-specific paths or values instead of using relative references.
- [ ] Omitting `## Rationalizations` or `## Red Flags` sections from SKILL.md.

## References

- `references/guide.md` - Templates, examples, and best practices
- `references/scripts.md` - CLI reference for bundled scripts
- `references/evaluating-skills.md` - Evaluating skill output quality and paired runs
