# Qwen Agent Guidelines

This project uses a unified agent framework. **All rules, skills, and workflows are defined in [`AGENTS.md`](./AGENTS.md).**

Qwen-specific notes:
- Prefer `agents-docs/` for context before asking clarifying questions
- Use the skills in `.agents/skills/` for structured tasks
- Always append task results using `./scripts/log-metric.sh '<json>'` after each task (Full profile; optional for Light-mode adopters)
- Check `.github/ci-status/ci-status.json` before making changes (Full profile; optional for Light-mode adopters)
