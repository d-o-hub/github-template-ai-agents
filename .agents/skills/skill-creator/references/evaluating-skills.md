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

## Running Evals

Run each test case **twice**: once with the skill, once without.

**Workspace structure:**
```
<skill-name>-workspace/
└── iteration-1/
    ├── eval-0/
    │   ├── with_skill/outputs/
    │   ├── without_skill/outputs/
    │   └── eval_metadata.json
    └── timing.json
```

## Writing Assertions

Verifiable statements about output:
- Must be programmatically verifiable or observable
- Examples: "The output file is valid JSON", "The chart has labeled axes"
- Avoid vague assertions like "The output is good"

## Grading Outputs

- Evaluate each assertion against actual outputs
- Record **PASS** or **FAIL** with concrete evidence
- Use LLMs for subjective checks, scripts for mechanical checks

## Aggregating Results

Compute in `benchmark.json`:
- Pass rate (mean, stddev)
- Time in seconds (mean, stddev)
- Tokens (mean, stddev)
- Delta between with/without skill

## Analyzing Patterns

- Remove assertions that always pass in both configurations
- Investigate assertions that always fail in both configurations
- Study assertions that pass with skill but fail without
- Check for inconsistent results (high stddev)

## Human Review

- Human reviewer catches issues not covered by assertions
- Record specific feedback in `feedback.json`
- Focus improvements on test cases with specific complaints

## Test Case Guidelines

- **Realism**: Add file paths, personal context, specific details, casual language
- **Variety**: Mix formal/casual, terse/context-heavy, single-step/multi-step
- **Near-misses**: Include queries that share keywords but need something different

## Description Optimization

After the skill is working well, optimize the frontmatter:

1. **Generate eval queries** - 20 queries (8-10 should-trigger, 8-10 should-not-trigger)
2. **Run optimization loop**:
```bash
python -m scripts.run_loop \
  --eval-set <path/to/queries.json> \
  --skill-path <path/to/skill> \
  --model <current-model> \
  --max-iterations 5 \
  --verbose
```
3. **Apply best description** - Update SKILL.md frontmatter