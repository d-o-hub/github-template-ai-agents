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
  "eval_id": 1,
  "prompt": "User's task prompt",
  "config": "with_skill",
  "assertion_results": [
    {
      "assertion": "The output includes X",
      "text": "Full output text (or excerpt)",
      "passed": true,
      "evidence": "Found 'X' at line 14 of output"
    }
  ],
  "summary": {
    "passed": 2,
    "failed": 1,
    "total": 3,
    "pass_rate": 0.667
  }
}
```

## timing.json

Performance metrics for an eval iteration.

```json
{
  "iteration": 1,
  "eval_id": 1,
  "config": "with_skill",
  "duration_ms": 12500,
  "total_tokens": 4520
}
```

## benchmark.json

Aggregated benchmark results comparing with_skill and without_skill.

```json
{
  "skill_name": "example-skill",
  "iteration": 3,
  "total_cases": 10,
  "runs_per_case": 3,
  "run_summary": {
    "with_skill": {
      "pass_rate": {
        "mean": 0.85,
        "stddev": 0.05
      },
      "time_seconds": {
        "mean": 12.5,
        "stddev": 2.1
      },
      "tokens": {
        "mean": 4520,
        "stddev": 380
      }
    },
    "without_skill": {
      "pass_rate": {
        "mean": 0.62,
        "stddev": 0.12
      },
      "time_seconds": {
        "mean": 15.2,
        "stddev": 3.0
      },
      "tokens": {
        "mean": 5100,
        "stddev": 420
      }
    },
    "delta": {
      "pass_rate": {
        "mean": 0.23,
        "stddev": 0.13
      },
      "time_seconds": {
        "mean": -2.7,
        "stddev": 3.7
      },
      "tokens": {
        "mean": -580,
        "stddev": 570
      }
    }
  }
}
```

## feedback.json

Human review feedback for eval outputs.

```json
{
  "eval_id": 1,
  "reviewer": "human",
  "rating": 4,
  "comments": "The output covered all required steps but missed the edge case for empty input.",
  "suggested_improvements": ["Add handling for empty input case"],
  "assertions_missed": []
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `eval_id` | integer | yes | Test case identifier |
| `reviewer` | string | yes | "human" or "automated" |
| `rating` | integer | no | 1-5 quality rating |
| `comments` | string | yes | Free-text review |
| `suggested_improvements` | array | no | List of actionable suggestions |
| `assertions_missed` | array | no | Assertions the reviewer noticed were missing |

## Validation Rules

- `pass_rate` must be between 0.0 and 1.0
- `duration_ms` must be positive
- `total_tokens` must be non-negative
- `eval_id` values must be unique within an evals.json file
- At least one assertion per eval case
