# Jules Agent Guidelines

This project uses a unified agent framework. **All rules, skills, and workflows are defined in [`AGENTS.md`](./AGENTS.md).**

Jules-specific notes:
- See `.jules/bolt.md` for performance-specific learnings and technical rules
- Reference `.jules/sentinel.md` for high-level codebase context and architectural patterns
- Always follow the atomic commit workflow defined in `AGENTS.md`
- Always append task results using `./scripts/log-metric.sh '<json>'` after each task per the Post-Task Protocol
- Check `.github/ci-status/ci-status.json` before making any changes
