# Evaluating Skill Output Quality

Static validation and behavioral evaluation answer different questions:

| Question | Producer | Verdict vocabulary |
|----------|----------|--------------------|
| Is the skill well-formed and are its cases usable? | `scripts/eval-skills.sh`, `scripts/run-evals.py`, `check_structure.py` | PASS / NEEDS_WORK / FAIL (static) |
| Does the skill change actual agent behavior? | `scripts/behavioral-eval.py` with an operator-supplied adapter | PASS / NEEDS_WORK / FAIL (behavioral), NOT_RUN, BLOCKED |

`scripts/eval-skills.sh` exit 0 is never behavioral evidence.

## Designing Cases

Cases live in `evals/evals.json` and are shared by both paths. A case has:

- **prompt**: a realistic user message.
- **expected_output**: a human-readable description of success.
- **assertions**: concrete, checkable statements about the output.
- **files** (optional): input fixtures that exist under the skill root.
- **bucket** (optional): `explicit`, `implicit`, `contextual`, or `negative`.

If any case declares a bucket, the set must include a `negative` case. Negative
cases test that the skill stays unloaded; they are not keyword traps.

```json
{
  "skill_name": "csv-analyzer",
  "evals": [
    {
      "id": 1,
      "bucket": "explicit",
      "prompt": "I have a CSV of monthly sales data in data/sales_2025.csv. Find the top 3 months by revenue and chart them.",
      "expected_output": "A bar chart of the top 3 months with labeled axes.",
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

## Adapter Contract (`behavioral-eval/v1`)

The runner invokes one adapter process per case and configuration. The adapter
receives one task JSON on stdin:

```json
{
  "schema_version": "behavioral-eval/v1",
  "skill_name": "csv-analyzer",
  "skill_path": ".agents/skills/csv-analyzer",
  "skill_digest": "sha256:...",
  "configuration": "with_skill",
  "workspace": "<artifact-dir>/tasks/case-1/with_skill/workspace",
  "provider": {"name": "my-agent", "model": "my-model", "observed": true},
  "case": {
    "id": 1,
    "bucket": "explicit",
    "prompt": "...",
    "expected_output": "...",
    "assertions": ["..."],
    "fixtures": [{"name": "evals/files/sales_2025.csv", "path": "..."}]
  }
}
```

It must print exactly one result JSON object on stdout:

```json
{
  "schema_version": "behavioral-eval/v1",
  "skill_name": "csv-analyzer",
  "case_id": 1,
  "configuration": "with_skill",
  "status": "graded",
  "assertion_results": [
    {"text": "The chart shows exactly 3 months", "result": "pass", "evidence": "chart.png shows 3 bars"}
  ],
  "activation": {"skill_loaded": true, "selected_skill": "csv-analyzer", "evidence": "routing trace"},
  "duration_ms": 4123,
  "usage": {"total_tokens": 84852, "cost_usd": 0.12, "source": "provider usage API"}
}
```

Required: `schema_version`, `skill_name`, `case_id`, `configuration`, `status`,
and for `status: "graded"` a non-empty `assertion_results` plus `activation`.
`status` is `graded`, `blocked`, or `not_run`; blocked and not-run results need a
`reason`. Each assertion result is `pass`, `fail`, or `blocked` with non-empty
`evidence`. `usage` values may be null; the runner reports them as `unavailable`
and refuses to sum partial measurements.

Prompt text is withheld from stored artifacts unless `--include-prompts` is
passed, and stored text is redacted. Credentials belong in environment
variables read by the adapter, never in the command string.

## Running a Paired Evaluation

```bash
# Inspect the plan: one task per case and configuration.
python3 scripts/behavioral-eval.py plan --skill skill-evaluator --cases 1,8

# Execute both configurations. The adapter command is yours.
BEHAVIORAL_EVAL_ADAPTER="my-adapter --json" \
  python3 scripts/behavioral-eval.py run --skill skill-evaluator \
  --provider-name my-agent --provider-model my-model

# Compare an existing report with the blessed baseline.
python3 scripts/behavioral-eval.py compare --skill skill-evaluator --report <report.json>

# Bless a new floor only after human review of the artifact.
python3 scripts/behavioral-eval.py bless --skill skill-evaluator \
  --report <report.json> --accept --blessed-by <reviewer>
```

The opt-in GitHub workflow (`.github/workflows/behavioral-eval.yml`) runs the
same command via `workflow_dispatch` and uploads the artifact for 7 days. It is
not triggered by pull requests and cannot bless a baseline.

**Exit codes:** `0` all graded cases pass and no blessed floor regressed;
`1` a case failed or a floor regressed; `2` contract/configuration error;
`3` blocked or not run (no adapter, incomplete pair, unobserved activation).

## Artifact Layout

The runner owns this layout; do not hand-write results.

```text
<output-dir>/                      # default: .agents/skills/<skill>-workspace/behavioral-<stamp>/
├── plan.json                     # digests, case ids, task list; no raw prompts
├── report.json                   # machine-readable aggregate + baseline comparison
├── candidate-baseline.json       # only when a blessed baseline exists
└── tasks/
    └── case-<id>/<configuration>/
        ├── task.json             # prompt withheld unless --include-prompts
        ├── fixtures/             # staged copies of the case inputs
        ├── workspace/            # adapter scratch directory
        ├── result.json           # validated, redacted adapter result
        └── adapter.stderr        # bounded, redacted diagnostics (when present)
```

The manual layout (`<skill>-workspace/iteration-N/...`) remains valid for
operator-run trials with no adapter; label it manual so it is not confused with
runner output.

## Result Semantics

- A case is graded only when both configurations produced graded results.
  A missing side is `not_run`, never an inferred pass.
- `with_skill` must observe `skill_loaded: true`. Unobserved or false activation
  blocks the case.
- A `negative` case fails on `skill_loaded: true` (false activation) and is
  blocked when activation is unobserved.
- Blocked and not-run cases are excluded from every denominator and listed with
  reasons. The report names the denominator it used.
- Durations come from the adapter or the runner's wall clock and say which.
  Tokens, cost, and trigger accuracy are reported only with a measurement source.

## Baselines

`<skill>/evals/behavioral-baseline.json` records:

```json
{
  "schema_version": "behavioral-eval/v1",
  "skill_name": "skill-evaluator",
  "blessed_at": "2026-10-28T00:00:00Z",
  "blessed_by": "reviewer-handle",
  "skill_digest": "sha256:...",
  "fixture_digest": "no-fixtures",
  "case_ids": [1, 8],
  "observed": {"with_skill": {"case_pass_rate": 1.0, "assertion_pass_rate": 0.95}},
  "floors": {"with_skill": {"case_pass_rate": 1.0, "assertion_pass_rate": 0.95}}
}
```

`run` never writes this file. `bless` refuses failing, blocked, not-run, or
unattributed runs; without `--accept` it writes `<baseline>.candidate.json` for
review and exits 1 when the floor would change. A measured rate below a blessed
floor is reported as `regression` and exits 1. `skill_revision_changed` and
`fixture_changed` are reported so a delta is not misread as model noise.

`do-harness eval` is a possible backend only through an adapter. Its fixture
format is not verified compatible with `behavioral-eval/v1`; write and test a
mapping before claiming compatibility.

## Analyzing Patterns

- **Remove redundant assertions**: those that always pass in both configurations.
- **Investigate double failures**: either the assertion, the case, or the agent is wrong.
- **Study skill-only successes**: this is where the skill adds clear value.
- **Check negative cases**: a false activation is a routing defect, not a wording tweak.
- **Treat small samples carefully**: one run is not an efficacy claim.

## Human Review Loop

1. Review the artifact and the graded evidence, not just the aggregate.
2. Record actionable feedback with case ids.
3. Improve the skill via `skill-creator`; keep behavioral and static findings separate.
4. Re-run in a new output directory; never reuse a with-skill transcript as the baseline.
5. Bless a new floor only after review, in its own reviewed change.
