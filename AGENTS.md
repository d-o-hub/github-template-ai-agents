# AGENTS.md

> Single source of truth for all AI coding agents in this repository.
> Supported by: Claude Code, Windsurf, Gemini CLI, Codex, Copilot, OpenCode, Devin, Amp, Zed, Warp, RooCode, Jules
> See: https://agents.md

## Named Constants

```bash
# File size limits (lines)
readonly MAX_LINES_PER_SOURCE_FILE=500
readonly MAX_LINES_PER_SKILL_MD=250
readonly MAX_LINES_AGENTS_MD=150

# Retry and polling configuration
readonly DEFAULT_MAX_RETRIES=3
readonly DEFAULT_RETRY_DELAY_SECONDS=5
readonly DEFAULT_POLL_INTERVAL_SECONDS=5
readonly DEFAULT_MAX_POLL_ATTEMPTS=12
readonly DEFAULT_TIMEOUT_SECONDS=1800

# Git/PR configuration
readonly MAX_COMMIT_SUBJECT_LENGTH=72
readonly MAX_PR_TITLE_LENGTH=72

# Security configuration
readonly GITLEAKS_VERSION="v8.27.2"
```

## Setup

```bash
./scripts/setup-skills.sh # Create skill symlinks
# Install pre-commit for local secret scanning (optional but recommended)
pip install pre-commit
# Install custom git pre-commit hook (integrates Gitleaks)
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
**Guard Rails:** Pre-commit validates git config. If global hooks detected, run `git config --global --unset core.hooksPath` or use `SKIP_GLOBAL_HOOKS_CHECK=true`.

### Contract Testing Rules

- NEVER change an API endpoint shape without updating its Pact contract in `contracts/pacts/`
- NEVER delete a field from a response/request without a deprecation cycle documented in `agents-docs/CONTRACT-TESTING.md`
- ALWAYS use the `@pact-contract-testing` skill when adding/modifying HTTP API boundaries
- When adding a new endpoint: write the Pact consumer test FIRST, then implement
- Pact files in `contracts/pacts/` are the source of truth for API contracts — do not modify JSON manually

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}` lines/file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must start with frontmatter; No magic numbers - use named constants
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
```text
feat(search): add fuzzy matching to improve discovery

Users can now find documents even with typos. This uses the
Levenshtein distance algorithm for better results.
```

**Invalid Example (Body line too long):**
```text
fix(auth): resolve login timeout issue for users on slow connections by increasing the default timeout from 5 to 30 seconds
```

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

## Security

- **Secret Scanning**: Gitleaks is enforced via pre-commit hooks to prevent credential leakage.
- No secrets in commits (use `.env`); Pin Actions to SHA (with `# vX.Y` comment)
- No untrusted MCPs; Report vulnerabilities via Private Advisories

## Permission Boundaries (All Agents)

- **Never** commit to `main` directly
- **Never** read or reproduce secrets, tokens, or API keys
- **Never** modify `.github/workflows/` without human review step
- **Never** install global tooling
- **Never** access resources outside the git workspace root
- When in doubt: stop and ask via a GitHub comment, don't proceed

## Agent Guidance

- **Plan**: Produce written plan, wait for confirmation for non-trivial tasks.
- **Policies**: See `agents-docs/WORKFLOW.md` for Atomic Commit & Pre-Existing Issue resolution.
- **Learning**: After work, run `learn` or append discoveries to nearest `AGENTS.md`.
- **Context**: Delegate to sub-agents; Use `/clear`; Load skills only when needed.

#### Recent Project-Wide Learnings
- **Action SHA Pinning**: Pin to 40-char SHAs for security (LESSON-016)
- **Worktree Cleanup**: Use `trap cleanup EXIT ERR` and `CREATED_WORKTREES` (LESSON-010)

See `agents-docs/` for detailed reference documentation.
