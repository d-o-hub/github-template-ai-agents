# Evaluation Artifact JSON Schemas

This document defines formal JSON Schema (draft-07) definitions for all evaluation
artifacts used in the skill evaluation workflow. Each schema is accompanied by a
concrete example.

---

## evals.json

Defines the test cases for a skill evaluation.

**Schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "EvalsFile",
  "type": "object",
  "properties": {
    "skill_name": {
      "type": "string",
      "description": "Name of the skill being evaluated"
    },
    "evals": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": {
            "type": "integer",
            "description": "Unique eval case identifier"
          },
          "prompt": {
            "type": "string",
            "description": "Realistic user prompt for the eval run"
          },
          "expected_output": {
            "type": "string",
            "description": "Human-readable description of expected output"
          },
          "files": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Paths to input files the eval requires"
          },
          "assertions": {
            "type": "array",
            "items": { "type": "string" },
            "description": "Verifiable statements about the output"
          }
        },
        "required": ["id", "prompt", "expected_output", "assertions"]
      }
    }
  },
  "required": ["skill_name", "evals"]
}
```

**Example:**

```json
{
  "skill_name": "csv-analyzer",
  "evals": [
    {
      "id": 1,
      "prompt": "I have a CSV of monthly sales data in data/sales_2025.csv. Can you find the top 3 months by revenue and make a bar chart?",
      "expected_output": "A bar chart image showing the top 3 months by revenue, with labeled axes and values.",
      "files": ["evals/files/sales_2025.csv"],
      "assertions": [
        "The output includes a bar chart image file",
        "The chart shows exactly 3 months",
        "Both axes are labeled"
      ]
    }
  ]
}
```

---

## grading.json

Records per-assertion pass/fail results for a single eval run.

**Schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "GradingFile",
  "type": "object",
  "properties": {
    "assertion_results": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "text": {
            "type": "string",
            "description": "The assertion text being evaluated"
          },
          "passed": {
            "type": "boolean",
            "description": "Whether the assertion passed"
          },
          "evidence": {
            "type": "string",
            "description": "Concrete evidence supporting the pass/fail decision"
          }
        },
        "required": ["text", "passed", "evidence"]
      }
    },
    "summary": {
      "type": "object",
      "properties": {
        "passed": { "type": "integer" },
        "failed": { "type": "integer" },
        "total": { "type": "integer" },
        "pass_rate": { "type": "number" }
      },
      "required": ["passed", "failed", "total", "pass_rate"]
    }
  },
  "required": ["assertion_results", "summary"]
}
```

**Example:**

```json
{
  "assertion_results": [
    {
      "text": "The output includes a bar chart image file",
      "passed": true,
      "evidence": "Found chart.png (45KB) in outputs directory"
    },
    {
      "text": "The chart shows exactly 3 months",
      "passed": true,
      "evidence": "Chart contains 3 bars labeled Jan, Feb, Mar"
    },
    {
      "text": "Both axes are labeled",
      "passed": false,
      "evidence": "X-axis labeled 'Month' but Y-axis has no label"
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

---

## timing.json

Captures token usage and wall-clock duration for a single eval run.

**Schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "TimingFile",
  "type": "object",
  "properties": {
    "total_tokens": {
      "type": "integer",
      "description": "Total tokens consumed during the run"
    },
    "duration_ms": {
      "type": "integer",
      "description": "Wall-clock duration in milliseconds"
    }
  },
  "required": ["total_tokens", "duration_ms"]
}
```

**Example:**

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332
}
```

---

## benchmark.json

Aggregates statistics across all eval cases for a single iteration, comparing
with_skill vs without_skill configurations.

**Schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "BenchmarkFile",
  "type": "object",
  "properties": {
    "run_summary": {
      "type": "object",
      "properties": {
        "with_skill": {
          "type": "object",
          "description": "Statistics for runs with the skill loaded",
          "properties": {
            "pass_rate": {
              "type": "object",
              "properties": {
                "mean": { "type": "number" },
                "stddev": { "type": "number" }
              },
              "required": ["mean", "stddev"]
            },
            "time_seconds": {
              "type": "object",
              "properties": {
                "mean": { "type": "number" },
                "stddev": { "type": "number" }
              },
              "required": ["mean", "stddev"]
            },
            "tokens": {
              "type": "object",
              "properties": {
                "mean": { "type": "number" },
                "stddev": { "type": "number" }
              },
              "required": ["mean", "stddev"]
            }
          },
          "required": ["pass_rate", "time_seconds", "tokens"]
        },
        "without_skill": {
          "type": "object",
          "description": "Statistics for baseline runs without the skill",
          "properties": {
            "pass_rate": {
              "type": "object",
              "properties": {
                "mean": { "type": "number" },
                "stddev": { "type": "number" }
              },
              "required": ["mean", "stddev"]
            },
            "time_seconds": {
              "type": "object",
              "properties": {
                "mean": { "type": "number" },
                "stddev": { "type": "number" }
              },
              "required": ["mean", "stddev"]
            },
            "tokens": {
              "type": "object",
              "properties": {
                "mean": { "type": "number" },
                "stddev": { "type": "number" }
              },
              "required": ["mean", "stddev"]
            }
          },
          "required": ["pass_rate", "time_seconds", "tokens"]
        },
        "delta": {
          "type": "object",
          "description": "Difference (with_skill - without_skill) for each metric",
          "properties": {
            "pass_rate": { "type": "number" },
            "time_seconds": { "type": "number" },
            "tokens": { "type": "number" }
          },
          "required": ["pass_rate", "time_seconds", "tokens"]
        }
      },
      "required": ["with_skill", "without_skill", "delta"]
    }
  },
  "required": ["run_summary"]
}
```

**Example:**

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

---

## feedback.json

Records human review notes for each eval case in an iteration.

**Schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "FeedbackFile",
  "type": "object",
  "description": "Map of eval case identifiers to human feedback notes",
  "additionalProperties": {
    "type": "string"
  }
}
```

**Example:**

```json
{
  "eval-top-months-chart": "The chart is missing axis labels. Update the prompt to require axis labels explicitly.",
  "eval-clean-missing-emails": ""
}
```

---

## eval_metadata.json

Captures the eval case definition alongside iteration and timing context. Generated
at the start of each iteration run.

**Schema:**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "EvalMetadataFile",
  "type": "object",
  "properties": {
    "eval_id": { "type": "integer" },
    "prompt": { "type": "string" },
    "expected_output": { "type": "string" },
    "assertions": {
      "type": "array",
      "items": { "type": "string" }
    },
    "iteration": { "type": "string" },
    "timestamp": { "type": "string", "format": "date-time" }
  },
  "required": ["eval_id", "prompt", "expected_output", "assertions", "iteration", "timestamp"]
}
```

**Example:**

```json
{
  "eval_id": 1,
  "prompt": "I have a CSV of monthly sales data in data/sales_2025.csv. Can you find the top 3 months by revenue and make a bar chart?",
  "expected_output": "A bar chart image showing the top 3 months by revenue, with labeled axes and values.",
  "assertions": [
    "The output includes a bar chart image file",
    "The chart shows exactly 3 months",
    "Both axes are labeled"
  ],
  "iteration": "iteration-01",
  "timestamp": "2026-06-18T12:00:00Z"
}
```
