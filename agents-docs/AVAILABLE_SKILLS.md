# Available Skills Reference

> Auto-generated from skill definitions in `.agents/skills/`
> Do not edit manually. Run `./scripts/generate-available-skills.sh` to regenerate.

## Agent

| Skill | Description |
|-------|-------------|
| `agent-coordination` | Coordinate multiple agents for software development across any language. Use this skill when running parallel execution of independent tasks, sequential chains with dependencies, swarm analysis from multiple perspectives, or iterative refinement loops — even if they just say "run these in parallel" or "coordinate agents". |
| `delegate` | Lightweight retrieval and context agent skill for rapid information gathering and environment assessment. Use this skill for quick context lookups, finding code patterns, or assessing current state without full implementation overhead — even if they just say "find where X is defined" or "what's the current state of Y". |
| `implementer` | Execution agent skill focused on implementing changes based on an approved Blueprint. Use this skill for targeted, atomic code changes once the plan is solid — even if they just say "implement this" or "make the changes". Gated by human or primary agent approval of the implementation strategy. |
| `intent-classifier` | Classify user intents and route to appropriate skills, commands, or workflows. Use when determining which skill to invoke, routing requests to specialized agents, or building skill selection logic. Trigger on 'which skill should I use', 'route this to', 'classify this request', 'skill selection', or when multiple skills could handle a task. |
| `jules-delegator` | Use this skill to delegate complex coding tasks by creating Jules sessions via the Jules CLI. Use this skill when the user asks to delegate a coding task to Jules, create a Jules session, or hand off implementation work — even if they just say "send this to Jules" or "let Jules handle it". Jules is an AI coding agent that can autonomously implement features, fix bugs, and make code changes across repositories. |

## Analysis

| Skill | Description |
|-------|-------------|
| `triz-analysis` | Run a systematic TRIZ contradiction audit against a codebase, architecture, or workflow to identify hidden trade-offs and innovation opportunities. Use this skill when facing design trade-offs, contradictory requirements, or when needing to identify innovation opportunities through systematic contradiction analysis. |

## Code Quality

| Skill | Description |
|-------|-------------|
| `codacy` | Use the Codacy CLI for local static analysis and cloud data queries. Use the Analysis CLI (`codacy-analysis`) to run local analysis without pushing to Codacy Cloud, or the Cloud CLI (`codacy`) to query remote repositories, issues, security findings, pull requests, and patterns. |
| `code-review-assistant` | Automated code review with PR analysis, change summaries, quality checks, and code smell detection. Use this skill when reviewing pull requests, generating review comments, checking against best practices, identifying code smells, or providing refactoring guidance — even if they just say "review this" or "look at this PR". |
| `css-render-performance` | Guide CSS render performance analysis and optimization. Use this skill when reviewing or writing CSS animations, transitions, scroll-heavy UIs, or long lists — even if they just say "this animation is janky" or "optimize the CSS". Covers compositor layer promotion, paint vs composite, and content-visibility. |
| `iterative-refinement` | Execute iterative refinement workflows with validation loops until quality criteria are met. Use this skill for test-fix cycles, code quality improvement, performance optimization, or any task requiring repeated action-validate-improve cycles — even if they just say "keep improving until it passes" or "iterate on this". |
| `migration-refactoring` | Automate complex code migrations and refactorings with safety patterns. Use this skill when upgrading dependencies, migrating frameworks (React class→hooks, Flask→FastAPI), modernizing languages (Python 2→3), or performing large-scale refactories — even if they just say "migrate this" or "refactor the whole thing". Includes breaking change analysis, automated fix application, rollback strategies, and cross-file dependency tracking. |
| `shell-script-quality` | Lint and test shell scripts using ShellCheck and BATS. Use this skill when checking bash/sh scripts for errors, writing shell script tests, fixing ShellCheck warnings, setting up CI/CD for shell scripts, or improving bash code quality — even if they just say "fix this script" or "add tests for the shell script". |
| `static-analysis` | Triage and fix static analysis findings across any programming language. Use this skill when running linters (ruff, eslint, clippy, shellcheck), analyzing lint output, fixing warnings or errors, or managing cross-language static analysis results in a project. Trigger on "lint", "static analysis", "triage warnings", "fix findings". |

## Compliance

| Skill | Description |
|-------|-------------|
| `eu-ai-act-compliance` | EU AI Act compliance logging and requirements. Use this skill when ensuring transparency, human oversight, and record-keeping per Regulation (EU) 2024/1689 — even if they just say "add compliance logging" or "make sure this is EU AI Act compliant". |

## Database

| Skill | Description |
|-------|-------------|
| `database-devops` | Database design, migration, and DevOps automation with safety patterns. Use this skill when designing schemas, planning migrations, optimizing queries, or managing multi-database orchestration — even if they just say "set up the database" or "fix the migration". Includes rollback strategies, performance analysis, and cross-database synchronization. |
| `turso-db` | Use this skill for Turso (LibSQL/Limbo) database development, including scaffolding, querying, migrations, and maintenance. Supports vector search, full-text search, CDC, MVCC, encryption, and bidirectional remote sync. Use when working with Turso SDKs for JavaScript, Rust, Python, Go, Swift, and React Native. Provides current API guidance to avoid stale "libsql" legacy knowledge. |

## Devops

| Skill | Description |
|-------|-------------|
| `dora-report` | Generate monthly DORA and agentic metrics reports. Use this skill when the user asks to generate a DORA report, pull monthly metrics, create an agentic performance report, report DORA metrics, or when a monthly audit is required — even if they just say 'metrics' or 'performance report'. |

## Documentation

| Skill | Description |
|-------|-------------|
| `agents-md` | Create AGENTS.md files with production-ready best practices. Use this skill when creating new AGENTS.md files, implementing quality gates, or updating agent documentation — even if they just say "add an AGENTS.md" or "set up agent guidance". |
| `architecture-diagram` | Generate or update a project architecture SVG diagram by scanning the live project structure. Use this skill whenever the user asks to regenerate, refresh, or update the architecture diagram, or when skills, agents, or commands have been added/removed and the diagram is stale. Triggers on phrases like "update the diagram", "regenerate the architecture SVG", "sync the diagram", or "diagram is out of date". |
| `readme-best-practices` | Create, audit, and improve GitHub README.md files following 2026 best practices. Use this skill when a user asks to write, rewrite, or review a README.md for a GitHub repository, add shields.io badges, create a project SVG logo, improve documentation structure, or make a repository more discoverable and professional. |

## Innovation Problem Solving

| Skill | Description |
|-------|-------------|
| `triz-solver` | Systematic problem-solving using TRIZ (Theory of Inventive Problem Solving) principles adapted for software engineering. Use when stuck on complex problems, facing technical contradictions, optimizing system design, or seeking innovative solutions beyond trial-and-error. Prevents solving the wrong problem correctly. |

## Knowledge

| Skill | Description |
|-------|-------------|
| `memory-context` | Retrieve semantically relevant past learnings, analysis outputs, and project context using the csm CLI (HDC encoder with hybrid BM25 retrieval). Use this skill when the user needs context retrieval, past session memory, learning recall, or wants to query the memory system for relevant documents or patterns — even if they just say "remember when we..." or "did we solve this before". |

## Knowledge Management

| Skill | Description |
|-------|-------------|
| `learn` | Extract non-obvious session learnings, patterns, and discoveries into scoped AGENTS.md files. Use this skill after completing non-trivial tasks, when the user says "extract learnings", "save patterns", "update AGENTS.md", or whenever the session has produced insights that should be captured for future reference — even if they just say "what did we learn" or "save this for later". |

## Platform

| Skill | Description |
|-------|-------------|
| `api-design-first` | Design and document RESTful APIs using design-first principles with OpenAPI specifications. Use this skill when the user asks to design an API, create an API spec, plan endpoints, model request/response schemas, or discuss API versioning — even if they just say "design the API" or "create the OpenAPI spec". |
| `codeberg-api` | Interact with Forgejo/Codeberg repositories via the REST API — read or write files, manage issues, create pull requests, list branches/tags, search repos, and automate CI/CD workflows. Use this skill when the user wants to: read file contents from a Forgejo repo, create or update files, manage issues (create, list, close), list repositories for a user, search, set up Forgejo Actions workflows, or automate any git-forge operation. Works without authentication for public repos; requires FORGEJO_TOKEN for private repos and write operations. |
| `durable-objects` | Create and review Cloudflare Durable Objects. Use when building stateful coordination (chat rooms, multiplayer games, booking systems), implementing RPC methods, SQLite storage, alarms, WebSockets, or reviewing DO code for best practices. Covers Workers integration, wrangler config, and testing with Vitest. Biases towards retrieval from Cloudflare docs over pre-trained knowledge. |

## Quality

| Skill | Description |
|-------|-------------|
| `dogfood` | Systematically explore and test a web application to find bugs, UX issues, and other problems. Use when asked to "dogfood", "QA", "exploratory test", "find issues", "bug hunt", "test this app/site/platform", or review the quality of a web application. Produces a structured report with full reproduction evidence. |
| `lifecycle-management` | Manage application lifecycle, error handling, and resource cleanup to prevent memory leaks and ensure stability. Use this skill when handling startup/shutdown sequences, managing resource pools, implementing error boundaries, preventing memory leaks, or ensuring graceful degradation — even if they just say "clean up resources" or "fix the memory leak". |
| `skill-creator` | Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy. |
| `skill-evaluator` | Reusable skill for evaluating other skills with structure checks, eval coverage review, and real usage spot checks. Use when you need to check a skill, add evals, benchmark a skill, validate outputs against assertions, or compare current skill behavior against a baseline. |
| `testdata-builders` | Maintain deterministic builders/factories for test entities. Use this skill when authoring tests, extending test utilities, or adding schema fields that affect fixtures — even if they just say "create test data" or "build a factory for this". |
| `verification-template` | Template for creating portable domain-specific verification skills. Use this as a starting point when defining systematic verification checklists for new features, modules, or domain-specific operations — even if they just say "create a verification checklist" or "add quality checks for this". |

## Security

| Skill | Description |
|-------|-------------|
| `privacy-first` | Prevent email addresses and personal data from entering the codebase. Use when user asks to "prevent emails", "remove personal data", "privacy check", "no email", or when writing/ editing any code, config, or documentation files. |
| `security-code-auditor` | Perform security audits on code to identify vulnerabilities, misconfigurations, and security anti-patterns. Use when users ask to 'audit', 'review', or 'check security' of code, configurations, or repositories. Trigger on keywords like 'security review', 'vulnerability scan', 'OWASP', 'secure coding', 'penetration test', or 'security assessment'. |

## Testing

| Skill | Description |
|-------|-------------|
| `test-runner` | Execute tests, analyze results, and diagnose failures across any testing framework. Use this skill when running test suites, debugging failing tests, or configuring CI/CD testing pipelines — even if they just say "run the tests" or "why is this test failing". |
| `testing-strategy` | Design and implement comprehensive testing strategies for software projects. Use this skill when planning test suites, choosing testing approaches like property-based testing, visual regression, load testing, mutation testing, or E2E test generation — even if they just say "how should we test this" or "what testing approach should we use". |

## Tool

| Skill | Description |
|-------|-------------|
| `agent-browser` | Browser automation CLI for AI agents. Use when the user needs to interact with websites, including navigating pages, filling forms, clicking buttons, taking screenshots, extracting data, testing web apps, or automating any browser task. Triggers include requests to "open a website", "fill out a form", "click a button", "take a screenshot", "scrape data from a page", "test this web app", "login to a site", "automate browser actions", or any task requiring programmatic web interaction. |
| `dist-channel-selection` | Guide for selecting the correct distribution channel (npm, Cargo, etc.) based on artifact type and target audience. Use this skill when preparing to publish or release a new version of a package — even if they just say "publish this" or "release it". |
| `do-web-doc-resolver` | Python resolver for URLs and queries into compact, LLM-ready markdown. Use this skill when fetching documentation, resolving web URLs, or building context from web sources — even if they just say "read this doc page" or "get the docs for X". Uses progressive free-first cascade with quality scoring, circuit breakers, layered routing memory, trace-based evaluation, and agent-friendly docs validation. |
| `template-version-management` | Manage versioning in a template repository. Use when working with template repos where `VERSION` is intentionally pinned to 0.0.0, when bumping the template's own release version, when fixing stale version badges, or when answering questions about how versioning flows from `VERSION`/`CHANGELOG-TEMPLATE.md` to `README.md`. Triggers on "template version", "bump template", "changelog-template", "version badge", "propagate-version", "bump_patch_version", "what's the template version", "stale version badge". |
| `web-search-researcher` | Research topics using web search to find accurate, current information. Use this skill when you need modern information, official documentation, best practices, or technical solutions beyond training data — even if they just say "look this up" or "search for how to do X". |

## Ui Ux

| Skill | Description |
|-------|-------------|
| `accessibility-auditor` | Audit web applications for WCAG 2.2 compliance, screen reader compatibility, keyboard navigation, and color contrast. Use this skill when the user asks for an accessibility audit, a11y check, WCAG compliance review, screen reader test, keyboard navigation check, color contrast check, or ARIA validation — even if they don't explicitly mention "accessibility" or "WCAG". Also triggers on Section 508 and ADA compliance requests. |

| `ui-ux-optimize` | Swarm-powered UI/UX prompt optimizer with auto-research agents, handoff coordination, confidence-scored autoresearch loops, and backpressure quality gates. Use this skill when optimizing UI/UX for web apps, mobile apps, games, dashboards, SaaS, e-commerce, kiosks, or any screen-based product. |

## Workflow

| Skill | Description |
|-------|-------------|
| `cicd-pipeline` | Design and implement CI/CD pipelines with GitHub Actions, GitLab CI, and Forgejo Actions. Use this skill when the user asks to set up, optimize, or troubleshoot CI/CD pipelines, configure workflow triggers, manage secrets in pipelines, handle pipeline failures, or implement deployment strategies — even if they don't say "CI/CD" explicitly. |
| `cloudflare-worker-api` | Structure Worker API routes and handlers. Use this skill when defining Cloudflare Worker routes, building response helpers, or implementing typed handler patterns — even if they just say "set up the worker routes" or "add an API endpoint to the worker". Auth belongs to secure-invite-and-access. |
| `docs-hook` | Lightweight git hook integration for updating agents-docs with minimal tokens. Use this skill when updating agents-docs on commit or merge events to sync documentation — even if they just say "update the docs" or "sync the agent docs". |
| `document-rendering-and-locators` | Implement resilient document rendering and annotation anchoring. Use this skill when working with reader-core rendering, TOC generation, locator systems, or highlight anchoring changes — even if they just say "fix the document rendering" or "the highlights aren't sticking". Generic pattern applicable to EPUB, PDF, or any document format. |
| `git-github-workflow` | Unified atomic git workflow with GitHub integration — validates, commits conventionally, checks issues, creates PR, monitors ALL Actions with pre-existing detection, uses swarm/web research, auto-merges with strategy selection, and post-merge validates. Use this skill when the user asks to commit code, create a PR, push changes, merge, or manage the full git lifecycle — even if they just say "push it" or "ship it". |
| `github-pr-sentinel` | Monitor a GitHub pull request until it's merged, green, or blocked. Polls CI checks, review comments, and mergeability state continuously. Use this skill when the user asks to monitor a PR, watch CI, handle review comments, sentinel a PR, babysit a PR, or keep an eye on failures and feedback — even if they just say "check on the PR" or "is it green yet". |
| `goap-agent` | Invoke for complex multi-step tasks requiring intelligent planning and multi-agent coordination. Use when tasks need decomposition, dependency mapping, parallel/sequential/swarm/iterative execution strategies, or coordination of multiple specialized agents with quality gates. |
| `pwa-offline-sync` | Design Cache Storage + IndexedDB strategy and sync queue. Use this skill when building service workers, implementing caching strategies, or investigating offline bugs — even if they just say "make it work offline" or "add caching". Generic pattern for any offline-first application. |
| `reader-ui-ux` | Build localized, accessible reader/admin UI with responsive layouts, telemetry, and state management. Use this skill when building React screens, polishing UX, or implementing responsive layouts for reader or admin interfaces — even if they just say "fix the UI" or "make it responsive". Generic pattern for any document reader application. |
| `secure-invite-and-access` | Implement access control, authentication, and authorization patterns. Use this skill when building auth endpoints, managing permissions, implementing session/token logic, or generating signed URLs — even if they just say "add auth" or "secure this endpoint". Generic template adaptable to any project's auth needs. |

## Usage

Skills are triggered automatically based on context or loaded explicitly.
See `agents-docs/SKILLS.md` for loading skills manually.

## See Also

- `agents-docs/SKILLS.md` - Skill authoring guide
- `.agents/skills/skill-rules.json` - Skill validation rules
