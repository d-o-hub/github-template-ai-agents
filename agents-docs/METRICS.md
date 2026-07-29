# Metrics

## Task metrics (`.agents/metrics/`)

Agents append one JSON object per completed task using `./scripts/log-metric.sh '<json>'`.
Entries go to per-agent files in `.agents/metrics/metrics-{agent}.jsonl`, eliminating
merge conflicts between concurrent agent sessions (LESSON-035).

### Helper script

```bash
./scripts/log-metric.sh '{"timestamp":"2026-07-15T12:00:00Z","agent":"buffy","task":"fix CI","skill_used":"shell-script-quality","status":"completed","tokens_used":1200,"duration_seconds":60}'
```

The script extracts the `agent` field to determine the target file.

Suggested fields:

```json
{
  "timestamp": "2026-07-15T12:00:00Z",
  "agent": "claude|opencode|gemini|other",
  "task": "short description",
  "skill_used": "skill-name-or-none",
  "status": "completed|failed|abstained",
  "tokens_used": 0,
  "duration_seconds": 0,
  "notes": "optional"
}
```

## Rotation

- Keep per-agent files small (prefer under a few hundred lines each).
- Archive older entries under `agents-docs/metrics-archive/` when rotating.
- Template clones should not inherit years of maintainer telemetry; delete
  `.agents/metrics/` entries and start fresh.

## Aggregation

To aggregate across all agents for DORA reports:

```bash
cat .agents/metrics/*.jsonl | sort  # all entries merged
```

The `dora-report` skill and `quality_gate.sh` scan all `metrics-*.jsonl` files.

## Related

- Monthly DORA: `dora-report` skill / `agents-docs/dora-reports/`
- Conflict automation: `metrics-conflict-resolver` workflow (optional for adopters)
