# Changelog (Template)

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- sec(paths): harden path validation by protecting critical root files

## [0.2.10] - 2026-05-29

### Added

- feat(quality): add codacy static analysis skill (#376)

## [0.2.9] - 2026-05-19

### Added

- feat(turso-db): sync with latest Turso docs (v0.6.0) (#338)
- feat(do-web-doc-resolver): integrate optimizations and bugfixes from reference repository (#329)
- feat: adopt template practices from do-web-doc-resolver (#320)
- feat: add jules-delegator skill for task delegation (#304)
- feat: add .claude-plugin/ manifest for Claude Code marketplace (#300)
- feat(docs): centralize reference checklists in agents-docs/ (#299)

### Fixed

- fix: harden shell scripts against option injection (#339)
- fix(security): harden utility scripts and address review feedback
- fix(security): harden utility scripts and fix bash compatibility
- fix(security): harden utility scripts against injection
- fix: harden utility scripts against structural and option injection
- fix: harden shell scripts against injection and improve portability
- 🔒 [security fix] Unsafe command execution via tesseract and docling (#317)
- fix(security): harden scripts against injection and improve portability
- fix(security): harden scripts against injection
- fix(security): address PR feedback on ai-commit.sh and sentinel.md
- fix(security): prevent structural and option injection in ai-commit.sh
- fix: explicitly add missing 0.2.7 entry to CHANGELOG-TEMPLATE.md
- fix: resolve jules-delegator CI issues and harden doc scripts
- fix: resolve jules-delegator CI issues and harden doc scripts
- fix(security): prevent message injection in ai-commit.sh (#307)
- 🛡️ Sentinel: Fix option injection in utility scripts (#290)
- fix: address further PR feedback for patch version bump script
- fix: address PR feedback for patch version bump script

### Changed

- Fix badge link for template version in README
- Update README.md
- Remove template version badge
- Update version from 0.2.8 to 0.0.0
- Add Changelog link to Quick Links section
- CodeRabbit Generated Unit Tests: Add unit tests (#344)
- ci: bump the github-actions group with 2 updates (#342)
- 🛡️ Sentinel: [security improvement] harden scripts against structural and option injection (#343)
- sync orchestration and management tools from do-gist-hub (#340)
- 🛡️ Sentinel: [security improvement] (#341)
- Enhance sync-turso-skill workflow with error handling
- 🛡️ Sentinel: [security improvement] Harden swarm-worktree-web-research script (#337)
- perf: optimize command invalidation by pre-parsing JSON (#336)
- chore: remove .gemini/skills symlinks (#335)
- Hi, Jules here! I've optimized the performance by eliminating subshells in the `generate-available-skills.sh` loop.
- chore: [Jules Audit] 2026-05-14 — no actionable findings\n\nIncludes a test patch to stabilize do-web-doc-resolver tests.
- perf: remove subshells in quality gate linting loops
- perf: eliminate subshells in validate-config.sh loop
- Bolt: Eliminate redundant process forks and subshells (#325)
- ci: bump the github-actions group with 2 updates (#323)
- 🛡️ Sentinel: [security improvement] (#324)
- ⚡ Bolt: eliminate jq subshells in verify-commands loop (#322)
- 🛡️ Sentinel: [security improvement] Harden research engine score comparison (#321)
- test: improve content quality scoring tests and observability (#319)
- refactor: cleanup imports and fix accessibility
- refactor(tests): remove unused MagicMock and pytest imports
- 🧹 remove unused MagicMock and pytest imports in tests/test_run_evals.py
- 🧪 Improve content quality scoring tests and observability
- perf: optimize form label accessibility check
- perf: eliminate subshells and bash loop in validate_skill_file
- perf: eliminate subshells and bash loop in validate_skill_file
- perf: address review comments in update-agents-md.sh
- perf: replace bash loop with batched awk in update-agents-md.sh
- refactor(agents): replace spec-driven dev with GOAP/ADR
- refactor(agents): replace spec-driven dev with GOAP/ADR
- refactor(agents): replace spec-driven development with GOAP and ADRs
- ci: update github actions to node 24
- ci: update github actions to support node.js 24 and eliminate deprecation warnings
- refactor(gemini): use direct .agents/skills/ instead of symlinks (#305)
- Migrate Gemini commands to TOML format (#298)
- Add anti-rationalization tables to SKILL.md template (#297)
- ⚡ Bolt: Optimize eval-skills.sh validation via single-pass AWK (#289)
- chore: update script to use semantic commit formatting without emojis

## [0.2.8] - 2026-05-07

### Added

- feat(template): add language-agnostic AI agent contracts from self-learning memory (#282)
- feat: add automatic patch version bump script
- feat: update script to use semantic commit formatting without emojis

### Fixed

- fix(security): validate VERSION format in propagate-version.sh (#280)

### Changed

- Backport mature skills from do-web-doc-resolver (#283)
- Bolt: implement timestamp-based fast-path for lint cache (#276)
- Bolt: optimize setup-skills.sh performance (#285)
- Sentinel: [HIGH] Harden verify-commands against shell injection (#284)
- Update init_skill.py with functional template logic (#287)
- chore: revert previous bad bump to 0.2.8
- ci: bump github/codeql-action in the github-actions group (#277)
- perf(synthesis): optimize pairwise similarity in conflict check (#268)
- perf(synthesis): optimize pairwise similarity in conflict check (#278)
- perf: optimize link validation via batched awk processing (#279)

## [0.2.7] - 2026-04-29

### Added

- feat(testing): add language-agnostic contract testing layer
- feat(security): add Gitleaks for secret scanning and pre-commit hooks
- feat(security): add explicit agent permission boundaries
- Create gh-jules-setup.sh

### Fixed

- fix(security): prevent path traversal in evaluation framework
- fix(quality-gate): remove duplicate headers and handle Windows symlinks
- fix(security): implement fail-closed policy for SSRF DNS resolution
- fix(security): prevent command injection in docling and ocr providers
- fix(security): harden gh-labels-creator against argument injection

### Changed

- refactor(agents-md): prioritize instructions to overcome compliance ceiling
- perf(scripts): optimize command discovery with awk and batched jq
- perf(scripts): optimize validate-links.sh with single-pass awk
- ci: bump actions and commitlint-github-action

## [0.2.6] - 2026-04-26

### Added

- Synchronized `turso-db` skill with latest Turso docs (v0.5.3).
- Switched to custom GraphQL script for resolving bot threads in CI.

### Fixed

- Used verified actions/checkout SHA that resolves correctly in CI.

### Changed

- Optimized GitHub Action workflow validation script (`scripts/validate-workflows.sh`) to run significantly faster.
- Upgraded GitHub Actions dependencies to resolve Node.js 20 deprecation warnings.
- Hardened and optimized GitHub Actions workflows.

## [0.2.5] - 2026-05-14

### Added

- New High-Impact Skills:
  - `accessibility-auditor`: WCAG 2.2 compliance checking and accessibility audits.
  - `cicd-pipeline`: CI/CD pipeline design for GitHub Actions, GitLab, and Forgejo.
  - `code-review-assistant`: Automated PR analysis and quality checks.
  - `database-devops`: Database design, migrations, and safety patterns.
  - `migration-refactoring`: Automated framework migrations (React, Flask, etc.).
  - `testing-strategy`: Comprehensive testing patterns and strategies.
- `git-github-workflow` command: A full atomic git workflow with CI verification and automatic rollback.
- Enhanced `PULL_REQUEST_TEMPLATE.md` with comprehensive quality checklists and impact assessment.

### Fixed

- `docs-hook` skill: Added missing `docs-sync.sh` script and standardized evaluation format.

### Changed

- Improved skill-rules configuration and standardized metadata.
- Cleanup of temporary test artifacts and validation files from the repository.

## [0.2.4] - 2026-05-10

### Changed

- Internal version bump and dependency updates.

## [0.2.3] - 2026-04-20

### Changed

- Internal version bump and minor documentation fixes.

## [0.2.2] - 2026-04-06

### Fixed

- Corrected `csm` CLI flag from `--output` to `--output-format` in memory-context skill
- Added missing `version` and `template_version` fields to memory-context SKILL.md

## [0.2.1] - 2026-04-03

### Changed

- Bumped version to 0.2.1 across all files

## [0.2.0] - 2026-03-15

### Fixed

- GitHub Actions workflows using non-existent action versions (checkout@v5, setup-python@v6)
- yaml-lint.yml using unstable actionlint version tag
- ci-and-labels.yml using deprecated actions-rust-lang action
- gh-labels-creator.sh interactive prompt blocking CI execution
- Inconsistent branch references between workflow files
- Documentation inconsistencies across multiple files

### Changed

- Standardized action versions to stable releases (checkout@v4, setup-python@v5)
- Replaced deprecated rust-toolchain action with dtolnay/rust-toolchain@stable
- Added --ci flag support to gh-labels-creator.sh for non-interactive CI runs
- Updated README.md version badge to 0.2.0
- Updated all documentation to reference Qwen Code support
- Improved CONTRIBUTING.md with comprehensive guide
- Cleaned up AGENTS_REGISTRY.md formatting

### Added

- develop branch support in ci-and-labels.yml workflow
- .qwen/skills/ symlinks for Qwen Code support
- .github/dependabot.yml with 2026 best practices:
  - GitHub Actions weekly updates (grouped)
  - Docker weekly updates (exclude pre-releases)
  - Terraform monthly updates (grouped providers)
  - Docker Compose and pre-commit monthly updates
- Dependabot security updates auto-merge support
- OpenCode agent format documentation in SUB-AGENTS.md
- Supported AI Agents table in HARNESS.md

## [0.1.0] - 2026-03-14

### Added

- Initial template release
- Core skills (9 initial skills)
- Scripts for setup, validation, and quality gates
- Comprehensive documentation in `AGENTS.md` and `agents-docs/`

[Unreleased]: https://github.com/your-org/your-project/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-org/your-project/releases/tag/v0.1.0
