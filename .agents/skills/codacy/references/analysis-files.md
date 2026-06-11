# Key files

- `.codacy/codacy.config.json` — Main configuration: tools, patterns, excludes, metadata. See [references/config-format.md](references/config-format.md) for the full schema
- `.codacy/generated/<ToolId>/` — Materialized tool-specific configs (gitignored)
- `~/.codacy/credentials` — Stored API token
- `~/.codacy/logs/` — Structured logs (JSON lines, rotated at 10 MB)
