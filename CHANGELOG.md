# Changelog

All notable changes to this template will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Auto-update script for AGENTS_REGISTRY.md (`scripts/update-agents-registry.sh`)
- Skill rules configuration (`.agents/skills/skill-rules.json`)
- Web documentation resolver skill (`.agents/skills/web-doc-resolver/`)
- Multi-language auto-detection in quality gate
- Enhanced skill validation (line count, frontmatter checks)

### Changed
- Comprehensive README.md with feature matrix and usage examples
- Quality gate with auto-detection for Rust, TypeScript, Python, Go, Shell
- validate-skills.sh now validates SKILL.md format and line limits

### Documentation
- QUICKSTART.md - 5-minute setup guide
- MIGRATION.md - Adoption guide for existing projects
- AGENTS_REGISTRY.md - Auto-generated agent/skill registry

## [0.1.0] - 2026-03-14

### Added
- Initial template release
- Core skills:
  - `task-decomposition` - Break complex tasks into atomic goals
  - `code-quality` - Code review and quality checks
  - `test-runner` - Execute and manage tests
  - `shell-script-quality` - ShellCheck + BATS for shell scripts
  - `parallel-execution` - Coordinate parallel agent execution
  - `iterative-refinement` - Progressive improvement loops
  - `agent-coordination` - Multi-agent orchestration
  - `goap-agent` - Goal-oriented action planning
  - `web-search-researcher` - Web research and synthesis
- Sub-agents:
  - `goap-agent` - Complex planning & coordination
  - `loop-agent` - Iterative refinement workflows
  - `analysis-swarm` - Multi-perspective code analysis
  - `agent-creator` - Scaffold new sub-agent definitions
- Scripts:
  - `setup-skills.sh` - Create symlinks for CLI tools
  - `validate-skills.sh` - Validate skill symlinks
  - `quality_gate.sh` - Multi-language quality gate
  - `pre-commit-hook.sh` - Git pre-commit integration
  - `gh-labels-creator.sh` - Initialize GitHub labels
- Documentation:
  - `AGENTS.md` - Single source of truth
  - `agents-docs/HARNESS.md` - Harness engineering overview
  - `agents-docs/SKILLS.md` - Skill authoring guide
  - `agents-docs/SUB-AGENTS.md` - Context isolation patterns
  - `agents-docs/HOOKS.md` - Hook configuration
  - `agents-docs/CONTEXT.md` - Context engineering & back-pressure
- CLI support:
  - Claude Code (`.claude/`)
  - Gemini CLI (`.gemini/`)
  - OpenCode (`.opencode/`)

### Changed
- Skills use canonical source in `.agents/skills/` with symlinks
- Quality gate exits with code 2 to surface errors to agent
- Progressive disclosure for skills (load on demand)

[Unreleased]: https://github.com/your-org/github-template-ai-agents/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/your-org/github-template-ai-agents/releases/tag/v0.1.0
