---
name: skill-evaluator
version: "0.2.11"
description: Reusable skill for evaluating other skills with static structure checks, eval coverage review, and manual paired behavioral trials. Use this skill when checking a skill, reviewing eval assertions, grading actual outputs, or comparing a skill against a baseline — even if they just say "evaluate this skill" or "check if this skill works". Not for authoring skills (use skill-creator) or routing requests (use intent-classifier).
category: quality
license: MIT
---

# Skill Evaluator

Evaluate local skills with evidence and an explicit scope. Choose **static
audit** or **paired behavioral evaluation** (opt-in runner or manual protocol);
never confuse their verdicts.

## When to Use

- Check whether a skill is wired correctly and has usable eval definitions
- Review assertion quality and coverage without executing user prompts
- Grade actual outputs or compare a skill against a no-skill/older baseline
- Identify missing fixtures, weak evals, and unclear routing boundaries

## Required Inputs

```text
SKILL_PATH: absolute or workspace-relative path to the skill directory
MODE: static (default) / paired (runner or manual)
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

## Mode 2: Paired Behavioral Evaluation

Behavioral evidence requires actual paired runs. Use the opt-in runner when an
adapter exists; it is **not** part of the default quality gate and needs no
model credentials in CI.

### 1. Prepare

Run the static audit first. Choose representative case IDs and define grading
criteria before seeing answers. Build the plan and confirm pairing:

```bash
python3 scripts/behavioral-eval.py plan --skill "$SKILL_NAME" --cases 1,8
```

Prompts are withheld from stored artifacts unless `--include-prompts` is passed.

### 2. Capture Paired Outputs

Supply an adapter command that prints one `behavioral-eval/v1` result JSON per
task on stdout. Task payloads arrive on stdin with `configuration`
(`with_skill` / `without_skill`), the case prompt/assertions, and staged
fixtures. Keep tool access and model settings equal except for the skill.

```bash
BEHAVIORAL_EVAL_ADAPTER="my-adapter --json" \
python3 scripts/behavioral-eval.py run --skill "$SKILL_NAME" \
  --provider-name <agent> --provider-model <model>
```

Never reuse a with-skill transcript as the baseline. Negative cases report
`activation.skill_loaded`: `true` is a false activation and fails the case,
while `null` blocks it.

### 3. Grade and Compare

Every graded result needs assertion evidence (`text`, `result`, `evidence`) and
activation evidence. The runner aggregates, excludes blocked/not-run cases from
denominators, and compares against `<skill>/evals/behavioral-baseline.json`.

Exit codes: `0` pass, `1` case failure or baseline regression, `2` contract or
configuration error, `3` blocked/not run. Malformed adapter output is exit 2 and
is never scored.

`duration_ms` is adapter- or runner-measured and labeled. Tokens, cost, and
trigger accuracy appear only when the adapter reported them; otherwise they are
`unavailable`. Do not estimate them.

### 4. Baseline Blessing

`run` never writes a baseline. After reviewing the artifact, bless explicitly:

```bash
python3 scripts/behavioral-eval.py bless --skill "$SKILL_NAME" \
  --report <artifact>/report.json --accept --blessed-by <reviewer>
```

`bless` refuses failing, blocked, not-run, or unattributed runs. Without
`--accept` it writes `<baseline>.candidate.json` and exits 1 when the floor would
change. A measured rate below a blessed floor is a visible regression.

### 5. Manual Fallback

With no adapter, run the same cases in isolated sessions and grade the captured
outputs by hand. Mark BLOCKED/NOT_RUN when isolation or provider metadata is
missing. `do-harness eval` is a possible backend only through an adapter; its
fixture format is not verified compatible with this contract.

### Behavioral Verdict

- **PASS (behavioral, selected cases)**: actual paired outputs meet the declared
  criteria; does not imply all cases passed or the skill improved the baseline
- **NEEDS_WORK (behavioral)**: captured outputs expose gaps or regressions
- **FAIL (behavioral)**: captured outputs fail core criteria
- **NOT_RUN / BLOCKED**: one or both sides were not executed; no paired verdict

Report scope, case IDs, assertion evidence, and baseline differences. A single
passing output cannot establish improvement over a baseline.

## Evidence Layout

Runner-owned layout; do not hand-write result files.

```text
<skill>-workspace/behavioral-<stamp>/
  plan.json                  # digests and tasks; prompts withheld by default
  report.json                # aggregate + baseline comparison
  candidate-baseline.json    # only when a blessed baseline exists
  tasks/case-<id>/<configuration>/
    task.json                # redacted; prompt withheld unless requested
    fixtures/                # staged case inputs
    workspace/               # adapter scratch directory
    result.json              # validated, redacted result
    adapter.stderr           # bounded diagnostics, when present
```

Manual trials may keep `<skill>-workspace/iteration-N/` (hand-authored), but
label them manual so they are not confused with runner output. Artifacts are
redacted and prompt capture is opt-in; keep temporary trials out of the repo and
retain only what review needs.

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
- `references/evaluating-skills.md` — adapter contract, artifacts, baselines
- `scripts/behavioral-eval.py` (repo-level) — opt-in paired runner; no model call
  of its own, no default-gate dependency

## See Also

- `skill-creator` — Author or improve skills from findings
- `intent-classifier` — Route requests to appropriate skills
- `agents-docs/SKILL_EVAL_TIERS.md` — tier mapping; Tier 3 is the opt-in adapter runner

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The static checker passed, so the skill works" | Static PASS checks definitions, not behavior; paired trials need actual outputs. |
| "One case is enough" | This template requires at least 3 definitions; behavioral coverage must be reported separately. |
| "I can estimate the missing metrics" | Unmeasured values stay not measured; estimates are not evaluation evidence. |
| "The runner exited 0, so the skill is effective" | Exit 0 covers selected cases only; cite scope, denominator, and baseline delta. |
| "I can raise the baseline to make it green" | Floors change only through an attributable, reviewed bless; a drop is a regression. |
| "Activation was not observed, so it probably loaded" | Unobserved activation blocks the case; inference is not evidence. |

## Red Flags

- [ ] Declaring behavioral PASS from a static schema check
- [ ] Claiming improvement without an actual isolated baseline
- [ ] Reporting token usage, timing, costs, or trigger accuracy without measurements
- [ ] Tagging a case negative while expecting the target skill to execute
- [ ] Using subjective assertions or verdicts without evidence
- [ ] Blessing a baseline without review, or letting a run write it automatically
- [ ] Counting a missing without-skill side as an implicit pass
