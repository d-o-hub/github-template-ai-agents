# AGENTS.md

> Single source of truth for all AI coding agents in this repository.
> @see agents-docs/HARNESS.md for architecture and repository structure.

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

## TIER 1 — CRITICAL SAFETY

1. **NEVER** commit directly to the `main` branch. ALWAYS use feature branches.
2. **NEVER** include secrets, API keys, or tokens in commits. USE `.env` files for local secrets.
3. **ALWAYS** pin GitHub Actions to a 40-character commit SHA and include a version comment (e.g., `uses: action/name@SHA # v1.0`).
4. **NEVER** connect to or use untrusted MCP servers or tools.
5. **NEVER** perform irreversible operations (like database deletions) without explicit human confirmation.
6. **REPORT** all discovered security vulnerabilities via Private Advisories immediately.

## TIER 2 — QUALITY & WORKFLOW

7. **ALWAYS** run `./scripts/quality_gate.sh` before committing and FIX all errors.
8. **ALWAYS** produce a written plan and WAIT for user confirmation before starting non-trivial tasks.
9. **ALWAYS** use the `VERSION` file at the root as the single source of truth for project versioning.
10. **ALWAYS** use the commit helper `./scripts/ai-commit.sh` for all commits to ensure proper formatting.
11. **USE** the `type(scope): description` format for all PR titles and manual commit messages (max `${MAX_COMMIT_SUBJECT_LENGTH}` chars).
12. **FOLLOW** the Atomic Commit Workflow defined in `agents-docs/WORKFLOW.md`.
13. **DELEGATE** complex research or isolated tasks to sub-agents to maintain context hygiene.
14. **LOAD** skills progressively only when needed; DO NOT load all skills at session start.

## TIER 3 — STANDARDS & STYLE

15. **ALWAYS** use named constants from the "Named Constants" section above. **NEVER** use magic numbers.
16. **ENFORCE** file size limits: `${MAX_LINES_PER_SOURCE_FILE}` lines/source file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`.
17. **ENSURE** all `SKILL.md` files start with the required frontmatter and follow the structure in `agents-docs/SKILLS.md`.
18. **USE** the reference format `` `references/filename.md` - Description `` for all skill documentation.
19. **CAPTURE** non-obvious technical discoveries in the nearest `AGENTS.md` or `LESSONS.md` after completing a task.
20. **USE** `shellcheck` (severity=error) for Shell, `markdownlint` for Markdown, and `mermaid` for diagrams.
21. **NORMALIZE** all paths relative to the repository root before execution.

## Compliance Self-Check (Agents: run before finalizing any response)

- [ ] Did I read **ALL** of `AGENTS.md` before starting? (not just the first half)
- [ ] Did I check the **Named Constants** section for any values I used?
- [ ] Did I verify no **secrets/tokens** appear in my output?
- [ ] Did I confirm my **branch name** and **commit message** follow conventions?
- [ ] Did I run the **Quality Gate** (`./scripts/quality_gate.sh`)?
