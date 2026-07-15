# Metrics

## Task metrics (`.agents/metrics.jsonl`)

Append one JSON object per completed agent task (post-task protocol).

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

- Keep the working file small (prefer under a few hundred lines).
- Archive older entries under `agents-docs/metrics-archive/` when rotating.
- Template clones should not inherit years of maintainer telemetry; ship only an
  example line (or empty file) and start fresh.

## Related

- Monthly DORA: `dora-report` skill / `agents-docs/dora-reports/`
- Conflict automation: `metrics-conflict-resolver` workflow (optional for adopters)
