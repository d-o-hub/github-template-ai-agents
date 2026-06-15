# Monorepo Example (Bun + Turbo)

This example demonstrates how to structure a larger agent system using a monorepo approach with [Bun](https://bun.sh/) and [Turborepo](https://turbo.build/).

## Structure

```text
.
├── package.json          # Workspace configuration
├── turbo.json            # Task pipeline configuration
├── bunfig.toml           # Bun-specific settings
├── AGENTS.md             # Shared agent instructions (symlinked or copied)
├── .agents/skills/       # Canonical skills (shared across packages)
└── packages/
    ├── agent-core/       # Core logic and shared utilities
    └── agent-config/     # Environment-specific agent configurations
```

## Why Bun + Turbo?

- **Bun**: Ultra-fast runtime, package manager, and test runner. Ideal for high-frequency agent tool calls.
- **Turborepo**: Manages complex task dependencies and provides remote caching for agent-driven builds and tests.

## Key Scripts

- `bun run build`: Build all packages in the correct order.
- `bun run test`: Run the full test suite with parallel execution.
- `bun run lint`: Validate code style and documentation across the workspace.

## Agent Configuration in a Monorepo

In a monorepo, you have two primary options for `AGENTS.md`:

1. **Global**: A single `AGENTS.md` at the root that applies to all packages.
2. **Per-Package**: package-specific `AGENTS.md` files that extend the root guidance.

We recommend keeping the canonical `AGENTS.md` at the root and using tool-specific overrides (`CLAUDE.md`, etc.) within individual packages if they require specialized context.
