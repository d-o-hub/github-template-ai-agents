# AGENTS.md

## Named Constants

```bash
# File size limits (lines)
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_PER_TEST_FILE=600
readonly MAX_LINES_PER_CONFIG_FILE=200

# Node/npm versions
readonly NODE_VERSION=20
readonly NPM_VERSION=10

# Timeouts
readonly TEST_TIMEOUT_SECONDS=30
readonly BUILD_TIMEOUT_SECONDS=120
readonly TYPECHECK_TIMEOUT_SECONDS=60

# Retry configuration
readonly MAX_RETRIES=3
readonly RETRY_DELAY_MS=1000
```

## Monorepo Structure

- `packages/` — workspace packages (libs, apps, shared utilities)
- `tools/` — internal build tooling and scripts
- `scripts/` — monorepo-level scripts (setup, quality gates, CI helpers)
- `plans/` — ADRs and implementation plans

## Setup

```bash
# Initial setup
npm install
npm run build

# Per-package development
npm run build --workspace=@repo/package-name
npm run test --workspace=@repo/package-name
```

## Code Style

- **TypeScript**: Strict mode, no `any`, prefer `unknown` with type guards
- **Imports**: Use `@repo/*` aliases for cross-package imports
- **Exports**: Explicit named exports only, no default exports in libraries
- **Naming**: `camelCase` for variables/functions, `PascalCase` for types/classes
- **Max line length**: 100 characters

## Pre-existing Issues

**Fix ALL before completing:**
- [ ] Lint warnings (`npm run lint`)
- [ ] Type errors (`npm run typecheck`)
- [ ] Test failures (`npm run test`)
- [ ] Build failures (`npm run build`)

**Workflow**: See `agents-docs/AGENTS_GUIDANCE.md` for GOAP + swarm pattern.

## Development Workflow

**Prerequisite**: Fetch and pull latest `main` before starting.

**Phase 1 (ANALYZE)**: Use `triz-analysis` skill. Write ADR in `plans/`.
**Phase 2 (DECOMPOSE)**: Plan in `plans/GOAP_STATE.md` with dependency graph.
**Phase 3 (EXECUTE)**: Implement with atomic commits. One concern per commit.
**Phase 4 (CI CHECK)**: Wait for full CI. Do not proceed until green.
**Phase 5 (SYNTHESIZE)**: Update context in `AGENTS.md` if patterns emerge.

## Quality Gate

**Required before every commit:**

```bash
# Type checking (workspace-level)
npm run typecheck

# Linting
npm run lint

# Unit tests
npm run test

# Build verification
npm run build

# Security audit
npm audit --audit-level=high
```

**Package-level checks:**

```bash
npm run typecheck --workspace=@repo/package-name
npm run lint --workspace=@repo/package-name
npm run test --workspace=@repo/package-name
```

## Commit Convention

Format: `type(scope): subject`

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `refactor` | Code change (no feature/fix) |
| `test` | Adding/fixing tests |
| `chore` | Build, CI, tooling |
| `perf` | Performance improvement |

**Scope**: Package name (e.g., `feat(core): add parser`).

Validate: `echo "title" | npx commitlint --config commitlint.config.cjs`

## Workspace Rules

- **Version pinning**: All dependencies in `package.json`, no global installs
- **Dependency order**: Respect `dependsOn` in `turbo.json` or `lerna.json`
- **Shared code**: Place in `packages/shared/*`, import via `@repo/shared`
- **Private packages**: Use `publishConfig.access: restricted` for internal-only

## Testing Strategy

- **Unit tests**: Co-located with source (`*.test.ts`)
- **Integration tests**: In `__tests__/integration/` directories
- **E2E tests**: Top-level `e2e/` directory, run after full build
- **Coverage**: Aim for 80% line coverage, no hard enforcement

## CI/CD

**GitHub Actions workflows:**
- `.github/workflows/ci.yml` — lint, typecheck, test on every PR
- `.github/workflows/release.yml` — publish on merge to `main`

**Local rehearsal:**

```bash
./scripts/run_act_local.sh  # Optional: test CI locally
```

## Skills & Sub-agents

Use specialized skills for complex tasks:

- `goap-agent` — multi-step planning and execution
- `agent-coordination` — parallel swarm dispatch
- `static-analysis` — lint triage and fixes
- `test-runner` — execute and diagnose test failures

Load skills on-demand via `.agents/skills/<skill-name>/SKILL.md`.

## Anti-patterns to Avoid

- Importing across package boundaries without going through `packages/shared`
- Using `require()` — use ES module `import` syntax
- Hardcoding package paths — use workspace protocol (`workspace:*`)
- Skipping type checks before commit
- Mixing business logic in UI packages (or vice versa)

## References

- `agents-docs/AGENTS_GUIDANCE.md` — Pre-existing issue workflow
- `agents-docs/SKILLS.md` — Available skills catalog
- `turbo.json` or `lerna.json` — Build orchestration config
