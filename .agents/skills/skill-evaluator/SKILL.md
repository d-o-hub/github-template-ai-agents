---
name: skill-evaluator
version: "0.2.10"
description: Reusable skill for evaluating other skills with static structure checks, eval coverage review, and opt-in paired behavioral evaluation. Use this skill when checking a skill, reviewing eval assertions, grading actual outputs, or comparing a skill against a baseline — even if they just say "evaluate this skill" or "check if this skill works". Not for authoring skills (use skill-creator) or routing requests (use intent-classifier).
category: quality
license: MIT
---

# Skill Evaluator

Evaluate local skills with evidence and an explicit scope. Choose **static
audit** or **opt-in paired behavioral evaluation**; never confuse their verdicts.

## When to Use

- Check whether a skill is wired correctly and has usable eval definitions
- Review assertion quality and coverage without executing user prompts
- Grade actual outputs or compare a skill against a no-skill/older baseline
- Identify missing fixtures, weak evals, and unclear routing boundaries

## Required Inputs

```text
SKILL_PATH: absolute or workspace-relative path to the skill directory
MODE: static (default) / paired-behavioral
GOAL: structure / coverage review / behavioral comparison
```

If the user requests behavioral evaluation but execution is unconfigured, report
**status: BLOCKED** or **behavioral: NOT_RUN** with `"unavailable"` metadata, not a static result relabeled as behavior.

## Mode 1: Static Audit

Reads definitions only. Invokes no model, executes no eval prompt, and scores no assertion against an answer. Keyless and offline.

### 1. Structure and Schema

```bash
python3 .agents/skills/skill-evaluator/scripts/check_structure.py --path "$SKILL_PATH"
# or repository-wide static runner
python3 scripts/run-evals.py --skill <skill-name>
```

Requirements: `SKILL.md` exists; `evals/evals.json` exists with matching `skill_name` and `evals` array of at least 3 cases; unique integer `id`s, non-empty `prompt` and `expected_output` strings, and non-empty `assertions` string arrays; optional `files` exist under skill root; optional `bucket` uses `explicit`, `implicit`, `contextual`, or `negative`.

### 2. Static Verdict

- **PASS (static)**: structure/schema/fixtures pass
- **FAIL (static)**: missing/invalid core files or malformed schema

Always report **Behavioral evaluation: NOT_RUN**. A static PASS is never a behavioral PASS or evidence of skill lift.

## Mode 2: Opt-In Paired Behavioral Evaluation

An opt-in workflow for matched paired runs (`with_skill` vs `without_skill`). Default PR checks run static checks only and do not require model keys.

### 1. Execute Paired Evaluation Runner

```bash
# Run paired behavioral evaluation
python3 scripts/run-paired-eval.py --skill <skill-name> [--agent-cmd "<cmd>"]

# Bless current run as authoritative baseline floor
python3 scripts/run-paired-eval.py --skill <skill-name> --bless
```

Alternatively, trigger `.github/workflows/paired-eval.yml` via `workflow_dispatch`.

### 2. Paired Contract & Artifact Fields

Recorded artifact JSON includes:
- `skill.content_digest`: SHA256 of skill definition files
- `skill.fixture_digest`: SHA256 of `evals/evals.json`
- `environment.provider` & `model_id`: observed provider and model or `"unavailable"`
- `metrics`: duration, tokens, cost, or `"unavailable"` when unobserved
- `summary`: pass rates (`with_skill` vs `without_skill`), `skill_lift`, and `baseline_comparison`
- `cases`: per-case status, bucket, and assertion evidence

For negative cases (`bucket: negative`), the `with_skill` arm verifies the target skill stays unloaded. False activation is flagged as a false positive failure.

### 3. Human-Controlled Baseline Blessing

- Blessed baselines reside at `.agents/baselines/<skill-name>.json`.
- Candidate runs compare against the blessed baseline; if pass rate drops or previously passing assertions fail, status is flagged as `REGRESSION` / `FAIL`.
- Runs NEVER silently rewrite the baseline. Blessing requires explicit `--bless` flag or workflow input.

## Output Format

```text
## Eval Report: <skill-name>
- Mode: static / paired-behavioral
- Provider / Model: <provider> / <model_id> or unavailable
- Structure/schema: PASS / FAIL (static)
- Behavioral: PASS / REGRESSION / FAIL / BLOCKED (paired)
- Baseline Delta: <delta> vs blessed floor
- Artifact Digests: <content_digest> / <fixture_digest>
```

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The static checker passed, so the skill works" | Static PASS checks definitions, not behavior; paired evaluation needs actual model output. |
| "I can estimate missing model metrics" | Unmeasured tokens or cost stay "unavailable"; estimated metrics are not evaluation evidence. |
| "New runs can auto-update the baseline" | Baseline blessing requires explicit human review and `--bless`. |

## Red Flags

- [ ] Declaring behavioral PASS from a static schema check
- [ ] Claiming improvement without an actual isolated baseline
- [ ] Fabricating token usage, costs, or model metadata when unobserved
- [ ] Silently overwriting blessed baseline floors
