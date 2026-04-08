# Evaluating Skills Spec

Condensed reference for evaluating skills according to the agentskills.io specification.

## Workspace Layout

Organize eval results in a workspace directory alongside your skill directory.

```text
<skill-name>/
├── SKILL.md
└── evals/
    └── evals.json

<skill-name>-workspace/
└── iteration-N/
    ├── eval-<id>/
    │   ├── with_skill/
    │   │   ├── outputs/       # Files produced by the run
    │   │   ├── timing.json    # Tokens and duration
    │   │   └── grading.json   # Assertion results
    │   └── without_skill/     # (or old_skill/ for snapshot comparison)
    │       ├── outputs/
    │       ├── timing.json
    │       └── grading.json
    ├── benchmark.json         # Aggregated statistics
    └── feedback.json          # Human review notes
```

## Artifact Schemas

### timing.json
Captured per run.
```json
{
  "total_tokens": 84852,
  "duration_ms": 23332
}
```

### grading.json
Structured assertion results with evidence.
```json
{
  "assertion_results": [
    {
      "text": "The output includes a bar chart image file",
      "passed": true,
      "evidence": "Found chart.png (45KB) in outputs directory"
    }
  ],
  "summary": {
    "passed": 3,
    "failed": 1,
    "total": 4,
    "pass_rate": 0.75
  }
}
```

### benchmark.json
Aggregated across all evals in an iteration.
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

### feedback.json
Human review notes per eval case.
```json
{
  "eval-case-id": "Actionable feedback message",
  "another-eval-id": ""
}
```

## Baseline Comparison
Always compare the skill's performance against a baseline:
- `without_skill`: Same prompt, no skill loaded.
- `old_skill`: Same prompt, previous snapshot of the skill.
