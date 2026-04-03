# AGENTS.md

> Single source of truth for AI coding agents. See https://agents.md for spec.

## Named Constants

```bash
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_PER_SKILL_MD=250
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_TIMEOUT_SECONDS=1800
readonly MAX_COMMIT_SUBJECT_LENGTH=72
readonly MAX_PR_TITLE_LENGTH=72
```

## Project Overview

AI agent template with 30+ skills. Stack: Bash, Markdown, GitHub Actions.

## Setup

```bash
./scripts/setup-skills.sh                                    # Create symlinks
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit          # Install hook
chmod +x .git/hooks/pre-commit
```

## Quality Gate

**Always run before committing:**

```bash
./scripts/quality_gate.sh              # Full validation
./scripts/validate-skill-format.sh   # SKILL.md format
./scripts/validate-skills.sh           # Symlinks
```

## Code Style

- Max 500 lines per source file, 250 per SKILL.md
- SKILL.md: frontmatter required (`---` on line 1)
- Conventional Commits: `feat:`, `fix:`, `docs:`, `ci:`, `test:`, `refactor:`
- No magic numbers - use named constants
- Shell: `shellcheck` for linting, `bats` for testing
- Markdown: `markdownlint` for consistency

## Testing Strategy

| Type | Purpose | Command |
|------|---------|---------|
| Unit | Individual functions | `bats tests/` |
| Integration | Skill validation | `./scripts/validate-skills.sh` |
| Format | SKILL.md compliance | `./scripts/validate-skill-format.sh` |
| Security | Secrets/audit | `./scripts/atomic-commit/pre-commit-check.sh` |

## PR Instructions

- Title: `[type(scope)] description` (max 72 chars)
- Run quality gate before committing
- Create feature branch, never commit to `main`
- Keep PRs focused; one concern per PR

## Security

- Never commit secrets or API keys (use `.env`, gitignored)
- Never connect to untrusted MCP servers

## Agent Guidance

### Plan Before Executing
For non-trivial tasks: produce a written plan first, pause, and wait for confirmation.

### Atomic Commit Policy (REQUIRED)

```bash
git checkout -b feat/name          # 1. Create branch
./scripts/atomic-commit/run.sh     # 2. Full atomic workflow:
                                   #    - Validate (zero warnings)
                                   #    - Commit all changes
                                   #    - Push to origin
                                   #    - Create PR
                                   #    - Verify all GitHub Actions pass
```

**Zero-tolerance:** Rolls back on ANY failure - quality gate warnings, check failures, or any warnings detected. Pre-existing issues must be fixed first.

### Pre-Existing Issue Policy (REQUIRED)

**Fix ALL before completing:** lint warnings, test failures, security warnings, documentation gaps, code style violations.

**Process:** Run quality gate before starting, note all failures, fix ALL issues, verify zero issues remain.

### Skills: Single Source in .agents/skills/

Canonical skills live in `.agents/skills/`. Claude/Gemini use symlinks. OpenCode reads directly. Run `./scripts/setup-skills.sh` to create symlinks.

### Available Skills

| Skill | Description | Category |
|-------|-------------|----------|
| `accessibility-auditor` | WCAG 2.2 compliance | Security |
| `agent-coordination` | Multi-agent orchestration | Coordination |
| `agents-md` | AGENTS.md best practices | Documentation |
| `anti-ai-slop` | UX/UI authenticity | UI/UX |
| `api-design-first` | OpenAPI/REST design | APIDevelopment |
| `architecture-diagram` | SVG architecture diagrams | Documentation |
| `cicd-pipeline` | GitHub Actions workflows | DevOps |
| `code-quality` | Code quality reviews | CodeQuality |
| `code-review-assistant` | PR analysis | General |
| `codeberg-api` | Forgejo/Codeberg API | DevOps |
| `database-devops` | DB migrations | DevOps |
| `do-web-doc-resolver` | URL resolution | Research |
| `docs-hook` | Git hook docs sync | Documentation |
| `github-readme` | README best practices | Documentation |
| `goap-agent` | Complex task planning | Coordination |
| `intent-classifier` | Skill routing | Coordination |
| `iterative-refinement` | Validation loops | Quality |
| `migration-refactoring` | Code migrations | Migration |
| `parallel-execution` | Parallel tasks | Coordination |
| `privacy-first` | PII detection | Security |
| `security-code-auditor` | Security audits | Security |
| `shell-script-quality` | Shell testing | CodeQuality |
| `skill-creator` | Create new skills | Meta |
| `skill-evaluator` | Evaluate skills | Meta |
| `task-decomposition` | Task planning | Planning |
| `test-runner` | Test execution | Quality |
| `testing-strategy` | Test design | Quality |
| `triz-solver` | Problem solving | Innovation |
| `ui-ux-optimize` | UI/UX optimization | UI/UX |
| `web-search-researcher` | Web research | Research |

### Context Discipline

- Delegate research to sub-agents
- Use `/clear` between unrelated tasks
- Load skills only when needed

### Nested AGENTS.md

For monorepos, place AGENTS.md in each package. Closest file takes precedence.

### Reference Docs

| Topic | File |
|---|---|
| Harness overview | `@agents-docs/HARNESS.md` |
| Skill authoring | `@agents-docs/SKILLS.md` |
| Sub-agents | `@agents-docs/SUB-AGENTS.md` |
| Hooks | `@agents-docs/HOOKS.md` |
| Context/back-pressure | `@agents-docs/CONTEXT.md` |
| Rust patterns | `@agents-docs/RUST.md` |
