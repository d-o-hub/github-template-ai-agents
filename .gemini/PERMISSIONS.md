# Gemini CLI — Permission Boundaries

## Motivation
Permission boundaries are the most important measure against AI-Agent catastrophes.
- **Kiro incident**: 13-hour outage due to no permission boundaries and no review gate.
- **Grigorev incident**: Production database destroyed by an agent with unconstrained write access.
Reference: [Böttger's AI-Agent Catastrophes]

## ALLOWED
- Read and write files within the workspace.
- Execute shell commands as needed for task completion.
- Access MCP tools configured in `settings.json`.

## NEVER ALLOWED
- Push directly to `main` or `release/*` branches.
- Access, read, or log `*_API_KEY`, `*_SECRET`, `*_TOKEN` environment variables.
- Execute network requests outside of explicitly listed domains.
- Install global packages.
- Modify `.github/` workflow files without human review.
- Access files outside the workspace root.

## MCP POLICY
- Only MCPs listed in `.gemini/settings.json` are permitted.
- Untrusted/community MCPs: NEVER add without explicit human approval.
