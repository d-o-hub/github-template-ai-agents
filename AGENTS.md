# AGENTS.md

> Single source of truth for all AI coding agents in this repository.

<!-- Agent-specific guidance: CLAUDE.md, GEMINI.md, QWEN.md, JULES.md -->

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
readonly MAX_COMMIT_SUBJECT_LENGTH=150
readonly MAX_PR_TITLE_LENGTH=150
```

## Development Phases

We use a GOAP (Goal-Oriented Action Planning) approach combined with ADRs (Architecture Decision Records) and TRIZ for structured development.

**Prerequisites**:
- Always fetch and pull the latest default remote branch before beginning analysis or making changes.
- **Check CI Status**: Agents MUST check `ci-status.json` before starting any change task. If status is NOT "passing", the agent should report the issue and pause until CI is fixed.

1. **ANALYZE & STRATEGIZE (Phase 1)**
   - **Action**: Use `triz-analysis` or `triz-solver` to evaluate the problem, resolve contradictions, and identify architecture requirements. Write an **ADR** (Architecture Decision Record) detailing the context, decision, and consequences.
   - **Storage**: Save the ADR in the `plans/` directory.
   - **Human Gate**: Review and approve the ADR and analysis before proceeding. *This is the only human review gate.*

2. **DECOMPOSE & PLAN (Phase 2)**
   - **Action**: Use the `goap-agent` to break down the problem into atomic, testable tasks. Record these in `plans/GOAP_STATE.md`.

3. **EXECUTE & COORDINATE (Phase 3)**
   - **Action**: Agents execute tasks systematically based on the `plans/GOAP_STATE.md` using the atomic commit workflow.
   - **Action**: Use the `self-fix-loop` skill or equivalent to loop until all GitHub Actions (CI checks) pass.

4. **SYNTHESIZE (Phase 4)**
   - **Action**: Run the `learn` skill to extract discoveries and update project-specific `AGENTS.md` contexts.

## ADR Status Convention

Downstream projects should use the following statuses for ADRs:

- **accepted**: Architectural decision defining an ongoing pattern (e.g., AbortController, IndexedDB, token system).
- **complete**: Feature implementation with clear completion criteria (e.g., ambient light sensor, UI modernization).

This helps distinguish between permanent architectural conventions and completed feature work.

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

## CI State Artifacts

- `ci-status.json`: Machine-readable CI state file updated by GitHub Actions after each workflow run.
- `ci-summary.md`: Human/agent readable markdown summary of the latest CI run.

## Maintenance & Verification

```bash
./scripts/analyze-codebase.sh   # Autonomous analysis and self-learning
./scripts/check-adr-compliance.sh # Verify ADR registration and patterns
./scripts/run-evals.py --skill dora-report # Mandatory monthly DORA + agentic report
./scripts/check-plan-numbering.sh # Ensure plan counters are consistent
./scripts/archive-stale-plans.sh # Archive plans older than 60 days
```

**Guard Rails:**
- **Temporary Files**: NEVER create temporary files or debug outputs in the repository root or source directories. Always use system temporary directories (e.g., `/tmp` or via `mktemp`).
- **Secret Scanning**: Gitleaks is enforced via CI only to prevent credential leakage.
- **Git Config**: Pre-commit validates git config. If global hooks detected, run `git config --global --unset core.hooksPath` or use `SKIP_GLOBAL_HOOKS_CHECK=true`.

## Code Style

- Max `${MAX_LINES_PER_SOURCE_FILE}` lines/file; `${MAX_LINES_PER_SKILL_MD}`/`SKILL.md`; `${MAX_LINES_AGENTS_MD}`/`AGENTS.md`
- `SKILL.md` must start with frontmatter and include **Rationalizations** and **Red Flags** sections
- **No hardcoded values / Magic numbers**: Never hardcode deployment-specific paths, port numbers, API versions, or magic numeric literals. Use relative paths (base: "./"), runtime derivation (self.location), environment variables, or named constants with clear intent.
- **Reference format**: `` `references/filename.md` - Description ``
- Shell: `shellcheck` (severity=error); Markdown: `markdownlint`; Diagrams: `mermaid`

## Repository Structure

- `agents-docs/`: Detailed reference; `.agents/skills/`: Canonical skills
- `llms.txt` & `llms-full.txt`: Machine-readable project context for LLMs
- `scripts/`: Setup/validation; `analysis/` & `reports/`: Generated outputs
- `.claude/`: Agent-specific symlinks (see `scripts/setup-skills.sh`)
- `plans/`: ADRs define decisions; progress updates track implementation status.

## PR & Commit Instructions

- PR Title: `type(scope): description` (max `${MAX_PR_TITLE_LENGTH}` chars)
- Commit Header: `type(scope): subject` (max `${MAX_COMMIT_SUBJECT_LENGTH}` chars total, including type and scope)
- Commit Subject: MUST be lowercase (not sentence-case, start-case, or upper-case)
- Commit Body: max 1000 chars; wrap at 100 chars per line
- Commit Footer: max 1000 chars
- Branch per feature; One concern per PR; Never commit to `main`

### Commit Workflow (Mandatory)

1. **Use Helper (Preferred)**: Run `./scripts/ai-commit.sh --type <type> --subject <subject> --body <body>`
2. **Manual Commits**: Validated via `.githooks/commit-msg` (requires `./scripts/install-git-hooks.sh`)
3. **If Validation Fails**: Identify violation, then `git commit --amend` to fix message.

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

See `agents-docs/skills-reference.md` for the full skill catalog (50+ skills).

**Categories**: Coordination · DevOps · Documentation · General · Quality · Security · UI/UX · Compliance & Governance

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

## Self-Learning Rules (Auto-Generated)

This section is automatically updated by `./scripts/analyze-codebase.sh`.
See `agents-docs/self-learning-rules.md` for details and `./scripts/analyze-codebase.sh` for regeneration.

See `agents-docs/` for detailed reference documentation.

#### Integration Learnings

- **Optional Skills Pattern**: Implemented `SKILLS_OPTIONAL` in `setup-skills.sh` to allow opt-in for specialized knowledge like `eu-ai-act-compliance` and `durable-objects`.
- **Compliance Category**: Established "Compliance & Governance" as a new skill category for regulatory adherence patterns.
