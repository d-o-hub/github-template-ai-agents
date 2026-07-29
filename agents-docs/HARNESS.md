# Harness Engineering

> Reference doc - not loaded by default. Link from AGENTS.md or a skill as needed.

`coding agent = AI model(s) + harness`

The harness is everything around the model: AGENTS.md, MCP servers, skills, sub-agents,
hooks, and back-pressure mechanisms. Harness engineering is the practice of tuning these
surfaces to improve output quality and reliability.

## Core Principle: Iterate on Failure

Do not design the ideal harness upfront. Add configuration **only when the agent actually
fails**. When a failure occurs, engineer a solution so it cannot happen the same way again.
Throw away what does not help - more config is not always better.

## AGENTS.md Guidelines

- Keep under **200 lines** (`MAX_LINES_AGENTS_MD` in `AGENTS.md`); human-written (never auto-generated — LLM-generated files hurt quality)
- Concise and universally applicable - every instruction costs tokens
- Use progressive disclosure: detailed docs in `agents-docs/`, not the root file

## Skills (Single Canonical Source)

All skills live in `.agents/skills/`. Claude Code and Qwen Code use symlinks
(`.claude/skills/`, `.qwen/skills/`) created by `./scripts/setup-skills.sh`.
OpenCode and Gemini CLI read skills directly from `.agents/skills/` - no symlinks needed.
See `agents-docs/SKILLS.md`.

## MCP Servers

- Only connect servers you actively use and trust
- Tool descriptions inject into the system prompt - each one consumes instruction budget
- Prefer well-known CLIs (GitHub, Docker, databases) over MCP
- Write thin CLI wrappers with concise output rather than verbose MCP responses
- Never connect to untrusted MCP servers - they are a prompt injection vector
- **MCP Tool Search** (Claude Code v2.1+): Reduces MCP context overhead by ~85%
  via on-demand tool loading. Enable in settings to avoid loading all tool schemas
  at session start.

## Observability

Track agent behavior for debugging and cost control:

- **Task-level**: Use `./scripts/log-metric.sh '<json>'` after every task (see `AGENTS.md` Post-Task Protocol). Entries go to `.agents/metrics/metrics-{agent}.jsonl`.
- **Session-level**: Use `claude --verbose` for detailed session tracing
- **Monthly**: Run `dora-report` skill for aggregated metrics
- **Cost attribution**: Add `session_id` to metrics entries to group work by session

## Supported AI Agents

| Agent | Skills Location | Sub-agents | Parallel Capabilities |
|-------|-----------------|------------|----------------------|
| Claude Code | `.claude/skills/` (symlinks) | `.claude/agents/` | Agent Teams, Agent View, Dynamic Workflows, Worktrees |
| Gemini CLI | `.agents/skills/` (direct) | `.gemini/agents/` | Sub-agents |
| OpenCode | `.agents/skills/` (direct) | `.opencode/agents/` | Sub-agents |
| Qwen Code | `.qwen/skills/` (symlinks) | - | - |

For Agent Teams, Dynamic Workflows, and Worktrees details, see `AGENT_TEAMS_GUIDE.md`.

## Further Reading

| Topic | File |
|---|---|
| Skills | `agents-docs/SKILLS.md` |
| Sub-Agents | `agents-docs/SUB-AGENTS.md` |
| Hooks | `agents-docs/HOOKS.md` |
| Back-Pressure | `agents-docs/CONTEXT.md` |
