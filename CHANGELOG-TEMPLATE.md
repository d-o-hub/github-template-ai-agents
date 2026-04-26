# Changelog (Template)

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- `atomic-commit` command: A full atomic git workflow with CI verification and automatic rollback.
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
