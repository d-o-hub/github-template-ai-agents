# Plan: Add CLI Interface (`agent-toolkit`)

## Summary

Add a unified Bash CLI (`agent-toolkit`) that wraps all existing scripts under a single command with subcommands, help text, and colored output.

## Design

**Entry point**: `bin/agent-toolkit` (symlinked from `scripts/agent-toolkit.sh`)

### Commands

| Command | Wraps | Description |
|---------|-------|-------------|
| `agent-toolkit setup` | `bootstrap.sh` | First-time setup |
| `agent-toolkit doctor` | `doctor.sh` | Environment diagnostics |
| `agent-toolkit quality` | `quality_gate.sh` | Run quality gate |
| `agent-toolkit validate [all\|skills\|workflows\|links\|hooks\|config\|shas\|adr]` | `validate-*.sh` | Validation (defaults to `all`) |
| `agent-toolkit analyze` | `analyze-codebase.sh` | Codebase analysis |
| `agent-toolkit fix` | `self-fix-loop.sh` | Auto-fix CI loop |
| `agent-toolkit eval [skill-name]` | `run-evals.py` | Run skill evaluations |
| `agent-toolkit docs [generate\|sync]` | `generate-llms-txt.sh`, `docs-sync.sh` | Documentation operations |
| `agent-toolkit version` | `VERSION` | Show version |
| `agent-toolkit help` | — | Show help |

### Features

- `--help` / `-h` on every subcommand
- `--verbose` / `-v` for debug output
- Colored output with `--no-color` support
- Exit codes: 0=success, 1=warning, 2=failure
- Auto-detects `REPO_ROOT` from script location

## Files to Create/Modify

| File | Action |
|------|--------|
| `scripts/agent-toolkit.sh` | Create — main CLI script |
| `bin/agent-toolkit` | Create — symlink to `../scripts/agent-toolkit.sh` |
| `Makefile` | Add `cli` target |
| `AGENTS.md` | Add CLI documentation section |
| `QUICKSTART.md` | Add CLI quickstart |
| `agents-docs/SCRIPTS.md` | Add CLI entry |
| `tests/test_agent_toolkit.bats` | Create — CLI tests |

## Verification

1. `./bin/agent-toolkit help` — shows all commands
2. `./bin/agent-toolkit doctor` — runs doctor
3. `./bin/agent-toolkit quality` — runs quality gate
4. `./bin/agent-toolkit validate skills` — validates skills
5. `./bin/agent-toolkit --help` — shows global help
6. `bats tests/test_agent_toolkit.bats` — tests pass
