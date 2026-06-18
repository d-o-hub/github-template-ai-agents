# Skill Evaluation Schemas

JSON Schema definitions for skill evaluation data formats.

## evals.json

Test case definitions for evaluating skill behavior.

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt text",
      "expected_output": "Description of what correct output looks like",
      "files": ["path/to/input/file.md"],
      "assertions": [
        "The output includes X",
        "The output is valid JSON"
      ]
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `skill_name` | string | yes | Name matching the skill directory |
| `evals` | array | yes | List of test cases |
| `evals[].id` | integer | yes | Unique test case identifier |
| `evals[].prompt` | string | yes | User prompt to test |
| `evals[].expected_output` | string | yes | Description of expected result |
| `evals[].files` | array | no | File paths relative to skill root |
| `evals[].assertions` | array | yes | Verifiable claims about output |

## grading.json

Per-assertion grading results for a single eval run.

```json
{
  "assertion_results": [
    {
      "text": "The output includes a bar chart image file",
      "passed": true,
      "evidence": "Found chart.png (45KB) in outputs directory"
    },
    {
      "text": "Both axes are labeled",
      "passed": false,
      "evidence": "Y-axis labeled but X-axis has no label"
    }
  ],
  "summary": {
    "passed": 1,
    "failed": 1,
    "total": 2,
    "pass_rate": 0.50
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `assertion_results` | array | yes | Per-assertion pass/fail with evidence |
| `assertion_results[].text` | string | yes | The assertion text being evaluated |
| `assertion_results[].passed` | boolean | yes | Whether the assertion passed |
| `assertion_results[].evidence` | string | yes | Concrete evidence for the pass/fail decision |
| `summary.passed` | integer | yes | Number of passing assertions |
| `summary.failed` | integer | yes | Number of failing assertions |
| `summary.total` | integer | yes | Total assertions |
| `summary.pass_rate` | number | yes | Passed / total (0.0-1.0) |

## timing.json

Token usage and wall-clock duration for a single eval run.

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `total_tokens` | integer | yes | Total tokens consumed during the run |
| `duration_ms` | integer | yes | Wall-clock duration in milliseconds |

## benchmark.json

Aggregated benchmark results comparing with_skill and without_skill.

```json
{
  "run_summary": {
    "with_skill": {
      "pass_rate": { "mean": 0.83, "stddev": 0.06 },
      "time_seconds": { "mean": 45.0, "stddev": 12.0 },
      "tokens": { "mean": 3800, "stddev": 400 }
    },
    "without_skill": {
      "pass_rate": { "mean": 0.33, "stddev": 0.10 },
      "time_seconds": { "mean": 32.0, "stddev": 8.0 },
      "tokens": { "mean": 2100, "stddev": 300 }
    },
    "delta": {
      "pass_rate": 0.50,
      "time_seconds": 13.0,
      "tokens": 1700
    }
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `run_summary.with_skill` | object | yes | Stats for runs with skill loaded |
| `run_summary.without_skill` | object | yes | Stats for baseline runs |
| `run_summary.with_skill.pass_rate.mean` | number | yes | Mean pass rate |
| `run_summary.with_skill.pass_rate.stddev` | number | yes | Standard deviation |
| `run_summary.with_skill.time_seconds.mean` | number | yes | Mean duration in seconds |
| `run_summary.with_skill.tokens.mean` | number | yes | Mean token usage |
| `run_summary.delta.pass_rate` | number | yes | with_skill minus without_skill |
| `run_summary.delta.time_seconds` | number | yes | with_skill minus without_skill |
| `run_summary.delta.tokens` | number | yes | with_skill minus without_skill |

## feedback.json

Human review feedback for eval outputs. Simple key-value map.

```json
{
  "eval-top-months-chart": "The chart is missing axis labels.",
  "eval-clean-missing-emails": ""
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `<eval-name>` | string | yes | Eval directory name as key |
| (value) | string | yes | Human feedback text (empty = looks fine) |

## Validation Rules

- `pass_rate` must be between 0.0 and 1.0
- `duration_ms` must be positive
- `total_tokens` must be non-negative
- `eval_id` values must be unique within an evals.json file
- At least one assertion per eval case
