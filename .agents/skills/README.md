# .agents/skills/ - Canonical Skill Source

This is the **single canonical location** for all skills in this repository.

Claude Code, Gemini CLI, and Qwen Code use symlinks; OpenCode reads directly from `.agents/skills/`:

```
.claude/skills/<name>      -> ../../.agents/skills/<name>
.gemini/skills/<name>      -> ../../.agents/skills/<name>
.qwen/skills/<name>        -> ../../.agents/skills/<name>
```

## Setup

After cloning, run once to create all symlinks:

```bash
./scripts/setup-skills.sh
```

Validate symlinks are intact:

```bash
./scripts/validate-skills.sh
```

## Adding a New Skill

1. Create `.agents/skills/<skill-name>/SKILL.md` (see `agents-docs/SKILLS.md`)
2. Add `reference/` folder for detailed content (optional)
3. Run `./scripts/setup-skills.sh` to create symlinks for all CLI tools
4. The skill is now available in Claude Code, OpenCode, Gemini CLI, and Qwen Code

## Skills in This Repository

| Skill | Description |
|---|---|
| [`agent-coordination/`](agent-coordination/) | Multi-agent orchestration patterns (hybrid, iterative, parallel, sequential, swarm) |
| [`github-readme/`](github-readme/) | Create human-focused GitHub README.md files with 2026 best practices |
| [`goap-agent/`](goap-agent/) | Goal-Oriented Action Planning agent execution strategies |
| [`iterative-refinement/`](iterative-refinement/) | Iterative code improvement patterns with validation loops |
| [`parallel-execution/`](parallel-execution/) | Parallel task execution patterns |
| [`shell-script-quality/`](shell-script-quality/) | Shell script linting (ShellCheck) and testing (BATS) |
| [`skill-creator/`](skill-creator/) | Create new skills with proper structure and best practices |
| [`task-decomposition/`](task-decomposition/) | Break complex tasks into manageable steps |
| [`web-doc-resolver/`](web-doc-resolver/) | Resolve and fetch web documentation with cascade fallback |
| [`web-search-researcher/`](web-search-researcher/) | Research topics using web search with systematic methodology |