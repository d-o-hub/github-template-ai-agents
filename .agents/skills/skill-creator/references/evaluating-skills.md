# Evaluating Skill Output Quality

## Designing Test Cases

Store in `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": [],
      "assertions": ["The output includes X"]
    }
  ]
}
```

**Tips:**
- Start with 2-3 test cases, expand after first round
- Vary phrasing: formal, casual, terse, context-heavy
- Cover edge cases: malformed input, unusual requests, ambiguous instructions
- Use realistic context: file paths, column names, personal details

## Running Evals

Run each test case **twice**: once with the skill, once without (or with previous version).

**Workspace structure:**

```
<skill-name>-workspace/
└── iteration-1/
    ├── eval-top-months-chart/
    │   ├── with_skill/
    │   │   ├── outputs/
    │   │   ├── timing.json
    │   │   └── grading.json
    │   └── without_skill/
    │       ├── outputs/
    │       ├── timing.json
    │       └── grading.json
    └── benchmark.json
```

## Writing Assertions

Verifiable statements about output:

- **Good**: "The output file is valid JSON", "The chart has labeled axes", "The report includes at least 3 recommendations"
- **Bad**: "The output is good" (too vague), "Uses exactly the phrase X" (too brittle)

Not everything needs an assertion. Writing style and visual design are better caught during human review.

## Grading Outputs

Evaluate each assertion against actual outputs. Save to `grading.json`:

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
      "evidence": "Y-axis labeled 'Revenue ($)' but X-axis has no label"
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

**Grading principles:**
- Require concrete evidence for PASS — don't give benefit of the doubt
- Use scripts for mechanical checks (valid JSON, file exists, row count)
- Use LLMs for subjective checks (content quality, organization)
- Review assertions themselves: remove ones that always pass or always fail

## Timing Data

Capture `total_tokens` and `duration_ms` from task completion notifications. Save to `timing.json`:

```json
{
  "total_tokens": 84852,
  "duration_ms": 23332
}
```

## Aggregating Results

Compute `benchmark.json` alongside eval directories:

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

The `delta` tells you what the skill costs (time, tokens) and what it buys (higher pass rate).

## Analyzing Patterns

After computing benchmarks, look for:

- **Always-pass assertions**: Remove or replace — they don't discriminate between with/without skill
- **Always-fail assertions**: Either the assertion is broken or the test case is too hard — fix before next iteration
- **Pass-with-skill, fail-without**: This is where the skill adds value — understand why
- **High stddev**: Instructions may be ambiguous — add examples or more specific guidance
- **Time/token outliers**: Read execution transcripts to find bottlenecks

## Human Review

Assertion grading catches objective issues. Human review catches:
- Technically correct but unhelpful output
- Wrong approach for the task
- Issues not anticipated in assertions

Save feedback to `feedback.json`:

```json
{
  "eval-top-months-chart": "The chart is missing axis labels and months are alphabetical instead of chronological.",
  "eval-clean-missing-emails": ""
}
```

Empty feedback = output looked fine. Focus improvements on test cases with specific complaints.

## Iterating on the Skill

1. Give eval signals (failed assertions, human feedback, execution transcripts) + current SKILL.md to an LLM
2. Ask it to propose changes
3. Apply changes
4. Rerun all test cases in `iteration-<N+1>/`
5. Grade and aggregate
6. Review with human
7. Repeat until satisfied or no meaningful improvement

**Key principles:**
- Generalize from feedback — the skill will be used across many prompts, not just test cases
- Keep the skill lean — fewer, better instructions outperform exhaustive rules
- Explain the WHY — reasoning-based instructions work better than rigid directives
- Bundle repeated work — if every run independently writes a helper script, bundle it in `scripts/`

## Test Case Guidelines

- **Realism**: Add file paths, personal context, specific details, casual language
- **Variety**: Mix formal/casual, terse/context-heavy, single-step/multi-step
- **Near-misses**: Include queries that share keywords but need something different

## Description Optimization

After the skill is working well, optimize the frontmatter:

1. **Generate eval queries** — 20 queries (8-10 should-trigger, 8-10 should-not-trigger)
2. **Run optimization loop**:

```bash
python -m scripts.run_loop \
  --eval-set <path/to/queries.json> \
  --skill-path <path/to/skill> \
  --model <current-model> \
  --max-iterations 5 \
  --verbose
```

3. **Apply best description** — Update SKILL.md frontmatter
