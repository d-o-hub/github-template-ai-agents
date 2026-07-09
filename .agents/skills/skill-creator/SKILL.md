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
3. **Create test cases** - Realistic prompts users would actually say
4. **Run evals** - Test with-skill vs baseline (or old version)
5. **Review results** - Use eval-viewer for human review + benchmarks
6. **Iterate** - Improve based on feedback until satisfied
7. **Optimize description** - Fine-tune frontmatter for better triggering

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
└── evals/            # Optional: test cases
```

### Frontmatter Fields

| Field | Required | Constraints |
|-------|----------|-------------|
| `name` | Yes | Max 64 chars. Lowercase letters, numbers, hyphens only. |
| `description` | Yes | Max 1024 chars. Describes what the skill does AND when to use it. |
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

### The Optimization Loop

10. **Evaluate on both sets** — Train results guide changes; validation tells if changes generalize
11. **Identify failures in train set only** — Keep validation results hidden during iteration
12. **Revise strategically:**
    - Should-trigger failing → broaden scope or add context
    - Should-not-trigger false-triggering → add specificity about what the skill does *not* do
13. **Select best iteration by validation pass rate**
14. **Check the 1024-character limit**

---

## Creating Test Cases

Store in `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": [],
      "assertions": ["The output includes X"]
    }
  ]
}
```

### Test Case Guidelines

- **Realism**: Add file paths, personal context, specific details, casual language
- **Variety**: Mix formal/casual, terse/context-heavy, single-step/multi-step
- **Near-misses**: Include queries that share keywords but need something different

---

## Domain-Specific Verification Skills

When creating a new domain-specific skill, always include a verification checklist.
Use `.agents/skills/verification-template/SKILL.md` as a starting point.

### Benefits

- Deep domain knowledge encoded in skills.
- Reduces onboarding time.
- Ensures consistent debugging and verification approach.

## See Also

- `skill-evaluator` — Evaluate and score skills
- `intent-classifier` — Route requests to appropriate skills

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I don't need evals, the skill works fine" | Without evals there is no evidence the skill triggers correctly or produces quality output. |
| "The description is good enough, no need to optimize" | A poorly tuned description causes false triggers or missed invocations, wasting tokens and degrading user experience. |
| "I'll add Rationalizations and Red Flags later" | These sections are mandatory; they prevent common failure modes and make the skill self-defending. |

## Red Flags

- [ ] Creating a skill without running the eval loop at least once.
- [ ] Skipping the description optimization step and shipping a vague or overly broad trigger.
- [ ] Hardcoding project-specific paths or values instead of using relative references.
- [ ] Omitting the `## Rationalizations` or `## Red Flags` sections from SKILL.md.

## References

- `references/guide.md` - Templates, examples, and best practices
- `references/evaluating-skills.md` - Evaluating skill output quality
- `references/schemas.md` - JSON schemas for evals, grading, timing, benchmark
- `references/best-practices.md` - Best practices for skill creators
- `references/output-patterns.md` - Common output patterns
- `references/workflows.md` - Common workflow patterns
- `agents/grader.md` - Subagent for grading eval assertions
- `agents/analyzer.md` - Subagent for analyzing benchmark results
- `agents/comparator.md` - Subagent for blind A/B comparison
- `eval-viewer/generate_review.py` - Generate HTML review page from results
- `assets/eval_review.html` - Self-contained eval set query review tool

## Registration and Standards

### How to register a skill in AGENTS.md

1. **Catalog Update**: Add the skill to the "Skills" section in `AGENTS.md` following the alphabetical order within its category.
2. **Docs Sync**: Add the skill to `agents-docs/skills-reference.md`.
3. **Registry Update**: Run `./scripts/update-agents-registry.sh` if applicable.
4. **Maintenance**: Run `./scripts/generate-skills-readme.py` and `./scripts/generate-available-skills.sh` to update auto-generated documentation.

### Acceptance Criteria Format

Every new skill must meet these criteria before being merged:
- [ ] `SKILL.md` is under 250 lines.
- [ ] Frontmatter contains `name`, `description`, `category`, and `version`.
- [ ] Includes `## Rationalizations` and `## Red Flags` sections.
- [ ] Contains at least 3 realistic eval cases in `evals/evals.json`.
- [ ] Successfully passes `./scripts/validate-skills.sh`.

### Versioning Conventions

- Use Semantic Versioning (SemVer) for the `version` field.
- **Major (1.0.0)**: Breaking changes in skill interface or core logic.
- **Minor (0.1.0)**: New instructions, sections, or eval cases that don't break existing usage.
- **Patch (0.0.1)**: Typos, minor phrasing improvements, or metadata updates.

## Scripts

### Initialize a New Skill

```bash
python -m scripts.init_skill \
  --skill-name my-skill \
  --description "Do X. Use when Y."
```

Creates full directory structure, SKILL.md template, evals/evals.json with 3 placeholder cases, scripts/example.py, and references/guide.md.

### Package for Distribution

```bash
python -m scripts.package_skill <path/to/skill-folder> [--output out.skill] [--force]
```

Validates structure (SKILL.md, evals/evals.json) and creates a `.skill` tar.gz archive.

### Aggregate Benchmark Results

```bash
python -m scripts.aggregate_benchmark <workspace-path> [--iteration N]
```

Reads all grading.json and timing.json, computes pass_rate/time/tokens stats per config, outputs `benchmark.json` and `benchmark.md`.

### Optimize Description

```bash
python -m scripts.run_loop \
  --eval-set <queries.json> \
  --skill-path <path/to/skill> \
  --model <model> \
  --max-iterations 5 \
  --verbose
```

Splits eval set 60/40 train/validation, iteratively evaluates and proposes description improvements, outputs best description by validation score.

### Generate Review Page

```bash
python eval-viewer/generate_review.py \
  --workspace <workspace-path> \
  --skill-name <name> \
  --static <output.html>
```

Generates standalone HTML with Outputs and Benchmark tabs for human review.

## Voice & Context

- **Default**: `professional` + `blog`
- **Reference**: `voice-profiles` skill for definitions and auto-detection.
