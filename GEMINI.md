# Gemini Agent Guidelines

This project uses a unified agent framework. **All rules, skills, and workflows are defined in [`AGENTS.md`](./AGENTS.md).**

Gemini-specific notes:
- Prefer `agents-docs/` for context before asking clarifying questions
- Use the skills in `.agents/skills/` for structured tasks
- Always append task results to `.agents/metrics.jsonl` after each task
- Check `.github/ci-status/ci-status.json` before making any changes
