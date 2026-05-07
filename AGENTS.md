# AGENTS.md

> Single source of truth for all AI coding agents in this repository.
> Supported by: Claude Code, Windsurf, Gemini CLI, Codex, Copilot, OpenCode, Devin, Amp, Zed, Warp, RooCode, Jules
> See: https://agents.md

## Named Constants

```bash
# File size limits (lines)
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_PER_SKILL_MD=250
readonly MAX_LINES_AGENTS_MD=200

# Retry and polling configuration
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_DELAY_SECONDS=5
readonly DEFAULT_POLL_INTERVAL_SECONDS=5
readonly DEFAULT_MAX_POLL_ATTEMPTS=12
readonly DEFAULT_TIMEOUT_SECONDS=1800

# Git/PR configuration
readonly MAX_COMMIT_SUBJECT_LENGTH=72
readonly MAX_PR_TITLE_LENGTH=72

```

## Setup

```bash
./scripts/setup-skills.sh # Create skill symlinks
# Install custom git pre-commit hook
cp scripts/pre-commit-hook.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
```

## Version Management

**Single source of truth**: `VERSION` file at root. Never edit version strings elsewhere.
```bash
echo "0.3.0" > VERSION && git add VERSION && git commit -m "chore: bump version to 0.3.0"
```
See `agents-docs/VERSION.md` for full workflow details.

## Quality Gate (Required Before Commit)

```bash
./scripts/quality_gate.sh # Always run before committing. Fix all errors.
./scripts/update-all-docs.sh # Verify and update documentation
```
**Guard Rails:**
- **Temporary Files**: NEVER create temporary files or debug outputs in the repository root or source directories. Always use system temporary directories (e.g., `/tmp` or via `mktemp`).
- **Secret Scanning**: Gitleaks is enforced via CI only to prevent credential leakage.
- **Git Config**: Pre-commit validates git config. If global hooks detected, run `git config --global --unset core.hooksPath` or use `SKIP_GLOBAL_HOOKS_CHECK=true`.

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}` lines/file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must start with frontmatter and include **Rationalizations** and **Red Flags** sections
- No magic numbers - use named constants
- **Reference format**: `` `references/filename.md` - Description ``
- Shell: `shellcheck` (severity=error); Markdown: `markdownlint`; Diagrams: `mermaid`

## Repository Structure

- `agents-docs/`: Detailed reference; `.agents/skills/`: Canonical skills
- `scripts/`: Setup/validation; `analysis/` & `reports/`: Generated outputs
- `.claude/`, `.gemini/`, `.qwen/`: Agent-specific symlinks

## PR & Commit Instructions

- Title/Commit: `type(scope): description` (max `${MAX_PR_TITLE_LENGTH}` chars)
- Branch per feature; One concern per PR; Never commit to `main`

### Commit Workflow (Mandatory)

1. **Use Helper (Preferred)**: Run `./scripts/ai-commit.sh --type <type> --subject <subject> --body <body>`
2. **Manual Commits**: Validated via `.githooks/commit-msg` (requires `./scripts/install-git-hooks.sh`)
3. **If Validation Fails**: Identify violation, then `git commit --amend` to fix message.

**Valid Example:**

### Commit Type Mapping

| Intent                        | Type     | Scope suggestion |
|-------------------------------|----------|------------------|
| Security patch / hardening    | `fix`    | `security`       |
| New security feature/control  | `feat`   | `security`       |
| Security-related CI/tooling   | `ci`     | `security`       |

### Commitlint failures

Allowed types: `build` `chore` `ci` `docs` `feat` `fix` `perf` `refactor` `revert` `style` `test`

If `commitlint` rejects your message:
1. Identify correct type from table. Reword: `git commit --amend -m "<type>(<scope>): <subject>"`
2. Verify: `npx commitlint --from HEAD~1`
3. If not HEAD: `git rebase -i <commit>^` → change `pick` to `reword`.

Do not invent new types. Do not skip linting.

## Skills

| Skill | Description | Category |
|-------|-------------|----------|
| `accessibility-auditor` | Audit web applications for WCAG 2.2 compliance, screen reade | Security |
| `agent-browser` | Browser automation CLI for AI agents. Use when the user need | BrowserautomationCLIforagents |
| `agent-coordination` | Coordinate multiple agents for software development across a | Coordination |
| `agents-md` | Create AGENTS.md files with production-ready best practices. | General |
| `anti-ai-slop` | Apply this skill whenever the user wants to audit, fix, rede | QualityenforcementforUI,UX,andcopy |
| `api-design-first` | Design and document RESTful APIs using design-first principl | API Development |
| `architecture-diagram` | Generate or update a project architecture SVG diagram by sca | General |
| `atomic-commit` | Atomic git workflow - validates, commits, pushes, creates PR | General |
| `cicd-pipeline` | Design and implement CI/CD pipelines with GitHub Actions, Gi | DevOps |
| `cloudflare-worker-api` | Structure Worker API routes and handlers. Activate for route | API Development |
| `code-quality` | Review and improve code quality across any programming langu | Quality |
| `code-review-assistant` | Automated code review with PR analysis, change summaries, an | General |
| `codeberg-api` | - Interact with Forgejo/Codeberg repositories via the REST A | API Development |
| `css-render-performance` | Guide CSS render performance analysis and optimization. Use | General |
| `database-devops` | Database design, migration, and DevOps automation with safet | DevOps |
| `database-schema-migrations` | Design database schema and write migrations. Activate for ta | DevOps |
| `dist-channel-selection` | Guide for selecting the correct distribution channel (npm, C | General |
| `do-web-doc-resolver` | Python resolver for URLs and queries into compact, LLM-ready | Documentation |
| `docs-hook` | Lightweight git hook integration for updating agents-docs wi | Documentation |
| `document-rendering-and-locators` | Implement resilient document rendering and annotation anchor | Documentation |
| `dogfood` | Systematically explore and test a web application to find bu | General |
| `git-github-workflow` | Unified atomic git workflow with GitHub integration - commit | General |
| `github-pr-sentinel` | Monitor a GitHub pull request until it's merged, green, or b | ContinuousPRmonitoringandCIauto-fix |
| `github-workflow` | Complete GitHub workflow automation - push, create branch/PR | General |
| `goap-agent` | Invoke for complex multi-step tasks requiring intelligent pl | Coordination |
| `intent-classifier` | Classify user intents and route to appropriate skills, comma | Coordination |
| `iterative-refinement` | Execute iterative refinement workflows with validation loops | General |
| `learn` | Extract non-obvious session learnings into scoped AGENTS.md | General |
| `memory-context` | Retrieve semantically relevant past learnings and analysis o | General |
| `migration-refactoring` | Automate complex code migrations and refactorings with safet | Migration |
| `parallel-execution` | Execute multiple independent tasks simultaneously using para | Coordination |
| `privacy-first` | Prevent email addresses and personal data from entering the | PreventPII/emailleaksinthecodebase |
| `pwa-offline-sync` | Design Cache Storage + IndexedDB strategy and sync queue. Ac | General |
| `reader-ui-ux` | Build localized, accessible reader/admin UI with responsive | UI/UX |
| `readme-best-practices` | Create, audit, and improve GitHub README.md files following | ExpertguidanceforGitHubdocumentation |
| `secure-invite-and-access` | Implement access control, authentication, and authorization | General |
| `security-code-auditor` | Perform security audits on code to identify vulnerabilities, | Security |
| `self-fix-loop` | Self-learning fix loop - commit, push, monitor CI, auto-fix | General |
| `shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS. Use w | Quality |
| `skill-creator` | Create new skills, modify and improve existing skills, and m | Meta-skillforcreatingandoptimizingagentskills |
| `skill-evaluator` | "Reusable skill for evaluating other skills with structure c | Meta |
| `task-decomposition` | Break down complex tasks into atomic, actionable goals with | Coordination |
| `test-runner` | Execute tests, analyze results, and diagnose failures across | Quality |
| `testdata-builders` | Maintain deterministic builders/factories for test entities. | Quality |
| `testing-strategy` | Design comprehensive testing strategies with modern techniqu | Quality |
| `triz-analysis` | Run a systematic TRIZ contradiction audit against a codebase | General |
| `triz-solver` | Systematic problem-solving using TRIZ (Theory of Inventive P | General |
| `turso-db` | Use this skill for Turso (LibSQL/Limbo) database development | DevOps |
| `ui-ux-optimize` | Swarm-powered UI/UX prompt optimizer with auto-research agen | UI/UX |
| `verification-template` | Template for creating portable domain-specific verification | General |
| `web-search-researcher` | Research topics using web search to find accurate, current i | Research |

## Security

- **Secret Scanning**: Gitleaks is enforced via CI only to prevent credential leakage.
- No secrets in commits (use `.env`); Pin Actions to SHA (with `# vX.Y` comment)
- No untrusted MCPs; Report vulnerabilities via Private Advisories

## Agent Guidance

- **Rationalizations & Red Flags**: Every skill must include a `## Rationalizations` table to preemptively counter common excuses for cutting corners, and a `## Red Flags` checklist to identify early warning behaviors. Review these whenever using a skill to ensure high standards.
- **Plan**: Produce written plan, wait for confirmation for non-trivial tasks.
- **Policies**: See `agents-docs/WORKFLOW.md` for Atomic Commit & Pre-Existing Issue resolution.
- **Learning**: After work, run `learn` or append discoveries to nearest `AGENTS.md`.
- **Context**: Delegate to sub-agents; Use `/clear`; Load skills only when needed.

#### Recent Project-Wide Learnings
- **Action SHA Pinning**: Pin to 40-char SHAs for security (LESSON-016)
- **Worktree Cleanup**: Use `trap cleanup EXIT ERR` and `CREATED_WORKTREES` (LESSON-010)

See `agents-docs/` for detailed reference documentation.
