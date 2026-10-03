# Skill Catalog

> Auto-generated from `.agents/skills/` directory.
> Last updated: 2026-10-03
> Do not edit manually. Run `./scripts/generate-skill-catalog.sh`.
> Description budget: 1024 chars (Agent Skills spec cap).
> Elided text ends on a word boundary and always keeps the `Not for <sibling>` guard.

## Available Skills

| Skill | Description | Category |
|-------|-------------|----------|
| accessibility-auditor | Audit web applications for WCAG 2.2 compliance, screen reader compatibility, keyboard navigation, and color contrast. Use this skill when the user asks for an accessibility audit, a11y check, WCAG compliance review, screen reader test, keyboard navigation check, color contrast check, or ARIA validation — even if they don't explicitly mention "accessibility" or "WCAG". Also triggers on Section 508 and ADA compliance requests. Not for css-render-performance. | ui-ux |
| agent-browser | Browser automation CLI for AI agents. Use when the user needs to interact with websites — navigating pages, filling forms, clicking buttons, taking screenshots, scraping data, testing web apps, or automating any browser task. Even if they just say "open this website", "click that button", "take a screenshot", or "fill out this form". Not for web search (use web-search-researcher), fetching documentation (use do-web-doc-resolver), or reading URLs (use do-web-doc-resolver). | tool |
| agentic-abstention | Encode CONVOLVE-style stopping rules: decide when to stop acting instead of continuing tool calls on an infeasible task. Use this skill whenever an agent must determine if further execution is warranted. Not for general task planning (use goap-agent). | agent |
| agents-md | Create AGENTS.md files with production-ready best practices. Use this skill when creating new AGENTS.md files, implementing quality gates, or updating agent documentation — even if they just say "add an AGENTS.md" or "set up agent guidance". Not for readme-best-practices, skill-creator. | documentation |
| api-design-first | Design and document RESTful APIs using design-first principles with OpenAPI specifications. Use this skill when the user asks to design an API, create an API spec, plan endpoints, model request/response schemas, or discuss API versioning — even if they just say "design the API" or "create the OpenAPI spec". Not for cloudflare-worker-api. | platform |
| architecture-diagram | Generate or update a project architecture SVG diagram by scanning the live project structure. Use this skill whenever the user asks to regenerate, refresh, or update the architecture diagram, or when skills, agents, or commands have been added/removed and the diagram is stale — even if they just say "update the diagram" or "regenerate the architecture SVG". Triggers on phrases like "update the diagram", "regenerate the architecture SVG", "sync the diagram", or "diagram is out of date". Not for readme-best-practices. | documentation |
| avoid-ai-writing | Audit and rewrite content to remove AI writing patterns ("AI-isms"). Use this skill when asked to "remove AI-isms," "clean up AI writing," "edit writing for AI patterns," "audit writing for AI tells," or "make this sound less like AI." Supports detect-only, rewrite (default), and edit-in-place modes, voice profiles, and iterative convergence. | quality |
| cicd-pipeline | Design and configure CI/CD pipelines with GitHub Actions, GitLab CI, and Forgejo Actions. Use this skill when the user asks to create a new workflow, set up pipeline triggers, configure caching or matrix builds, manage CI secrets, troubleshoot pipeline failures, or compare pipeline platforms — even if they don't say "CI/CD" explicitly. Not for monitoring an existing PR's CI (use git-github-workflow) or executing deployments (use deployment-specific tooling). | workflow |
| cloudflare-worker-api | Structure Worker API routes and handlers. Use this skill when defining Cloudflare Worker routes, building response helpers, or implementing typed handler patterns — even if they just say "set up the worker routes" or "add an API endpoint to the worker". Auth belongs to secure-invite-and-access. Not for api-design-first, cicd-pipeline. | workflow |
| codacy | Use the Codacy CLI for local static analysis and cloud data queries. Use the Analysis CLI (`codacy-analysis`) to run local analysis without pushing to Codacy Cloud, or the Cloud CLI (`codacy`) to query remote repositories, issues, security findings, pull requests, and patterns. Use when the user wants to analyze code locally, check code quality metrics on Codacy Cloud, inspect remote PR results, browse vulnerabilities, or search patterns — even if they just say "run codacy" or "check code quality". Not for generic linter triage (use static-analysis). | code-quality |
| code-review-assistant | Automated code review with PR analysis, change summaries, quality checks, and code smell detection. Use this skill when reviewing pull requests, generating review comments, checking against best practices, identifying code smells, or providing refactoring guidance — even if they just say "review this" or "look at this PR". Not for static-analysis, security-code-auditor. | code-quality |
| codeberg-api | Interact with Forgejo/Codeberg repositories via the REST API — read or write files, manage issues, create pull requests, list branches/tags, search repos, and automate CI/CD workflows. Use this skill when the user wants to interact with a Forgejo or Codeberg repository, even if they just say "read a file from Codeberg" or "create an issue on my Forgejo repo". Not for GitHub (use git-github-workflow) or GitLab (use cicd-pipeline). | platform |
| css-render-performance | Guide CSS render performance analysis and optimization. Use this skill when reviewing or writing CSS animations, transitions, scroll-heavy UIs, or long lists — even if they just say "this animation is janky" or "optimize the CSS". Covers compositor layer promotion, paint vs composite, and content-visibility. Not for accessibility-auditor, ui-ux-optimize. | code-quality |
| database-devops | Database design, migration, and DevOps automation with safety patterns. Use this skill when designing schemas, planning migrations, optimizing queries, or managing multi-database orchestration — even if they just say "set up the database" or "fix the migration". Includes rollback strategies, performance analysis, and cross-database synchronization. Not for turso-db. | database |
| debugger | Diagnose failing builds and runtime errors with root-cause discipline. Use when a build, deploy, or service crashes, or an error appears at runtime — even if they just say "debug this crash" or "why does the server 502". Not for test-runner (failing or flaky tests in a suite), iterative-refinement (repeat-until-pass loops), security-code-auditor (vulnerabilities). | code-quality |
| delegate | Lightweight retrieval and context agent skill for rapid information gathering and environment assessment. Use this skill when you need quick context lookups, finding code patterns, or assessing current state without full implementation overhead — even if they just say "find where X is defined" or "what's the current state of Y". | agent |
| dependency-upgrades | Perform routine, low-risk dependency version bumps and vulnerability-driven upgrades (patch/minor, or major with no source changes). Use when updating packages, action pins, pre-commit hooks, lockfiles, or base images — even if they just say "bump lodash" or "fix this CVE". Not for migration-refactoring (major bumps that force source changes, framework or language migrations). | devops |
| dist-channel-selection | Guide for selecting the correct distribution channel (npm, Cargo, etc.) based on artifact type and target audience. Use this skill when preparing to publish or release a new version of a package — even if they just say "publish this" or "release it". Not for cicd-pipeline. | tool |
| do-web-doc-resolver | Python resolver for URLs and queries into compact, LLM-ready markdown. Use this skill when fetching documentation, resolving web URLs, or building context from web sources — even if they just say "read this doc page" or "get the docs for X". Uses progressive free-first cascade with quality scoring, circuit breakers, layered routing memory, trace-based evaluation, and agent-friendly docs validation. Not for web-search-researcher, agent-browser. | tool |
| docs-hook | Lightweight git hook integration for updating agents-docs with minimal tokens. Use this skill when updating agents-docs on commit or merge events to sync documentation — even if they just say "update the docs" or "sync the agent docs". Not for learn, agents-md. | workflow |
| document-rendering-and-locators | Implement resilient document rendering and annotation anchoring. Use this skill when working with reader-core rendering, TOC generation, locator systems, or highlight anchoring changes — even if they just say "fix the document rendering" or "the highlights aren't sticking". Generic pattern applicable to EPUB, PDF, or any document format. Not for reader-ui-ux. | workflow |
| dogfood | Systematically explore and test a web application to find bugs, UX issues, and other problems. Use when asked to "dogfood", "QA", "exploratory test", "find issues", "bug hunt", "test this app/site/platform", or review the quality of a web application. Produces a structured report with full reproduction evidence. Not for test-runner, accessibility-auditor. | quality |
| dora-report | Generate monthly DORA and agentic metrics reports. Use this skill when the user asks for a DORA report, monthly metrics, or a monthly audit. Not for security-code-auditor, readme-best-practices. | devops |
| durable-objects | Create and review Cloudflare Durable Objects. Use when building stateful coordination (chat rooms, multiplayer games, booking systems), implementing RPC methods, SQLite storage, alarms, WebSockets, or reviewing DO code for best practices. Even if they just say "create a Durable Object", "add RPC methods", or "set up SQLite in a DO". Covers Workers integration, wrangler config, and testing with Vitest. Biases towards retrieval from Cloudflare docs over pre-trained knowledge. Not for Worker API routes (use cloudflare-worker-api) or general Workers deployment. | platform |
| eu-ai-act-compliance | EU AI Act compliance logging and requirements. Use this skill when ensuring transparency, human oversight, and record-keeping per Regulation (EU) 2024/1689 — even if they just say "add compliance logging" or "make sure this is EU AI Act compliant". Not for security-code-auditor, privacy-first. | compliance |
| git-github-workflow | Orchestrates the full git-to-merge lifecycle: validate → commit → check issues → create PR → monitor ALL GitHub Actions (including pre-existing failures) → fix via swarm/web research → merge with strategy selection → post-merge validate. Use this skill when the user asks to ship changes end-to-end, manage a PR through CI, or handle the complete commit-to-merge workflow — even if they just say "push it" or "ship it". Not for simple one-off git operations (revert, squash, cherry-pick), isolated tasks (just review, just test, just lint), or secret lifecycle work such as rotation and revocation (use secrets-management). | workflow |
| goap-agent | Orchestrates complex multi-step tasks with intelligent planning: analyze the problem, decompose into sub-goals, select execution strategy, assign agents, and coordinate with quality gates. Use this skill when the user asks to plan a large change, break down a complex problem, coordinate multiple agents, or systematically tackle a multi-file refactoring — even if they just say "plan this out" or "how should we approach this". Not for simple single-step tasks (use delegate) or implementing from an approved plan (use implementer). | workflow |
| implementer | Execution agent skill focused on implementing changes based on an approved Blueprint. Use this skill when implementing targeted, atomic code changes once the plan is solid — even if they just say "implement this" or "make the changes". Gated by human or primary agent approval of the implementation strategy. | agent |
| intent-classifier | Classify user intents and route to appropriate skills, commands, or workflows. Use when determining which skill to invoke, routing requests to specialized agents, or building skill selection logic. Trigger on 'which skill should I use', 'route this to', 'classify this request', 'skill selection', or when multiple skills could handle a task. Not for skill-creator, skill-evaluator. | agent |
| iterative-refinement | Execute iterative refinement workflows with validation loops until quality criteria are met. Use this skill when running test-fix cycles, code quality improvement, performance optimization, or any task requiring repeated action-validate-improve cycles — even if they just say "keep improving until it passes" or "iterate on this". Not for testing-strategy. | code-quality |
| jules-delegator | Use this skill to delegate complex coding tasks by creating Jules sessions via the Jules CLI. Use this skill when the user asks to delegate a coding task to Jules, create a Jules session, or hand off implementation work — even if they just say "send this to Jules" or "let Jules handle it". Jules is an AI coding agent that can autonomously implement features, fix bugs, and make code changes across repositories. Not for git-github-workflow. | agent |
| learn | Extract non-obvious session learnings, patterns, and discoveries into scoped AGENTS.md files. Use this skill when the user wants to extract learnings after completing non-trivial tasks, or when they say "extract learnings", "save patterns", "update AGENTS.md", or whenever the session has produced insights that should be captured for future reference — even if they just say "what did we learn" or "save this for later". Not for agents-md, skill-creator. | knowledge-management |
| lifecycle-management | Manage application lifecycle, error handling, and resource cleanup to prevent memory leaks and ensure stability. Use this skill when handling startup/shutdown sequences, managing resource pools, implementing error boundaries, preventing memory leaks, or ensuring graceful degradation — even if they just say "clean up resources" or "fix the memory leak". Not for security-code-auditor. | quality |
| memory-context | Retrieve semantically relevant past learnings, analysis outputs, and project context using the csm CLI (HDC encoder with hybrid BM25 retrieval). Use this skill when the user needs context retrieval, past session memory, learning recall, or wants to query the memory system for relevant documents or patterns — even if they just say "remember when we..." or "did we solve this before". Not for learn, delegate. | knowledge |
| migration-refactoring | Automate complex code migrations and refactorings with safety patterns. Use this skill when a dependency upgrade forces source changes, when migrating frameworks (React class→hooks, Flask→FastAPI), modernizing languages (Python 2→3), or performing large-scale refactories — even if they just say "migrate this" or "refactor the whole thing". Includes breaking change analysis, automated fix application, rollback strategies, and cross-file dependency tracking. Not for static-analysis, code-review-assistant, or routine patch/minor/CVE bumps (use dependency-upgrades). | code-quality |
| privacy-first | Prevent email addresses and personal data from entering the codebase. Use this skill when the user asks to prevent emails, remove personal data, run a privacy check, scan for PII, or ensure no email addresses leak into source code or documentation — even if they just say "no email" or "check for personal data". Not for security audits (use security-code-auditor), EU AI Act compliance (use eu-ai-act-compliance), or hardcoded secrets (use secrets-management). | security |
| progressive-delivery | Remediate a live production failure through a gated loop: reproduce the failure, generate a candidate fix, evaluate it, red-team it adversarially, then shadow, canary, and promote or roll back on SLO verdicts. Use when production is degraded and the fix must itself be proven safe, or when the user is already mid-rollout and needs shadow/canary/rollback decisions — even if they just say "roll this out safely", "canary this fix", or "prove the fix". Not for shipping changes through git/GitHub (use git-github-workflow), for running tests or diagnosing failures (use test-runner), for iterate-until-green validation loops (use iterative-refinement), or for authoring CI/CD pipeline config (use cicd-pipeline). | workflow |
| pwa-offline-sync | Design Cache Storage + IndexedDB strategy and sync queue. Use this skill when building service workers, implementing caching strategies, or investigating offline bugs — even if they just say "make it work offline" or "add caching". Generic pattern for any offline-first application. Not for lifecycle-management. | workflow |
| reader-ui-ux | Build localized, accessible reader/admin UI with responsive layouts, telemetry, and state management. Use this skill when building React screens, polishing UX, or implementing responsive layouts for reader or admin interfaces — even if they just say "fix the UI" or "make it responsive". Generic pattern for any document reader application. Not for document-rendering-and-locators. | workflow |
| readme-best-practices | Create, audit, and improve GitHub README.md files following 2026 best practices. Use this skill when a user asks to write, rewrite, or review a README.md for a GitHub repository, add shields.io badges, create a project SVG logo, improve documentation structure, or make a repository more discoverable and professional — even if they just say "write the README" or "make the repo look professional". Not for agents-md, architecture-diagram. | documentation |
| secrets-management | Own the secret lifecycle: detect leaked secrets, rotate them, and store them correctly. Use when handling API keys, tokens, or credentials — even if they just say "rotate this key", "where do I put this secret", or "this key is hardcoded". Not for privacy-first (email/PII lint), general vulnerability audits (use security-code-auditor), or commit/PR lifecycle mechanics (use git-github-workflow). | security |
| secure-invite-and-access | Implement access control, authentication, and authorization patterns. Use this skill when building auth endpoints, managing permissions, implementing session/token logic, or generating signed URLs — even if they just say "add auth" or "secure this endpoint". Generic template adaptable to any project's auth needs. Not for security-code-auditor, api-design-first. | workflow |
| security-code-auditor | Perform security audits on code to identify vulnerabilities, misconfigurations, and security anti-patterns. Use when users ask to 'audit', 'review', or 'check security' of code, configurations, or repositories — even if they just say "check for security issues" or "is this secure". Trigger on keywords like 'security review', 'vulnerability scan', 'OWASP', 'secure coding', 'penetration test', or 'security assessment'. Not for email/PII checks (use privacy-first), EU AI Act compliance (use eu-ai-act-compliance), hardcoded or leaked secrets (use secrets-management), or linter-based checks (use static-analysis). | security |
| shell-script-quality | Lint and test shell scripts using ShellCheck and BATS. Use this skill when checking bash/sh scripts for errors, writing shell script tests, fixing ShellCheck warnings, setting up CI/CD for shell scripts, or improving bash code quality — even if they just say "fix this script" or "add tests for the shell script". Not for static-analysis, cicd-pipeline. | code-quality |
| skill-creator | Create new skills, modify and improve existing skills, and measure skill performance. Use when users want to create a skill from scratch, edit, or optimize an existing skill, run evals to test a skill, benchmark skill performance with variance analysis, or optimize a skill's description for better triggering accuracy. Not for skill-evaluator, intent-classifier. | quality |
| skill-evaluator | Reusable skill for evaluating other skills with structure checks, eval coverage review, and real usage spot checks. Use when you need to check a skill, add evals, benchmark a skill, validate outputs against assertions, or compare current skill behavior against a baseline — even if they just say "evaluate this skill" or "check if this skill works".". Not for skill-creator. | quality |
| static-analysis | Triage and fix static analysis findings across any programming language. Use this skill when running linters (ruff, eslint, clippy, shellcheck), analyzing lint output, fixing warnings or errors, or managing cross-language static analysis results in a project — even if they just say "run the linter" or "fix the lint warnings". Trigger on "lint", "static analysis", "triage warnings", "fix findings". Not for code-review-assistant, security-code-auditor. | code-quality |
| test-runner | Execute tests, analyze results, and diagnose failures across any testing framework. Use this skill when running test suites, debugging failing tests, or configuring CI/CD testing pipelines — even if they just say "run the tests" or "why is this test failing". Not for debugger (build/deploy/runtime failures outside a suite), testing-strategy. | testing |
| testing-strategy | Design and implement comprehensive testing strategies for software projects. Use this skill when planning test suites, choosing testing approaches like property-based testing, visual regression, load testing, mutation testing, or E2E test generation — even if they just say "how should we test this" or "what testing approach should we use". Not for test-runner, testdata-builders. | testing |
| triz-solver | Systematic problem-solving using TRIZ (Theory of Inventive Problem Solving) principles adapted for software engineering. Use when facing technical contradictions, optimizing system design, running a TRIZ audit, finding contradictions in a design, or seeking innovative solutions beyond trial-and-error — even if they just say "help me solve this contradiction" or "run a TRIZ audit". Prevents solving the wrong problem correctly. Not for goap-agent, delegate. | innovation-problem-solving |
| turso-db | Use this skill for Turso (LibSQL/Limbo) database development, including scaffolding, querying, migrations, and maintenance. Supports vector search, full-text search, CDC, MVCC, encryption, and bidirectional remote sync. Use when working with Turso SDKs for JavaScript, Rust, Python, Go, Swift, and React Native — even if they just say "set up Turso", "query my Turso database", or "migrate to LibSQL". Provides current API guidance to avoid stale "libsql" legacy knowledge. Not for PostgreSQL, MySQL, or MongoDB (use database-devops) or general schema design without Turso. | database |
| ui-ux-optimize | Swarm-powered UI/UX prompt optimizer with auto-research agents, handoff coordination, confidence-scored autoresearch loops, and backpressure quality gates. Use this skill when optimizing UI/UX for web apps, mobile apps, games, dashboards, SaaS, e-commerce, kiosks, or any screen-based product — even if they just say "improve the UI" or "optimize the UX" or "this feels robotic". Writing-voice requests ("make it sound human") belong to avoid-ai-writing. Not for css-render-performance, avoid-ai-writing. | ui-ux |
| voice-profiles | Adapt writing tone and style based on target audience and content type using predefined voice and context profiles. | quality |
| web-search-researcher | Research topics using web search to find accurate, current information. Use this skill when you need modern information, official documentation, best practices, or technical solutions beyond training data — even if they just say "look this up" or "search for how to do X". Not for do-web-doc-resolver, agent-browser. | tool |

## Skill Categories

### agent

- agentic-abstention
- delegate
- implementer
- intent-classifier
- jules-delegator

### code-quality

- codacy
- code-review-assistant
- css-render-performance
- debugger
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

- dependency-upgrades
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
- voice-profiles

### security

- privacy-first
- secrets-management
- security-code-auditor

### testing

- test-runner
- testing-strategy

### tool

- agent-browser
- dist-channel-selection
- do-web-doc-resolver
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
- goap-agent
- progressive-delivery
- pwa-offline-sync
- reader-ui-ux
- secure-invite-and-access

## Usage

The `intent-classifier` skill uses this catalog for routing.
Regenerate after adding, renaming, or removing skills.
