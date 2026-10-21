# Evaluating Skill Output Quality

## Designing Test Cases

Store test cases in `evals/evals.json` inside your skill directory. A test case contains:
- **Prompt**: realistic user task message.
- **Expected output**: human-readable description of success.
- **Bucket** (optional): taxonomy tag (`explicit`, `implicit`, `contextual`, `negative`).
- **Files** (optional): relative paths to input fixtures under the skill directory.
- **Assertions**: verifiable statements about what the output must achieve.

### evals/evals.json Example

```json
{
  "skill_name": "csv-analyzer",
  "evals": [
    {
      "id": 1,
      "bucket": "explicit",
      "prompt": "I have a CSV of monthly sales data in data/sales_2025.csv. Can you find the top 3 months by revenue and make a bar chart?",
      "expected_output": "A bar chart image showing the top 3 months by revenue, with labeled axes.",
      "files": ["evals/files/sales_2025.csv"],
      "assertions": [
        "The output includes a bar chart image file",
        "The chart shows exactly 3 months"
      ]
    },
    {
      "id": 2,
      "bucket": "negative",
      "prompt": "Fix the formatting of this Dockerfile.",
      "expected_output": "Out-of-scope task; csv-analyzer stays unloaded.",
      "assertions": [
        "Target skill csv-analyzer stays unloaded for Dockerfile task"
      ]
    }
  ]
}
```

## Static Audit vs Opt-In Paired Behavioral Evaluation

Static validation (`scripts/run-evals.py` or `check_structure.py`) checks file existence, schema validity, and fixture paths. It is keyless, offline, and runs in default PR checks. A static PASS does NOT prove model behavior.

Paired behavioral evaluation runs matched cases with the skill enabled (`with_skill`) and disabled (`without_skill`) using `scripts/run-paired-eval.py` or `.github/workflows/paired-eval.yml`.

## Automated Paired Evaluation Runner

### Command Invocation

```bash
# Run paired behavioral evaluation
python3 scripts/run-paired-eval.py --skill csv-analyzer [--agent-cmd "<cmd>"]

# Bless current run output as baseline floor
python3 scripts/run-paired-eval.py --skill csv-analyzer --bless
```

### Paired Evaluation Output Schema

Output JSON generated at `reports/paired-eval/<skill-name>-result.json`:

```json
{
  "version": "1.0.0",
  "evaluation_type": "paired_behavioral",
  "timestamp": "2026-10-21T12:00:00Z",
  "skill": {
    "name": "csv-analyzer",
    "content_digest": "sha256:...",
    "fixture_digest": "sha256:..."
  },
  "environment": {
    "provider": "do-harness",
    "model_id": "claude-3-5-sonnet-20241022",
    "agent_cmd": "..."
  },
  "summary": {
    "status": "PASS",
    "total_cases": 2,
    "passed_cases": 2,
    "failed_cases": 0,
    "blocked_cases": 0,
    "pass_rate_with_skill": 1.0,
    "pass_rate_without_skill": 0.5,
    "skill_lift": 0.5,
    "baseline_comparison": {
      "blessed_baseline_found": true,
      "blessed_pass_rate": 1.0,
      "delta_from_baseline": 0.0,
      "regression_detected": false
    }
  },
  "metrics": {
    "duration_ms": "unavailable",
    "total_tokens": "unavailable",
    "total_cost_usd": "unavailable"
  },
  "cases": []
}
```

## Baseline Comparison & Blessing

- Blessed baselines are stored in `.agents/baselines/<skill-name>.json`.
- Candidate evaluation runs automatically compare results against the blessed baseline.
- If the pass rate drops or previously passing assertions fail, the status is flagged as `REGRESSION` / `FAIL`.
- A new run NEVER silently rewrites the baseline. Raising or blessing a baseline floor requires explicit `--bless` or workflow parameter.
