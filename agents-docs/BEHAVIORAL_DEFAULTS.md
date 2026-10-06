# Behavioral Defaults

> Reference doc — not loaded by default. This repository uses the Full template
> maintainer profile. Downstream Minimal/Standard repositories default to Light;
> they do not automatically inherit Full maintenance obligations.

## Core Defaults

- **Automation-First**: Execute within the user's intent, approved plan, and assigned file scope; minimize confirmation loops.
- **Parallelism**: Use parallel tool calls for independent operations when supported by the runtime.
- **Direct Action**: Proceed when intent and context are clear. Implementing a change is not permission to commit, push, create/close issues or PRs, or merge. Those actions require user intent; do not change git configuration or rewrite history without authorization.
- **Diff-Oriented**: Report changes using concise, diff-focused summaries instead of long prose.
- **Voice & Context**: Adapt tone via `voice-profiles`. Default: `professional`+`blog`. Auto-detects context from cues (code, README, hashtags).
- **Verification Honesty**: Static lint, skill structure, eval schema, and fixture validation are not behavioral proof. Report what actually ran and what was skipped. A smoke runner that invokes no model cannot establish skill effectiveness.
- **Proportionate Planning**: Small fixes/docs need a short plan and relevant checks, not new ADRs or tests by default. Architectural changes need an approved decision record and decomposition; Full uses ADR/TRIZ/GOAP. Light teams can scale planning without enabling telemetry or template maintenance.

## Pre-Existing Issues by Profile

**Full maintainers:** fix inherited CI, lint, and quality-gate failures as well as
introduced regressions; do not silently leave template maintenance debt behind.
Respect explicit task boundaries: surface out-of-scope findings to the
coordinating agent rather than editing another owner's files. An unresolved
external blocker means the task is blocked, not that CI is green.

**Minimal/Standard Light:** fix introduced regressions and findings relevant to
the requested work. Report unrelated inherited failures with evidence; do not
expand a product task into an unrequested repository-wide remediation campaign.
Metrics/DORA and the Full always-fix loop are opt-in, not universal defaults.

## Pre-Existing Issue Workflow

Retrieve context → plan (`goap-agent` for complex remediation) → implement →
verify (`test-runner` / review). Independent issues may proceed in parallel;
verification of a fix depends on that fix. Keep changes atomic and publish only
when requested. Full playbook: `agents-docs/AGENTS_GUIDANCE.md`.

## Triage Protocol for Unfixable Issues

For Full work, if a failure cannot be fixed in the current run (external service,
upstream breakage, or missing credentials):

1. Create an ADR in `plans/` documenting the issue, root cause, and why it's out of scope.
2. Create a GOAP task in `plans/GOAP_STATE.md` with status `blocked` and the ADR link.
3. Run applicable local checks and report their result separately from remote CI. Do not claim a green branch while a required check is unresolved.
4. Never skip, suppress, or mark as `done` an issue that remains open.

Light adopters may record a blocker in the task summary or their own tracker;
they do not need template ADR/GOAP bookkeeping for every external failure.

## GitHub Triage Impact

When triage is requested, assess benefit to adopters and actual consumers:
correctness, security, setup reliability, instructions, generated catalogs, and
metadata used by agents, hooks, CI, or tooling all count. A metadata-only diff
is not automatically “no impact.” Identify readers and consequences before
disposition; keep consumed metadata updates open until resolved or genuinely
superseded. Close duplicates only with evidence of the canonical replacement
and user-authorized triage. Static checks alone do not establish absence of value.

Copied CI-status artifacts are advisory history, not product CI evidence. Check
the repository and run identity before treating them as a signal; never invent a
passing status to clear a blocker.

## Agentic Abstention

When environment-revealed infeasibility makes further tool calls wasteful,
agents MUST follow the stopping rules in:
`.agents/skills/agentic-abstention/SKILL.md`
