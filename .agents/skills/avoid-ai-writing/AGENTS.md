# .agents/skills/avoid-ai-writing/ AGENTS.md

> Scoped guidance for agents working with the avoid-ai-writing skill.

## Context

- This skill is a port of the `avoid-ai-writing` open-source project (v3.10.0).
- It uses a separate `references/patterns.md` file to stay under the 250-line `SKILL.md` limit while maintaining an exhaustive pattern catalog.

## Learnings

- **Skill Specificity**: Use `detect` mode for CI/CD gates to avoid unwanted automated rewrites of intentional patterns.
- **Iterative Convergence**: Patterns often survive the first edit; use `--iterate 2` or check the "Second-pass audit" section in `rewrite` mode.
- **Markdown Linting**: Ensure `patterns.md` and other documentation files have blank lines around all headings to pass MD022.
