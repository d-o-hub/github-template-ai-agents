# Changelog (Template)

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- feat(harness): add Agent Teams, Dynamic Workflows, and Worktrees guide (`AGENT_TEAMS_GUIDE.md`)
- feat(harness): add behavioral defaults reference doc (`BEHAVIORAL_DEFAULTS.md`)
- feat(harness): add observability section to HARNESS.md

### Changed

- refactor(harness): trim AGENTS.md from 200 to 155 lines; move detailed sections to agents-docs/
- docs(harness): add MCP Tool Search guidance to HARNESS.md and CONTEXT.md
- docs(harness): add parallel capabilities column to Supported AI Agents table
- docs(agent-coordination): add native capabilities vs. custom coordination comparison table
- fix(paths): harden path validation by protecting critical root files
- refactor(template): move `templates/` to `.template/` for cleaner root structure
- fix(portability): replace `realpath --relative-to` with portable function in setup-skills.sh
- fix(portability): add Bash 4+ guard for `declare -A` in lint_cache.sh with graceful fallback
- fix(portability): wrap `python3` calls in `command -v` guards in quality_gate.sh
- fix(portability): remove GNU `xargs -r` flag from loc_gate.sh, eval-skills.sh, discover-commands.sh, lint_cache.sh
- fix(portability): replace GNU `date -d` with portable date detection in archive-stale-plans.sh
- fix(hooks): remove install-hooks.sh (superseded by bootstrap.sh + .githooks/)
- fix(template): remove hardcoded org fallback in cleanup-ci-status-prs.sh
- fix(hooks): downgrade global hooks check from error to warning in validate-git-hooks.sh
- fix(ci): add skill existence condition to sync-turso-skill.yml workflow
- perf(ci): add concurrency groups to markdown-lint, yaml-lint, commitlint, gitleaks workflows
- fix(template): derive PROJECT_NAME from git in .envrc instead of hardcoding
- fix(template): read VERSION from file in agent-toolkit.sh instead of hardcoding

### Fixed

- fix(refs): replace broken task-decomposition/github-readme skill references with goap-agent/readme-best-practices
- docs(agents): regenerate AGENTS.md skills table from catalog (17 categories, 56 skills)
- fix(version): agent-toolkit.sh reads VERSION file instead of hardcoding
- feat(validate): extend link-check to top-level docs and agents-docs/
- fix(links): resolve broken relative links in agents-docs/MIGRATION.md and AGENTS_REGISTRY.md
- chore: gitignore eval workspaces; remove 354 committed eval artifacts
- docs: align AGENTS.md line-limit guidance to 200 in CONTRIBUTING.md
- docs: sync QUICKSTART bootstrap output with bootstrap.sh
- chore: fix .gitignore malformed pattern and dedupe entries
- chore: remove duplicate comment block in quality_gate.sh

## [0.2.12] - 2026-08-20

### Added

- docs(plans): record round 3 PR triage and ci status persistence fix (#794)
- feat(turso-db): sync with latest Turso docs (v0.7.2) (#765)
- feat: sync features and fixes from upstream repository (#753)
- docs(adr): add adr-031 for per-agent metrics architecture
- test(log-metric): add bats tests for per-agent metrics helper
- docs(dora): correct metrics.jsonl status and triz suggestions
- docs(dora): add july 2026 dora and agentic metrics report
- docs(dora): correct F+followup batch merged count to 12 and closed count to 4
- docs(repo): add automerge workflow quickstart (#744)
- docs: update GOAP state to reflect all tasks completed (#729)
- feat(do-wdr): add semantic cache query normalization (#727)
- test(do-wdr): add cascade error handling tests (#726)

### Fixed

- fix(ci): prevent false-green ci status artifacts (#796)
- fix(ci): disable footer-max-line-length for squash merge bodies (#784)
- fix(ci): register unit pytest marker in do-web-doc-resolver (#785)
- fix(ci): persist ci status via automerge PR when main push is blocked (#786)
- fix(security): block database credentials and legacy shell profiles in path validation (#775)
- fix(security): harden skill discovery path validation (#773)
- fix(security): harden path validation with credential patterns (#770)
- fix(security): prevent access to development vaults ide settings and shell configs (#768)
- fix(tests): make turso-db skill version assertion version-agnostic
- fix(ci): harden reusable template automation (#760)
- fix(security): harden forbidden paths and credential pattern validation (#762)
- fix(tests): update stale codeql-action SHA pin in workflow versions test (#766)
- fix(ci): repair monthly DORA report workflow output path
- fix(security): harden eval paths and align workflow tests (#758)
- fix(tests): resolve 3 pre-existing test failures
- fix(workflows): repair YAML indentation + fatal disable on refusal (#746)
- fix(workflows): grant contents: write to auto-merge-non-deps workflow (#745)
- fix(do-wdr): deduplicate _l1_clear helper after squash-merge collision (#741)
- fix(security): harden path validation with credential patterns and cloud directories (#733)
- fix: markdownlint issues in GOAP_STATE.md (#728)
- fix(do-wdr): improve error handling and type safety (#725)
- fix(security): align async and sync ssrf protection by blocking unspecified ipv6

### Changed

- perf: replace dirname subshell in setup-skills loop (#792)
- ci: bump dtolnay/rust-toolchain (#780)
- ci: bump the github-actions group with 6 updates (#779)
- perf: replace find subshells with bash globbing in doctor.sh (#782)
- perf: eliminate find subshell in skills reference generation (#777)
- perf: eliminate grep and cut subshells in loc_gate.sh (#761)
- ci: bump actions/stale from 10.4.0 to 11.0.0 (#764)
- ci: bump the github-actions group with 5 updates (#763)
- perf(scripts): eliminate text-matching process forks in bash loop (#756)
- perf: eliminate subshells in metrics validation loops (#755)
- ci: bump https://github.com/igorshubovych/markdownlint-cli (#757)
- chore(metrics): log session wrap-up entry to per-agent metrics file
- refactor(metrics): replace single metrics file with per-agent files
- ci(CODEOWNERS): refine patterns + add /jules/ gate (#752)
- ci(CODEOWNERS): gate workflows + ADR + auto-merge docs (#751)
- perf(analyze-codebase): single-pass grep in check_todo_density (#750)
- ci(workflows): add yaml-validate guard for F8-class regressions (#749)
- ci(workflows): refine automerge to refuse on human review threads (#743)
- ci(workflows): opt-in label-gated auto-merge for non-Dependabot PRs (#742)
- perf: eliminate subshell in update-agents-md.sh (#731)
- ci: bump actions/labeler from 6.2.0 to 7.0.0 (#736)
- ci: bump the github-actions group with 6 updates (#735)
- perf: eliminate grep process forks in adr compliance check

## [0.2.11] - 2026-07-20

### Added

- feat(do-web-doc-resolver): backport synthesis and quality scoring (#700)
- feat: upgrade do-web-doc-resolver to asynchronous architecture (#685)
- feat: implement open GitHub issues #668, #669, #670 (#673)
- feat(skills): add metadata blocks and Codacy trigger rules
- feat(skills): enrich Codacy integration across existing skills
- feat: Add Context-Aware Voice & Context Profiles for Agent Writing (#662)
- feat(skills): add avoid-ai-writing skill (#641)
- feat(turso-db): sync with latest Turso docs (v0.6.1) (#657)
- feat(turso-db): sync with latest Turso docs (v0.6.1) (#621)
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
- Add llms.txt and llms-full.txt with generation script
- feat: add llms.txt and llms-full.txt with generation script
- feat: add mandatory agentic metrics reporting protocol with enhanced schema (#394)
- feat(quality): add core agent skills with automation and compliance tests
- feat(quality): add DORA automation and fix markdown linting
- feat(quality): add DORA automation and enhance core skill compliance
- feat(quality): add core agent skills and compliance tests
- feat(quality): add core agent skills for anti-slop, creation, evaluation, and dora reporting
- Add GitHub Actions workflow for quality gate
- feat: add ci-status.json and ci-summary.md as ci state artifacts
- feat: add ci status artifacts to change workflow
- feat: add ci-status.json and ci-summary.md as CI state artifacts

### Fixed

- fix(security): harden forbidden paths with pattern SSH blocking (#704)
- fix(security): fix dynamic ssh blocking and test failures (#706)
- fix(security): harden command categorization and path validation
- fix(template): implement improvement recommendations (ADR-030) (#702)
- fix(security): harden forbidden paths validation (#701)
- fix(security): harden command categorization against environment variable injection (#698)
- fix(security): block unspecified ipv6 address in ssrf protection
- fix(security): implement case-insensitive forbidden path validation (#689)
- fix(ci): add firecrawl-py to test dependencies
- fix(ci): add missing requests dependency for test_ssrf_repro.py
- fix(ci): replace hashFiles job-level if with step-level file check
- fix(template): improve portability and restructure templates folder
- fix: resolve pre-existing issues — missing visual_resolver stub and 6 oversized SKILL.md files
- fix(tests): create .templates/ dir in test setup for CHANGELOG-TEMPLATE.md
- fix(deps): add pytest to requirements.txt for CI test execution
- fix(security): harden command categorization and path validation (#687)
- fix(security): harden command keywords and forbidden paths (#683)
- fix(security): prevent command masking bypass in categorization (#678)
- fix: implement codebase improvement plan — 10 findings resolved (#680)
- fix(security): prevent path validation bypass for nested forbidden paths (#677)
- fix(security): harden forbidden paths and command categorization (#675)
- fix(ci): fix bash regex CR/LF bug in validate-skills.sh; add missing evals.json for agentic-abstention
- fix(security): harden forbidden paths and command categorization (#665)
- fix(security): expand restricted command and path coverage (#659)
- fix: harden command categorization regex and expand keyword coverage (#654)
- fix(security): harden command categorization and reduce false positives (#629)
- fix(security): harden command categorization and path validation (#624)
- fix(ci): add ignore patterns for bot-generated merge commits
- fix(security): harden command categorization and path validation (#615)
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

- perf(analysis): use native bash arrays in orphan cache detection (#705)
- Bolt: Optimize find existence checks in quality gate (#707)
- cleanup
- perf: eliminate jq subshells in verify-commands.sh loops (#695)
- test(security): add regression tests for unspecified ipv6 ssrf
- ci: bump the github-actions group with 2 updates (#697)
- perf: eliminate wc -l subprocesses in bash loop contexts (#690)
- chore: move CHANGELOG-TEMPLATE.md to .templates/ and update all references
- chore: remove project-specific unfixable-tests.md from template plans/
- chore: add .gitignore rules to prevent temp files in repo root
- chore: remove stray pr_body.txt temp file from repo root
- perf: eliminate grep process forks in bash loop (#688)
- ci: bump dtolnay/rust-toolchain (#682)
- ci: bump dorny/paths-filter in the github-actions group (#681)
- perf: eliminate subshells in docs-sync.sh while read loop (#679)
- chore: Update metrics, learnings, lessons, workflow, and GOAP state
- docs(agents): restructure AGENTS.md — split out teams-guide and behavioral-defaults; enrich docs with MCP Tool Search and observability
- chore: resolve merge conflicts with main
- perf: eliminate grep process forks in codebase analysis (#671)
- I have improved the scripts' performance by replacing external pattern-matching subshells with native Bash string matching. (#666)
- ci: bump <https://github.com/igorshubovych/markdownlint-cli> (#667)
- ci: regenerate llms.txt and llms-full.txt [skip ci]
- perf: eliminate grep process fork in test-workflow-validation.sh (#655)
- perf: eliminate awk and grep subshells in validate-skills.sh (#660)
- ci: bump the github-actions group with 3 updates (#656)
- 🛡️ Sentinel: harden path validation by protecting critical root files (#632)
- Bolt: optimize heading detection in validate-skills.sh (#633)
- Bolt: [eliminate subshells in metrics.jsonl validation] (#631)
- 🛡️ Sentinel: [MEDIUM] Harden command categorization regex (#630)
- perf(quality-gate): replace python subshells with batched jq (#628)
- 🛡️ Sentinel: [security improvement] Harden command categorization and forbidden paths (#626)
- I've made some performance improvements to eliminate subshells in the `validate-skills.sh` loop. (#627)
- Bolt: perf: eliminate subshells in validate-skills loop (#625)
- 🛡️ Sentinel: [MEDIUM] Harden command categorization (#622)
- perf(scripts): eliminate subshells and optimize json parsing (#623)
- ci: bump dtolnay/rust-toolchain (#620)
- ci: bump actions/checkout from 4.2.2 to 7.0.0 (#618)
- ci: bump peter-evans/create-pull-request from 6.1.0 to 8.1.1 (#617)
- ci: bump dorny/paths-filter from 3.0.3 to 4.0.1 (#619)
- ci: bump release-drafter/release-drafter in the github-actions group (#616)
- 🛡️ Sentinel: harden sha-pin-actions.sh against option injection (#614)
- chore: bump version to 0.2.11 and generate changelog (#613)
- refactor(skills): remove duplicate scripts, consolidate redundant skills, clean dangling symlinks
- ci: regenerate llms.txt and llms-full.txt (#609)
- I've made a performance improvement by eliminating unnecessary parsing of search results when counting lines. (#606)
- docs(plans): update eval schedule with Month 1 results and session summary
- docs(plans): add monthly skill evaluation schedule
- I’ve hardened the command categorization and added support for versioned interpreters to improve security. (#597)
- refactor(skills): merge redundancies, enhance skill-creator/evaluator, fix 60 lint errors
- perf(scripts): replace basename subshell with native bash expansion (#590)
- 🛡️ Sentinel: [HIGH] Harden command categorization and expand keyword lists (#589)
- chore(template): auto-generate skills-ref, expand analyzer, relocate orphans, document scaffolds
- chore(metrics): log pre-existing-failure audit round 2
- chore(metrics): log final merge-all-validate cycle
- perf: eliminate subshells in bash scripts [skip ci]
- chore(metrics): log GOAP+swarm pre-existing-failure remediation
- style(ci): trim log line to fit yamllint 120-char limit
- docs(agents): add Always-Fix Pre-Existing Issues rule + playbook
- chore(taste): record template-repo conventions learned this session
- chore(git): remove .commandcode and .mimocode from gitignore
- chore(lint): exclude .commandcode/ from markdownlint
- chore(metrics): log template-version-management skill creation
- chore(metrics): log swarm improvements and propagate-version bug discovery
- ci: bump turbo (#571)
- changelog
- ci: bump release-drafter/release-drafter (#569)
- ci: bump actions/checkout (#568)
- perf: use bash parameter expansion in command categorizer
- chore: add metrics entry for PR #558 cleanup
- chore(template): unify constants, fix dead docs, upgrade actions, clean artifacts
- perf(scripts): replace cut pipeline with native parameter expansion (#555)
- docs(template): add CommandCode to agent compatibility and config
- Bolt: [bash loop optimizations] (#547)
- ci: split ci-and-labels into focused workflows, add schema validation and release-drafter (#544)
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
- ci: bump the github-actions group across 1 directory with 2 updates (#513)
- ci: bump actions/checkout from 4.2.2 to 6.0.3 (#514)
- ci: bump actions/setup-go from 5.0.0 to 6.4.0 (#515)
- chore(plans): update GOAP_STATE with completed mission summary
- chore(docs): normalize setup docs to bootstrap.sh + doctor.sh (#504)
- Remove 'Available Skills' section from README
- docs(readme): rewrite hero and add why/compatibility/architecture/adoption sections
- 🛡️ Sentinel: [MEDIUM] Fix option injection in utility scripts (#501)
- Remove Codacy badge from README
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
- ci: bump the github-actions group across 1 directory with 2 updates (#458)
- ci: add commitlint config validation to quality gate and fix 14 yamllint truthy warnings
- ci: bump <https://github.com/shellcheck-py/shellcheck-py> (#456)
- test: refactor commitlint checks for stricter key-value matching and add dependabot exemption test
- ci: add dependabot commitlint exemption, LESSON-022, and workflow tests
- ci: add scheduled cleanup workflow, ci-status label, and duplicate-cleanup tests
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
- ci: regenerate llms.txt and llms-full.txt (#397)u
- docs: add LESSON-017 - CI symlink dependency for validate-skills
- test: add quality gate drift test for missing gitignored llms files on main
- ci: add regenerated llms.txt and llms-full.txt
- ci(workflow): add workflow_dispatch trigger to update llms context files
- refactor: remove space-collapse gsub from skill-index awk for consistency
- test: fix 4 pre-existing test failures in quality gate, loc_gate, and generate-llms-txt
- chore: merge AGENTS.md with llms.txt reference
- test: simple content
- test: verify update mechanism
- Bolt: [performance improvement] (#391)
- 🛡️ Sentinel: [security improvement] Harden WASM size gate against injection (#390)
- Replace empty GEMINI.md and QWEN.md stubs with agent guidance (#389)
- Remove npm cache from Node.js setup in workflow
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
- fix: explicitly add missing 0.2.7 entry to .templates/CHANGELOG-TEMPLATE.md
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
