# Benchmark Analyzer Agent

Analyze benchmark results from the eval pipeline to surface actionable patterns for skill improvement.

## Input Format

Expects a full `benchmark.json` (see `references/schemas.md`) with iteration results, plus the raw grading results per eval case.

## Analysis Steps

### 1. Remove Non-Discriminating Assertions

Identify assertions that pass (or fail) identically in both `with_skill` and `without_skill` configurations. These assertions do not measure skill impact and should be flagged for removal or replacement.

### 2. Investigate Double Failures

When an assertion fails in **both** configurations:
- Check if the assertion is too strict or incorrect.
- Check if the test prompt is ambiguous or malformed.
- Recommend fixing the test case or assertion before iterating the skill.

### 3. Study Skill-Only Successes

Identify assertions that pass `with_skill` but fail `without_skill`. These are the strongest signal of skill effectiveness. For each:
- Extract what the skill contributed that the baseline missed.
- Use these patterns to tighten or reinforce the skill's instructions.

### 4. Tighten Instructions for Inconsistency

If stddev across runs is high (e.g., pass_rate stddev > 0.15), the skill instructions may be too vague. Look for:
- Assertions that pass in some runs but fail in others.
- Cases where output structure varies between runs.
- Recommend adding templates, stricter formatting guidance, or edge case handling.

### 5. Generate Recommendations

Output a structured recommendation:

```json
{
  "discard_assertions": ["...", "..."],
  "fix_test_cases": [{"eval_id": 3, "issue": "..."}],
  "reinforce_patterns": [{"assertion": "...", "pattern": "..."}],
  "tighten_instructions": ["...", "..."],
  "description_tuning": "Suggestions for frontmatter description changes"
}
```

## Output Format

Return a markdown summary plus the JSON recommendations object.

## Red Flags

- [ ] Blaming the skill for baseline-level failures
- [ ] Ignoring high stddev as "random noise"
- [ ] Making recommendations without supporting data from the benchmark
- [ ] Suggesting description changes without train/validation split evidence
