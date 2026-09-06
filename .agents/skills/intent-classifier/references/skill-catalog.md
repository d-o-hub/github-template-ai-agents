# Skill Catalog

> Auto-generated from `.agents/skills/` directory.
> Last updated: 2026-08-16
> Do not edit manually. Run `./scripts/generate-skill-catalog.sh`.

## Available Skills

| Skill | Description | Category |
|-------|-------------|----------|
| accessibility-auditor | Audit web applications for WCAG 2.2 compliance, screen reader compatibility, keyboard navigation, and color contrast. Use this skill when the user asks for an accessibility audit, a11y check, WCAG compliance review, s... | ui-ux |
| agent-browser | Browser automation CLI for AI agents. Use when the user needs to interact with websites — navigating pages, filling forms, clicking buttons, taking screenshots, scraping data, testing web apps, or automating any brows... | tool |
| agent-coordination | Coordinate multiple agents for software development across any language. Use this skill when running parallel execution of independent tasks, sequential chains with dependencies, swarm analysis from multiple perspecti... | agent |
| agentic-abstention | No description available | agent |
| agents-md | Create AGENTS.md files with production-ready best practices. Use this skill when creating new AGENTS.md files, implementing quality gates, or updating agent documentation — even if they just say "add an AGENTS.md" or ... | documentation |
| api-design-first | Design and document RESTful APIs using design-first principles with OpenAPI specifications. Use this skill when the user asks to design an API, create an API spec, plan endpoints, model request/response schemas, or di... | platform |
| architecture-diagram | Generate or update a project architecture SVG diagram by scanning the live project structure. Use this skill whenever the user asks to regenerate, refresh, or update the architecture diagram, or when skills, agents, o... | documentation |
| avoid-ai-writing | Audit and rewrite content to remove AI writing patterns ("AI-isms"). Use this skill when asked to "remove AI-isms," "clean up AI writing," "edit writing for AI patterns," "audit writing for AI tells," or "make this so... | quality |
| cicd-pipeline | Design and configure CI/CD pipelines with GitHub Actions, GitLab CI, and Forgejo Actions. Use this skill when the user asks to create a new workflow, set up pipeline triggers, configure caching or matrix builds, manag... | workflow |
| cloudflare-worker-api | No description available | workflow |
| codacy | Use the Codacy CLI for local static analysis and cloud data queries. Use the Analysis CLI (`codacy-analysis`) to run local analysis without pushing to Codacy Cloud, or the Cloud CLI (`codacy`) to query remote reposito... | code-quality |
| code-review-assistant | Automated code review with PR analysis, change summaries, quality checks, and code smell detection. Use this skill when reviewing pull requests, generating review comments, checking against best practices, identifying... | code-quality |
| codeberg-api | No description available | platform |
| css-render-performance | Guide CSS render performance analysis and optimization. Use this skill when reviewing or writing CSS animations, transitions, scroll-heavy UIs, or long lists — even if they just say "this animation is janky" or "optim... | code-quality |
| database-devops | Database design, migration, and DevOps automation with safety patterns. Use this skill when designing schemas, planning migrations, optimizing queries, or managing multi-database orchestration — even if they just say ... | database |
| delegate | Lightweight retrieval and context agent skill for rapid information gathering and environment assessment. Use this skill when you need quick context lookups, finding code patterns, or assessing current state without f... | agent |
| dist-channel-selection | Guide for selecting the correct distribution channel (npm, Cargo, etc.) based on artifact type and target audience. Use this skill when preparing to publish or release a new version of a package — even if they just sa... | tool |
| do-web-doc-resolver | Python resolver for URLs and queries into compact, LLM-ready markdown. Use this skill when fetching documentation, resolving web URLs, or building context from web sources — even if they just say "read this doc page" ... | tool |
| docs-hook | Lightweight git hook integration for updating agents-docs with minimal tokens. Use this skill when updating agents-docs on commit or merge events to sync documentation — even if they just say "update the docs" or "syn... | workflow |
| document-rendering-and-locators | No description available | workflow |
| dogfood | Systematically explore and test a web application to find bugs, UX issues, and other problems. Use when asked to "dogfood", "QA", "exploratory test", "find issues", "bug hunt", "test this app/site/platform", or review... | quality |
| dora-report | Generate monthly DORA and agentic metrics reports. Use this skill when the user asks for a DORA report, monthly metrics, or a monthly audit. Not for readme-best-practices. | devops |
| durable-objects | Create and review Cloudflare Durable Objects. Use when building stateful coordination (chat rooms, multiplayer games, booking systems), implementing RPC methods, SQLite storage, alarms, WebSockets, or reviewing DO cod... | platform |
| eu-ai-act-compliance | EU AI Act compliance logging and requirements. Use this skill when ensuring transparency, human oversight, and record-keeping per Regulation (EU) 2024/1689 — even if they just say "add compliance logging" or "make sur... | compliance |
| git-github-workflow | Orchestrates the full git-to-merge lifecycle: validate → commit → check issues → create PR → monitor ALL GitHub Actions (including pre-existing failures) → fix via swarm/web research → merge with strategy selection → ... | workflow |
| github-pr-sentinel | Monitor a GitHub pull request until it's merged, green, or blocked. Polls CI checks, review comments, and mergeability state continuously. Use this skill when the user asks to monitor a PR, watch CI, handle review com... | workflow |
| goap-agent | Orchestrates complex multi-step tasks with intelligent planning: analyze the problem, decompose into sub-goals, select execution strategy, assign agents, and coordinate with quality gates. Use this skill when the user... | workflow |
| implementer | Execution agent skill focused on implementing changes based on an approved Blueprint. Use this skill when implementing targeted, atomic code changes once the plan is solid — even if they just say "implement this" or "... | agent |
| intent-classifier | Classify user intents and route to appropriate skills, commands, or workflows. Use when determining which skill to invoke, routing requests to specialized agents, or building skill selection logic. Trigger on 'which s... | agent |
| iterative-refinement | Execute iterative refinement workflows with validation loops until quality criteria are met. Use this skill when running test-fix cycles, code quality improvement, performance optimization, or any task requiring repea... | code-quality |
| jules-delegator | Use this skill to delegate complex coding tasks by creating Jules sessions via the Jules CLI. Use this skill when the user asks to delegate a coding task to Jules, create a Jules session, or hand off implementation wo... | agent |
| learn | Extract non-obvious session learnings, patterns, and discoveries into scoped AGENTS.md files. Use this skill when the user wants to extract learnings after completing non-trivial tasks, or when they say "extract learn... | knowledge-management |
| lifecycle-management | Manage application lifecycle, error handling, and resource cleanup to prevent memory leaks and ensure stability. Use this skill when handling startup/shutdown sequences, managing resource pools, implementing error bou... | quality |
| memory-context | Retrieve semantically relevant past learnings, analysis outputs, and project context using the csm CLI (HDC encoder with hybrid BM25 retrieval). Use this skill when the user needs context retrieval, past session memor... | knowledge |
| migration-refactoring | Automate complex code migrations and refactorings with safety patterns. Use this skill when upgrading dependencies, migrating frameworks (React class→hooks, Flask→FastAPI), modernizing languages (Python 2→3), or perfo... | code-quality |
| privacy-first | No description available | security |
| pwa-offline-sync | No description available | workflow |
| reader-ui-ux | No description available | workflow |
| readme-best-practices | No description available | documentation |
| secure-invite-and-access | No description available | workflow |
| security-code-auditor | Perform security audits on code to identify vulnerabilities, misconfigurations, and security anti-patterns. Use when users ask to 'audit', 'review', or 'check security' of code, configurations, or repositories — even ... | security |
| shell-script-quality | Lint and test shell scripts using ShellCheck and BATS. Use this skill when checking bash/sh scripts for errors, writing shell script tests, fixing ShellCheck warnings, setting up CI/CD for shell scripts, or improving ... | code-quality |
| skill-creator | Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill... | quality |
| skill-evaluator | Reusable skill for evaluating other skills with structure checks, eval coverage review, and real usage spot checks. Use when you need to check a skill, add evals, benchmark a skill, validate outputs against assertions... | quality |
| static-analysis | Triage and fix static analysis findings across any programming language. Use this skill when running linters (ruff, eslint, clippy, shellcheck), analyzing lint output, fixing warnings or errors, or managing cross-lang... | code-quality |
| template-version-management | Manage versioning in a template repository. Use when working with template repos where `VERSION` is intentionally pinned to 0.0.0, when bumping the template's own release version, when fixing stale version badges, or ... | tool |
| test-runner | Execute tests, analyze results, and diagnose failures across any testing framework. Use this skill when running test suites, debugging failing tests, or configuring CI/CD testing pipelines — even if they just say "run... | testing |
| testdata-builders | No description available | quality |
| testing-strategy | Design and implement comprehensive testing strategies for software projects. Use this skill when planning test suites, choosing testing approaches like property-based testing, visual regression, load testing, mutation... | testing |
| triz-analysis | Run a systematic TRIZ contradiction audit against a codebase, architecture, or workflow to identify hidden trade-offs and innovation opportunities. Use this skill when facing design trade-offs, contradictory requireme... | analysis |
| triz-solver | Systematic problem-solving using TRIZ (Theory of Inventive Problem Solving) principles adapted for software engineering. Use when stuck on complex problems, facing technical contradictions, optimizing system design, o... | innovation-problem-solving |
| turso-db | Use this skill for Turso (LibSQL/Limbo) database development, including scaffolding, querying, migrations, and maintenance. Supports vector search, full-text search, CDC, MVCC, encryption, and bidirectional remote syn... | database |
| ui-ux-optimize | No description available | ui-ux |
| verification-template | Template for creating portable domain-specific verification skills. Use this skill when creating a verification checklist as a starting point for defining systematic verification checklists for new features, modules, ... | quality |
| voice-profiles | No description available | quality |
| web-search-researcher | Research topics using web search to find accurate, current information. Use this skill when you need modern information, official documentation, best practices, or technical solutions beyond training data — even if th... | tool |

## Skill Categories

### agent

- agent-coordination
- agentic-abstention
- delegate
- implementer
- intent-classifier
- jules-delegator

### analysis

- triz-analysis

### code-quality

- codacy
- code-review-assistant
- css-render-performance
- iterative-refinement
- migration-refactoring
- shell-script-quality
- static-analysis

### compliance

- eu-ai-act-compliance

### database

- database-devops
- turso-db

### devops

- dora-report

### documentation

- agents-md
- architecture-diagram
- readme-best-practices

### innovation-problem-solving

- triz-solver

### knowledge

- memory-context

### knowledge-management

- learn

### platform

- api-design-first
- codeberg-api
- durable-objects

### quality

- avoid-ai-writing
- dogfood
- lifecycle-management
- skill-creator
- skill-evaluator
- testdata-builders
- verification-template
- voice-profiles

### security

- privacy-first
- security-code-auditor

### testing

- test-runner
- testing-strategy

### tool

- agent-browser
- dist-channel-selection
- do-web-doc-resolver
- template-version-management
- web-search-researcher

### ui-ux

- accessibility-auditor
- ui-ux-optimize

### workflow

- cicd-pipeline
- cloudflare-worker-api
- docs-hook
- document-rendering-and-locators
- git-github-workflow
- github-pr-sentinel
- goap-agent
- pwa-offline-sync
- reader-ui-ux
- secure-invite-and-access

## Usage

The `intent-classifier` skill uses this catalog for routing.
Regenerate after adding, renaming, or removing skills.
