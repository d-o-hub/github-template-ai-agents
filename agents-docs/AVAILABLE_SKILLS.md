# Available Skills Reference

> Complete registry of all skills in `.agents/skills/`
> Auto-generated from skill definitions

## By Category

### Coordination
| Skill | Description |
|-------|-------------|
| `agent-coordination` | Coordinate multiple agents for software development across any language |
| `goap-agent` | Complex multi-step tasks with intelligent planning and multi-agent coordination |
| `intent-classifier` | Classify user intents and route to appropriate skills/commands |
| `parallel-execution` | Execute multiple independent tasks simultaneously |
| `task-decomposition` | Break down complex tasks into atomic, actionable goals |

### DevOps
| Skill | Description |
|-------|-------------|
| `cicd-pipeline` | Design and implement CI/CD pipelines with GitHub Actions, GitLab CI, Forgejo |
| `codeberg-api` | Interact with Forgejo/Codeberg repositories via REST API |
| `database-devops` | Database design, migration, and DevOps automation |

### Documentation
| Skill | Description |
|-------|-------------|
| `architecture-diagram` | Generate or update project architecture SVG diagrams |
| `docs-hook` | Git hook integration for updating agents-docs |
| `github-readme` | Create human-focused GitHub README.md files |

### Migration & Modernization
| Skill | Description |
|-------|-------------|
| `migration-refactoring` | Automate complex code migrations (React class→hooks, Flask→FastAPI, etc.) |

### Quality & Security
| Skill | Description |
|-------|-------------|
| `accessibility-auditor` | Audit web applications for WCAG 2.2 compliance |
| `code-quality` | Code quality analysis and improvement |
| `code-review-assistant` | Automated code review with PR analysis |
| `iterative-refinement` | Execute iterative refinement workflows with validation loops |
| `privacy-first` | Prevent email addresses and personal data in codebase |
| `security-code-auditor` | Security audits for vulnerabilities and misconfigurations |
| `shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS |
| `testing-strategy` | Comprehensive testing strategies with modern techniques |

### Research
| Skill | Description |
|-------|-------------|
| `do-web-doc-resolver` | Resolve URLs and queries into compact, LLM-ready markdown |
| `web-search-researcher` | Research topics using web search |

### Knowledge Management
| Skill | Description |
|-------|-------------|
| `learn` | Extract non-obvious session learnings into scoped AGENTS.md files |

### Meta (Skill Management)
| Skill | Description |
|-------|-------------|
| `agents-md` | Create AGENTS.md files with production-ready best practices |
| `skill-creator` | Create new skills and modify existing ones |
| `skill-evaluator` | Evaluate other skills with structure checks and spot tests |

### Innovation & Problem Solving
| Skill | Description |
|-------|-------------|
| `triz-solver` | Systematic problem-solving using TRIZ principles |
| `ui-ux-optimize` | Swarm-powered UI/UX prompt optimizer |

### API Development
| Skill | Description |
|-------|-------------|
| `api-design-first` | Design and document RESTful APIs with OpenAPI |

### General
| Skill | Description |
|-------|-------------|
| `anti-ai-slop` | Avoid generic "AI slop" aesthetic in UI/UX |
| `test-runner` | Test execution and result aggregation |

## Usage

Skills are triggered automatically based on context or loaded explicitly.
See `agents-docs/SKILLS.md` for loading skills manually.

## See Also

- `agents-docs/SKILLS.md` - Skill authoring guide
- `.agents/skills/skill-rules.json` - Skill validation rules
