---
name: skill-evaluator
version: "0.2.10"
description: Reusable skill for evaluating other skills with static structure checks, eval coverage review, and manual paired behavioral trials. Use this skill when checking a skill, reviewing eval assertions, grading actual outputs, or comparing a skill against a baseline — even if they just say "evaluate this skill" or "check if this skill works". Not for authoring skills (use skill-creator) or routing requests (use intent-classifier).
category: quality
license: MIT
---

# Skill Evaluator

Evaluate local skills with evidence and an explicit scope. Choose **static
audit** or **manual paired behavioral evaluation**; never confuse their verdicts.

## When to Use

- Check whether a skill is wired correctly and has usable eval definitions
- Review assertion quality and coverage without executing user prompts
- Grade actual outputs or compare a skill against a no-skill/older baseline
- Identify missing fixtures, weak evals, and unclear routing boundaries

## Required Inputs

```text
SKILL_PATH: absolute or workspace-relative path to the skill directory
MODE: static (default) / manual-paired
GOAL: structure / coverage review / behavioral comparison
```

If the user requests behavioral evaluation but execution is unavailable, report
**behavioral: NOT_RUN** or **BLOCKED**, not a static result relabeled as behavior.

## Mode 1: Static Audit

This mode reads definitions only. It invokes no model, executes no eval prompt,
and scores no assertion against an answer. No secrets or authentication are
needed for static evaluation, including evals describing authenticated tools.

### 1. Structure and Schema

```bash
python3 .agents/skills/skill-evaluator/scripts/check_structure.py --path "$SKILL_PATH"
```

The standalone checker accepts one skill directory or an inventory directory.
It ignores support folders without `SKILL.md`, `_`-prefixed directories, and
`*-workspace` directories. An empty inventory fails rather than passing vacuously.

Template-local requirements (not Agent Skills specification requirements):

- `SKILL.md` exists; no nested `skill-name/skill-name/` duplicate
- `evals/evals.json` exists, even if `evals/` itself was never created
- Root JSON object with matching non-empty `skill_name` and `evals` array
- At least **3** cases; each is an object with unique integer `id`, non-empty
  `prompt` and `expected_output` strings, and a non-empty `assertions` string array
- Optional `files` is an array of non-empty paths to existing input files under
  the skill root; absolute paths, escapes, and missing fixtures fail
- Optional `bucket` uses `explicit`, `implicit`, `contextual`, or `negative`;
  a tagged set needs a real out-of-scope negative case

`references/` and `scripts/` are optional. The checker reports their presence,
not their quality. It does not parse frontmatter or enforce prose/line limits;
repository frontmatter policy is in `agents-docs/SKILLS.md`.

### 2. Eval Definition Review

Read every case and check:

- Prompt is realistic, success is defined, and inputs can be found locally
- Assertions are concrete and checkable, not just command-word presence
- Expected output and assertions agree with the skill's instructions
- Contextual cases actually supply context; negative cases leave the target
  skill unloaded and route appropriately instead of merely carrying a label

Schema checks cannot establish these semantic properties. Record this review
separately from the automated structure result, with case IDs as evidence.

### 3. Static Verdict

- **PASS (static)**: structure/schema/fixtures pass and reviewed definitions are usable
- **NEEDS_WORK (static)**: definitions have gaps or weak coverage
- **FAIL (static)**: missing/invalid core files or malformed schema

Always add **Behavioral evaluation: NOT_RUN**. A static PASS is never a
behavioral PASS, trigger-accuracy measurement, or evidence of skill uplift.

## Mode 2: Manual Paired Behavioral Evaluation

This is a manual operator/agent protocol, **not a bundled model runner**.
Repository `eval-skills.sh` and `run-evals.py` are static checks; they cannot
produce behavioral pass rates. Tier 3 automation is not shipped.

### 1. Prepare

Run the static audit first. Choose representative case IDs and define the
grading criteria before seeing answers. Use only authorized, safe inputs.
For external services, prefer a user-approved dry-run or mock; do not request
credentials just to audit definitions. If needed execution is unavailable,
mark that case BLOCKED and preserve the reason.

### 2. Capture Paired Outputs

Use fresh isolated sessions for each configuration:

- `with_skill`: same prompt and fixtures, target skill loaded
- `without_skill`: same prompt and fixtures, target skill not loaded
- `old_skill` (optional): a pinned prior snapshot for regression comparison

Keep tool access, model/configuration, and input context equal except for the
skill. Record deviations. Never reuse a with-skill transcript as the baseline.
For negative cases, test routing from the description without preloading the
target skill; record whether it stayed unloaded and the chosen alternative.

### 3. Grade and Compare

Save actual outputs/transcripts and mark each assertion PASS/FAIL/BLOCKED with
an evidence quotation or artifact path. Compare paired assertion counts,
missing details, and format compliance; specify the measured denominator.
Keep blocked cases out of pass-rate denominators and list them explicitly.

Record time, tokens, cost, and trigger accuracy **only if measured** with a
documented source. Otherwise report **not measured** and omit numeric artifacts.
Do not infer usage from answer length or insert zero/estimated measurements.

### 4. Behavioral Verdict

- **PASS (behavioral, selected cases)**: actual paired outputs meet the declared
  criteria; does not imply all cases passed or the skill improved the baseline
- **NEEDS_WORK (behavioral)**: captured outputs expose gaps or regressions
- **FAIL (behavioral)**: captured outputs fail core criteria
- **NOT_RUN / BLOCKED**: one or both sides were not executed; no paired verdict

Report scope, case IDs, assertion evidence, and baseline differences. A single
passing output cannot establish improvement over a baseline.

## Evidence Layout

Use a user-approved evidence directory; keep temporary trials outside the repo.

```text
<evidence-dir>/iteration-N/
  eval-<id>/with_skill/outputs/response.md
  eval-<id>/without_skill/outputs/response.md
  eval-<id>/grading.json          # actual assertion results + evidence
  summary.md                    # scope, configuration, blocked/not-measured fields
```

Additional benchmark/timing artifacts are optional and require real runs and
measurements. `references/schemas.md` describes artifact shapes, not proof that
a run occurred. Preserve evidence before proposing fixes via `skill-creator`.

## Assertion Rules

Good: `evals.json contains at least 3 cases with unique integer IDs` or
`The answer identifies a missing fixture by path and reports behavioral NOT_RUN`.

Bad: `The output is good`, `The skill feels smart`, or `The answer mentions Jules`.
Every scored assertion needs evidence; definition review does not score behavior.

## Output Format

```text
## Eval Report: <skill-name>
- Mode: static / manual-paired
- Goal and case IDs: <what was checked>
- Structure/schema: PASS/NEEDS_WORK/FAIL (static)
- Definition review: <findings with case IDs>
- Behavioral: NOT_RUN/BLOCKED/PASS/NEEDS_WORK/FAIL (selected cases only)
- Baseline: not run / actual comparison
- Measurements: measured values with sources / not measured
### Assertion Evidence
- <case ID, assertion, result, evidence; definition-only if static>
### Issues and Next Fixes
- <highest-value fix>
### Verdict
<status> (<static or behavioral scope>) — <evidence-based summary>
```

## Bundled Tools

- `scripts/check_structure.py` — standalone static layout/schema/fixture audit
- `references/verification-checklist.md` — domain-specific checklist starter
- `references/evaluating-skills.md` — background for manual output evaluation

## See Also

- `skill-creator` — Author or improve skills from findings
- `intent-classifier` — Route requests to appropriate skills
- `agents-docs/SKILL_EVAL_TIERS.md` — tier mapping; Tier 3 automation is not implemented

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The static checker passed, so the skill works" | Static PASS checks definitions, not behavior; paired trials need actual outputs. |
| "One case is enough" | This template requires at least 3 definitions; behavioral coverage must be reported separately. |
| "I can estimate the missing metrics" | Unmeasured values stay not measured; estimates are not evaluation evidence. |

## Red Flags

- [ ] Declaring behavioral PASS from a static schema check
- [ ] Claiming improvement without an actual isolated baseline
- [ ] Reporting token usage, timing, costs, or trigger accuracy without measurements
- [ ] Tagging a case negative while expecting the target skill to execute
- [ ] Using subjective assertions or verdicts without evidence
