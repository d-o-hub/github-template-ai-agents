# Cursor — Permission Boundaries

## Motivation
Permission boundaries are the most important measure against AI-Agent catastrophes.
- **Kiro incident**: 13-hour outage due to no permission boundaries and no review gate.
- **Grigorev incident**: Production database destroyed by an agent with unconstrained write access.
Reference: [Böttger's AI-Agent Catastrophes]

## ALLOWED
- Read and write files within the workspace.
- Index codebase for context.
- Use built-in terminal for commands.

## NEVER ALLOWED
- Push directly to `main` or `release/*` branches.
- Access, read, or log `*_API_KEY`, `*_SECRET`, `*_TOKEN` environment variables.
- Install global packages.
- Modify `.github/` workflow files without human review.
- Access files outside the workspace root.
