# Changelog (Template)

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.11] - 2026-06-20

### Added

- feat(cli): add agent-toolkit unified CLI interface
- feat(evals): complete Month 4 evals
- feat(evals): complete Month 3 evals
- feat(diagram): modernize architecture SVG with 2026 design
- feat(evals): complete Month 2 evals
- feat(evals): complete Month 1 evals with correct workspace structure
- feat(skills): add eval results, trigger tests, and scoped linting
- feat(skills): add negative triggers to all 46 remaining skills
- feat(skills): optimize descriptions with pushy language and trigger tests
- feat(skills): optimize all skills based on agentskills.io best practices (#604)
- feat(dx): add general-purpose dev experience improvements (#603)
- feat(dx): add general-purpose dev experience improvements
- feat(do-web-doc-resolver): add 2026 LLM-Readable-Doc standards (#592)
- feat(template): adopt P0 action-pin lifecycle, handoff schema, CI-debugging ADRs
- feat(skills): add template-version-management skill
- feat(turso-db): sync with latest Turso docs (v0.6.1)
- feat: add agent eval and policy templates inspired by MiMo-Code
- feat(skills): enforce skill authoring workflow across template codebase (#554)
- feat(ci): add ci status freshness check (#523)
- feat(convention): implement layered PR title guard rails (#511)
- feat(turso-db): sync with latest Turso docs (v0.6.1) (#516)
- feat: Add SessionStart hook for agent context injection (#509)
- feat: Adapt opencode-processing-skills concepts into agent structure (#506)
- feat(scripts): add bootstrap.sh and doctor.sh entry points (#498)
- feat(ci): add Codacy CI workflow, findings triage report, and update DORA metrics
- feat: port external resolver improvements (#481)
- feat(turso-db): sync with latest Turso docs (v0.6.1) (#419)
- feat(turso-db): sync with latest Turso docs (v0.6.1) and fix SonarCloud issues
- feat: add static analysis / linter agent skill (#392)
- feat: fix auto-regeneration CI workflow, add May 2026 DORA report
- feat: add llms.txt support, sync SKILL.md versions, prevent merge conflicts
- feat: add llms.txt and llms-full.txt with generation script
- feat: add mandatory agentic metrics reporting protocol with enhanced schema (#394)
- feat(quality): add core agent skills with automation and compliance tests
- feat(quality): add DORA automation and fix markdown linting
- feat(quality): add DORA automation and enhance core skill compliance
- feat(quality): add core agent skills and compliance tests
- feat(quality): add core agent skills for anti-slop, creation, evaluation, and dora reporting
- feat: add ci-status.json and ci-summary.md as ci state artifacts
- feat: add ci status artifacts to change workflow
- feat: add ci-status.json and ci-summary.md as CI state artifacts

### Fixed

- fix(tests): exclude eval workspaces from SKILL.md check, update auto-merge flag
- fix(lint): resolve markdown lint failures in CI
- fix(ci): resolve pre-existing issues and document unfixable CI staleness
- fix(ci): filter eval workspace dirs from skill validation (#611)
- fix(ci): use --auto instead of --admin for bot PR auto-merge (#612)
- fix(evals): cleanup workspaces and add Codacy config
- fix(evals): move skills-evaluation to .agents/skills/
- fix(evals): move workspaces to .agents/skills/ and update docs
- fix(evals): restructure workspaces to match skill-evaluator spec
- fix(security): harden command categorization against multi-line obfuscation (#607)
- fix(skills): add Use when phrasing to 5 remaining skills
- fix(tests): rewrite workflow tests to match current ci.yml
- fix(ci): fix markdown lint and shellcheck warnings
- fix(ci): remove local codacy workflow, adopt path-filter + ci-success aggregator (#601)
- fix(security): harden path validation in run-evals.py (#600)
- fix(tests): align workflow logic tests with skip ci requirement
- fix(ci): harden status update automerge logic
- fix(template): pin LC_ALL=C for deterministic skills sort
- fix(commitlint): disable body-max-line-length rule (#584)
- fix(ci): drop unused Dependabot ecosystems (docker, terraform)
- fix(security): harden command categorization and expand dangerous keywords [skip ci]
- fix(ci): remove invalid `workflows: write` permission
- fix(ci): restrict metrics auto-merge to safe files only
- fix(ci): grant workflows:write to metrics-conflict-resolver
- fix(ci): make Codacy upload optional when no project token
- fix(ci): exclude skill symlink dirs from Codacy analysis
- fix(ci): add --force-file-permissions to Codacy analyze
- fix(ci): skip Codacy uncommitted-files check + ignore test artifacts
- fix(ci): replace Codacy composite action with direct Docker invocation
- fix(docs): make README the sole template-version badge
- fix(example): add .gitignore to monorepo-bun-turbo example
- fix(pr-565): restore regressions, fix SonarCloud, improve AGENTS.md structure
- fix(security): harden utility scripts against option injection
- fix(security): harden command categorization against path prefixes (#559)
- fix(ci): yaml lint fixes for release-drafter
- fix(ci): fix release-drafter - correct action SHA and use PR for changelog
- fix(security): harden glob-to-regex conversion in matches_pattern (#546)
- fix(ci): allow required checks to run on auto-generated PRs (#541)
- fix(security): add eval and exec to dangerous keywords (#536)
- fix(metrics): prevent merge conflicts on metrics.jsonl (#533)
- fix(scripts): add portable skill symlink paths (#527)
- fix(workflows): validate final eof script blocks (#528)
- fix(docs): keep dry-run generation non-mutating (#524)
- fix(ci): use gh pr view to get PR number after gh pr create
- fix(ci): disable commitlint body-max-length and enforce at PR level (#519)
- fix(security): harden scripts against injection (#505)
- fix(repo): resolve conflicts, fix gemini config, and remove redundant command (#508)
- fix(ci): enforce conventional commits for all contributors including bots (#507)
- fix(security): resolve 9 SonarCloud security hotspots (#489)
- fix(ci): pin setup-go action to commit SHA in codacy.yml (#490)
- fix(security): resolve remaining Codacy triage findings
- fix(security): update vulnerable deps, fix shell=True Popen, add SonarPython exclusion
- fix(ci): skip update-ci-status job on Dependabot PRs to prevent auto-merge block
- fix(ci): update codeql-action version comments from v4.35 to v4.36
- fix(test): make quality_gate commitlint check conditional and fix drift test MD022
- fix(ci): exclude auto-merge check from self-detection using name filter
- fix(ci): accept cancelled checks in auto-merge and add yamllint convention to AGENTS.md
- fix(ci): resolve yamllint line-length violation and improve test precision
- fix(ci): ensure ci-status label exists before PR creation
- fix(ci): prevent duplicate CI status PRs with concurrency guard, stale exemption, and author fix
- fix(ci): use PR author login for Dependabot auto-merge guard
- fix: fix commitlint CI scoping and remaining SonarCloud issues (15+ code smells)
- fix: address SonarCloud issues across 9 files (30+ code smells)
- fix: resolve CI status PR clutter and enhance cleanup script (#451)
- fix: address remaining SonarCloud issues across 9 files (40+ code smells)
- fix: address SonarCloud issues in validate-links.sh, swarm-worktree, and run-evals.py
- fix: address SonarCloud code smells across 12 shell scripts
- fix: address SonarCloud issues in Python and shell config files
- fix: address SonarCloud code smells in non-skill shell scripts
- fix: address remaining SonarCloud code smells across 9 shell scripts
- fix(security): harden utility scripts against option injection and fix CI regressions
- fix(ci): prevent merge conflicts from duplicate ci-status update PRs (#411)
- fix: resolve remaining CI failures in quality gate and workflows
- fix: use locale-independent sort in generate-llms-txt.sh to prevent CI drift
- fix: resolve markdownlint md012 and relax commitlint subject-case
- fix(ci): add setup-skills step to quality gate and test workflows
- fix(workflow): remove nonexistent automated label from pr create
- fix(quality-gate): warn instead of fail when gitignored llms files are missing on main
- fix: add files filter to generate-llms-txt pre-commit hook
- fix: handle multi-line YAML descriptions in generate-llms-txt.sh
- fix: add cleanup trap and error checking to quality_gate.sh
- fix: add cleanup trap and error checking in quality_gate.sh
- fix: resolve merge conflict - merge PR #394 changes with PR #393 changes
- fix: resolve merge conflict - merge main changes with PR changes
- fix: resolve merge conflict with PR #394 - include both Post-Task Protocol and llms.txt

### Changed

- refactor(skills): remove duplicate scripts, consolidate redundant skills, clean dangling symlinks
- docs(plans): update eval schedule with Month 1 results and session summary
- docs(plans): add monthly skill evaluation schedule
- refactor(skills): merge redundancies, enhance skill-creator/evaluator, fix 60 lint errors
- perf(scripts): replace basename subshell with native bash expansion (#590)
- 🛡️ Sentinel: [HIGH] Harden command categorization and expand keyword lists (#589)
- chore(template): auto-generate skills-ref, expand analyzer, relocate orphans, document scaffolds
- chore(metrics): log pre-existing-failure audit round 2
- chore(metrics): log final merge-all-validate cycle
- perf: eliminate subshells in bash scripts [skip ci]
- chore(metrics): log GOAP+swarm pre-existing-failure remediation
- docs(agents): add Always-Fix Pre-Existing Issues rule + playbook
- chore(taste): record template-repo conventions learned this session
- chore(git): remove .commandcode and .mimocode from gitignore
- chore(lint): exclude .commandcode/ from markdownlint
- chore(metrics): log template-version-management skill creation
- chore(metrics): log swarm improvements and propagate-version bug discovery
- perf: use bash parameter expansion in command categorizer
- chore: add metrics entry for PR #558 cleanup
- chore(template): unify constants, fix dead docs, upgrade actions, clean artifacts
- perf(scripts): replace cut pipeline with native parameter expansion (#555)
- docs(template): add CommandCode to agent compatibility and config
- Bolt: [bash loop optimizations] (#547)
- chore(repo): remove duplicate SECURITY.md and rename ruleset file (#542)
- chore(skills): split codacy skill into analysis-cli and cloud-cli (#539)
- Bolt: optimize audit log rotation and line counting (#538)
- perf: optimize bash string manipulation and loops in library scripts (#532)
- chore(scripts): normalize bash shebangs (#525)
- 🛡️ Sentinel: [HIGH] Harden command categorization against obfuscation (#521)
- docs(agents): add LESSON-034 for gh pr create --json limitation
- test(ci): add BATS tests for update-llms-txt workflow auto-merge
- docs(agents): update commit body-max-length reference to reflect disabled state
- docs(plans): add ADR-010 for automated PR auto-merge pattern
- docs(agents): add LESSON-031/032/033 for CI and PR management learnings
- 🛡️ Sentinel: harden utility scripts against injection and traversal (#517)
- chore(plans): update GOAP_STATE with completed mission summary
- chore(docs): normalize setup docs to bootstrap.sh + doctor.sh (#504)
- docs(readme): rewrite hero and add why/compatibility/architecture/adoption sections
- 🛡️ Sentinel: [MEDIUM] Fix option injection in utility scripts (#501)
- perf: batch lint invocations in quality_gate.sh (#485)
- 🛡️ Sentinel: [MEDIUM] Harden command categorization (#484)
- perf: eliminate find subshell in generate-available-skills.sh (#480)
- docs: fix remaining 118->117 count inconsistencies in Codacy triage report
- docs: fix MD034 bare URL and update Codacy finding counts to 151
- docs: document SonarPython S101 suppression limitation in Codacy
- docs: fix MD031 blank line before code fence in LESSON-028
- docs: fix MD031 markdownlint violations in LESSON-028 code blocks
- 🛡️ Sentinel: [MEDIUM] Harden Bash scripts against octal interpretation (#479)
- docs: split LESSON-024 Related Discoveries into standalone LESSON-025/026/027
- docs: update June 2026 DORA report, append session metrics, document act status
- docs: add LESSON-024 documenting session discoveries from GOAP followups
- test: add ADR compliance regression tests to quality gate drift suite
- docs: update GOAP_STATE.md with ADR-007 registration status
- docs: fix MD022 markdownlint, register ADR-007, update GOAP_STATE.md
- docs: fix LESSON-023 reference in ADR-007 to use relative path
- docs: add ADR-007 for Dependabot auto-merge ruleset requirements and negative regression tests
- docs: add LESSON-023 documenting Dependabot auto-merge GraphQL rewrite
- refactor(ci): replace manual Dependabot auto-merge with GraphQL-based native merge
- refactor(ci): remove dead getCombinedStatusForRef call from auto-merge workflow
- docs: fix MD031 markdownlint error in AGENTS.md yamllint convention section
- test: update CodeQL SHA in workflow version tests to match merged Dependabot
- test: add auto-merge workflow validation tests and fix Dependabot pre-commit label
- test: refactor commitlint checks for stricter key-value matching and add dependabot exemption test
- docs: add LESSON-020 and LESSON-021 from dependabot auto-merge fix session
- docs: update DORA report for June 2026 with actual metrics
- chore: update agent metrics for issue #475 fix
- chore(ci): update ci-status.json to passing after successful CI run
- 🛡️ Sentinel: harden shell scripts against injection and expansion (#466)
- chore: migrate from .markdownlintrc to .markdownlint-cli2.jsonc format (#452)
- docs: update agent metrics for SonarCloud fixes session (#448)
- refactor: reduce cognitive complexity in Python test and validator files
- docs: update agent metrics for PR #414
- perf(wasm): batch stat calls to eliminate loop subshells in wasm_size_gate.sh
- docs: add LESSON-018/019, fix pre-commit config, init DORA report for June 2026
- docs: add LESSON-017 - CI symlink dependency for validate-skills
- test: add quality gate drift test for missing gitignored llms files on main
- refactor: remove space-collapse gsub from skill-index awk for consistency
- test: fix 4 pre-existing test failures in quality gate, loc_gate, and generate-llms-txt
- chore: merge AGENTS.md with llms.txt reference
- chore: remove test file
- test: simple content
- test: verify update mechanism
- Bolt: [performance improvement] (#391)
- 🛡️ Sentinel: [security improvement] Harden WASM size gate against injection (#390)
- 🛡️ Sentinel: [security improvement] Harden utility scripts against injection (#379)
- Bolt: [performance improvement] (#378)

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
