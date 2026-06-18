# A/B Comparator Agent

Blind comparison of two skill versions to determine which produces higher quality outputs.

## Input Format

```json
{
  "version_a": {"path": "...", "description": "Original description"},
  "version_b": {"path": "...", "description": "Revised description"},
  "eval_cases": [
    {"id": 1, "prompt": "...", "assertions": [...]}
  ],
  "outputs": {
    "1": {"a": "output from version A", "b": "output from version B"}
  }
}
```

## Grading Process

### Step 1: Anonymize

Remove all identifying information about which output belongs to which version. Label outputs as "Output 1" and "Output 2" randomly. Record the mapping separately.

### Step 2: Holistic Quality Scoring

For each eval case, score each anonymized output on:

| Criterion | Weight | Description |
|-----------|--------|-------------|
| Correctness | 40% | Does the output satisfy the core request? |
| Completeness | 25% | Does it cover all aspects of the prompt? |
| Clarity | 15% | Is it well-structured and easy to follow? |
| Conciseness | 10% | Does it avoid unnecessary verbosity? |
| Actionability | 10% | Can the user act on the output directly? |

Score each criterion 1-5, then compute weighted total.

### Step 3: Determine Winner

- Score each output across all eval cases.
- Average scores per output.
- The output with the higher average wins.
- If scores are within 0.5 points, declare a tie.

### Step 4: Explain Why

For each case where one output clearly outperforms the other, explain what specific aspects made the difference. Focus on concrete differences in structure, detail, accuracy, or usability.

## Output Format

```json
{
  "winner": "a" | "b" | "tie",
  "confidence": "high" | "medium" | "low",
  "scores": {
    "a": {"avg": 4.2, "per_case": {...}},
    "b": {"avg": 3.8, "per_case": {...}}
  },
  "analysis": [
    {
      "eval_id": 1,
      "winner": "a",
      "reason": "Output A provided step-by-step instructions with code examples; Output B only described the concept."
    }
  ]
}
```

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can tell which version this is from the output" | Re-randomize. If pattern persists, the versions are too different to blind. |
| "Both are good, it's a tie" | Check if one is measurably better on correctness or completeness. Ties should be rare. |
| "Version A is clearly better" | Prove it with per-criterion scores, not overall impression. |

## Red Flags

- [ ] Recognizing version from formatting artifacts instead of quality
- [ ] Scoring based on preference for one style over another
- [ ] Declaring winner without per-criterion justification
- [ ] Ignoring correctness failures because the output "looks good"
