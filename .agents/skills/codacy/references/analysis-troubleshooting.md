# Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `Tool X not found` / tool in `unavailable` | Tool binary not installed | Run with `--install-dependencies`; if that fails, install the tool manually |
| Analysis produces no results | No tools enabled or no matching files | Re-run `codacy-analysis init` or check `.codacy/codacy.config.json` has tools configured |
| Wrong tools detected | Language detection missed files | Use `--tool <id>` to force specific tools |
| Tool timeout | Analysis takes too long on large codebase | Increase `--tool-timeout <ms>` (default 600000) |
| Config outdated after adding new languages | Init was run before new files existed | Run `codacy-analysis update-config` |
| `Config already exists` on init | `.codacy/codacy.config.json` already present | Use `update-config` instead, or delete `.codacy/codacy.config.json` first |
| Remote init fails with auth error | Missing or invalid API token | Run `codacy-analysis login` or set `CODACY_API_TOKEN` |
| Permission errors on `~/.codacy/` | Directory ownership mismatch | Check permissions: `ls -la ~/.codacy/` |
| Inspect shows tool as `bundled` but it fails | Bundled library tool has dependency issue | Check `--log-level debug` output; may need `npm rebuild` |
| Different results than Codacy Cloud | Different tool versions or pattern config | Use `init --remote` to sync config; check tool versions in inspect output |

### Reading logs

Logs are written to `~/.codacy/logs/` in JSON lines format:

```bash

# View latest log

cat ~/.codacy/logs/*.log | jq .

# Filter for errors

cat ~/.codacy/logs/*.log | jq 'select(.level == "error")'

```

Use `--log-level debug` for the most verbose output when troubleshooting tool issues.
