---
name: skill-evaluator
description: "Reusable skill for evaluating other skills with structure checks, eval coverage review, and real usage spot checks. Use when you need to check a skill, add evals, benchmark a skill, validate outputs against assertions, or compare current skill behavior against a baseline."
license: MIT
version: "0.2.10"
category: quality
metadata:
  author: d.o.
  version: "1.1"
  spec: "agentskills.io"
---

# Skill Evaluator

Evaluate local skills with a repeatable loop: inspect structure, read eval definitions, run one or more realistic prompts, then score the output with explicit assertions and evidence.

## When to Use

- Test whether a skill is wired correctly
- Check whether `evals/evals.json` exists and is usable
- Run a real prompt through a skill and grade the result
- Compare a skill against a no-skill baseline or older snapshot
- Identify missing folders, weak evals, and flaky assertions

## Required Inputs

At minimum, identify:

```text
SKILL_PATH: absolute or workspace-relative path to the skill directory
GOAL: structure check / eval review / live run / baseline comparison
```

## Evaluation Workflow

### 1. Structure Check

Confirm the skill directory is sane before judging outputs.

Expected layout:

```text
skill-name/
  SKILL.md
  evals/evals.json                   # required
  references/evaluating-skills.md    # required for evaluator
  scripts/                           # optional but useful
```

Flag these issues explicitly:

- missing `SKILL.md`
- nested duplicate directory like `skill-name/skill-name/`
- `evals/` exists but `evals/evals.json` is missing or invalid JSON
- eval cases missing `id`, `prompt`, or `expected_output`

### 2. Eval Review

Read `evals/evals.json` if present and assess whether each case is realistic.

Good evals include:

- a real user prompt
- a short success definition
- optional input files
- assertions that are concrete and checkable

Weak evals include:

- vague prompts
- purely subjective assertions
- no evidence path for pass/fail

### 3. Live Run

Run at least one representative prompt from the eval set or create a focused ad hoc prompt.

For each live run:

- load the target skill
- read only the files the skill itself points to
- produce the answer or output
- grade against assertions with evidence

### 4. Baseline Comparison

Always rerun the same prompt without the skill (or against a snapshot of the older skill) to establish a baseline.

For each run, capture:
- `with_skill`: Standard run using the current skill version.
- `without_skill`: Run using the same prompt but without any skill loaded.
- `old_skill`: (Optional) Run using a prior snapshot of the skill for regression testing.

Compare:
- pass rate
- missing details
- format compliance
- time (`duration_ms`) and token cost (`total_tokens`)

### 5. Verdict

End with one of:

- `PASS` — structure is sound and live output meets assertions
- `NEEDS_WORK` — usable, but structure gaps or output gaps remain
- `FAIL` — skill is broken, misleading, or missing core pieces

## Workspace Layout

Organize eval results in a dedicated workspace directory (e.g., `<skill-name>-workspace/`). Each iteration of the eval loop produces structured artifacts.

```text
<skill-name>-workspace/iteration-N/eval-<id>/
├── with_skill/          # outputs/, timing.json, grading.json
└── without_skill/       # outputs/, timing.json, grading.json
```

Plus `benchmark.json` and `feedback.json` at the iteration level.

## Workspace Iteration Automation — Automate the eval loop: create iteration dirs, run cases, aggregate results.

### 1. Create iteration directory

```bash
ITER="iteration-$(printf '%02d' $((++N)))"
mkdir -p "<skill-name>-workspace/$ITER"
```

### 2. Set up subdirectories

```bash
for ID in $(jq -r '.evals[].id' evals/evals.json); do
  mkdir -p "<skill-name>-workspace/$ITER/eval-$ID"/{with_skill,without_skill}
done
```

### 3. Generate eval_metadata.json

```bash
jq '.evals[] | {id, prompt, expected_output, assertions}' evals/evals.json \
  > "<skill-name>-workspace/$ITER/eval_metadata.json"
```

### 4. Capture timing data

Write `timing.json` with `total_tokens` and `duration_ms` (schema in `references/schemas.md`).

### 5. Run the grader

### 6. Aggregate into benchmark.json

Collect all grading and timing JSONs, compute per-config means/stddevs, write `benchmark.json` with delta.

### 7. Record feedback

Write actionable notes to `feedback.json`, improve the skill, then iterate again.

## Scoring Rubric

Evaluate skills across these four dimensions (Score 1-5):

| Dimension | Description |
|---|---|
| **Clarity** | Are the instructions unambiguous and easy for an agent to follow? |
| **Completeness** | Does it cover common edge cases and include required sections (Rationalizations/Red Flags)? |
| **Testability** | Does it include realistic and varied eval cases in `evals/evals.json`? |
| **Reusability** | Can the skill be applied to multiple projects/contexts without hardcoded values? |

Detailed JSON Schema definitions for all evaluation artifacts are available in `references/schemas.md`.

### Filing a Skill Improvement Issue

When a skill fails evaluation:
1. Open a GitHub Issue with the title `skill-improvement: <skill-name>`.
2. Include the **Eval Report** in the description.
3. Label the issue with `quality` and `skill`.

### Deprecation Process

Outdated or redundant skills should follow this lifecycle:
1. **Deprecation Notice**: Add `[DEPRECATED]` to the `description` in `SKILL.md` and link to the replacement.
2. **Issue Creation**: File an issue to remove the skill in the next major version.
3. **Removal**: Delete the skill directory and update all registries after the notice period.

## Assertion Rules

Prefer assertions that can be checked directly.

Good:

- `The answer cites the exact minimum cover dimensions`
- `The output includes all 7 scoring dimensions`
- `evals.json contains at least 2 cases`

Bad:

- `The output is good`
- `The skill feels smart`
- `The answer is polished`

Every pass or fail must include evidence.

## Output Format

Use this structure:

```text
## Eval Report: <skill-name>

- Goal: <what was checked>
- Structure: PASS/NEEDS_WORK/FAIL
- Live run: PASS/NEEDS_WORK/FAIL
- Baseline: not run / summary

### Assertion Results
- PASS: <assertion> — <evidence>
- FAIL: <assertion> — <evidence>

### Issues
- <issue>

### Next Fixes
1. <highest-value fix>
2. <next fix>

### Verdict
PASS | NEEDS_WORK | FAIL — <one sentence>
```

## Bundled Tools

- `scripts/check_structure.py` — checks local skill folder structure and eval presence

## See Also

- `skill-creator` — Create and improve skills
- `intent-classifier` — Route requests to appropriate skills

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The skill looks fine, I don't need to evaluate it" | Without structured evaluation, gaps in coverage and weak assertions remain invisible until production failure. |
| "One eval case is enough to test the skill" | Single eval cases miss edge cases; multiple diverse cases reveal coverage gaps. |

## Red Flags

- [ ] Skipping baseline comparison when evaluating skill improvement
- [ ] Using vague or subjective assertions without concrete evidence paths
- [ ] Declaring PASS without running at least one live prompt through the skill

## References

- `references/evaluating-skills.md` — condensed eval workflow and grading guidance
