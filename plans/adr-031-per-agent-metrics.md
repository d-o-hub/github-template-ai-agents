# ADR-031: Per-agent metrics file isolation

## Status

Accepted

## Context

The Post-Task Protocol (AGENTS.md) required agents to append JSON entries to a
single `.agents/metrics.jsonl` file. This caused persistent merge conflicts
between concurrent agent sessions — documented as LESSON-035. The `merge=union`
gitattribute and an automated CI conflict resolver (`metrics-conflict-resolver.yml`)
mitigated but did not eliminate the problem. In July 2026, ADR-030 intentionally
reset the file to a template entry, erasing 50 historical entries.

The fundamental issue: multiple agents appending to the same file create append-
only conflicts that even union-merge cannot fully resolve when entries arrive in
different orders across branches.

## Decision

Replace the single `.agents/metrics.jsonl` with per-agent files in
`.agents/metrics/`:

1. **Directory**: `.agents/metrics/metrics-{agent}.jsonl` — each agent writes
   only to its own file, eliminating cross-agent merge conflicts entirely.
2. **Helper script**: `scripts/log-metric.sh` accepts a JSON payload, validates
   it, extracts the `agent` field, and appends to the correct per-agent file.
   Agent names with `/` or spaces are sanitized to hyphens.
3. **Validation**: `quality_gate.sh` validates all `metrics-*.jsonl` files in
   the directory. `validate-metrics.yml` CI workflow scans with `glob.glob`.
4. **gitattributes**: `merge=union` on `.agents/metrics/metrics-*.jsonl`
   handles same-agent collisions (rare, but possible with concurrent PRs).
5. **Backward compatibility**: `dora-report.yml` concatenates all per-agent
   files before passing them to the DORA tool. `metrics-conflict-resolver.yml`
   updates its safe-file pattern to match the new glob.
6. **Migration**: Old `.agents/metrics.jsonl` removed. Agent guidance files
   (AGENTS.md, GEMINI.md, QWEN.md, CLAUDE.md, JULES.md) updated to reference
   `log-metric.sh`. Documentation (METRICS.md, HARNESS.md) reflects the new
   pattern. `append-abstention-metric.sh` writes to per-agent files.

## Consequences

- **No merge conflicts**: Per-agent isolation eliminates the problem at its root.
- **Simpler CI**: `metrics-conflict-resolver.yml` is less critical; same-agent
  conflicts become the only edge case.
- **Aggregation**: DORA reports must concatenate files (`cat .agents/metrics/*.jsonl`).
  The `dora-report.yml` workflow already handles this.
- **Quality gate**: Now validates all per-agent files instead of one, with
  slightly higher overhead per file.
- **Template hygiene**: New clones get an empty `.agents/metrics/` directory
  (only `.gitkeep`) instead of a template entry — agents start clean.
- **Agent onboarding**: Agents must use `log-metric.sh` instead of direct
  file appends. The script validates JSON and enforces the schema.
