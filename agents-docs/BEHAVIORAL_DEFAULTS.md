# Behavioral Defaults

> Reference doc — not loaded by default. These rules apply to all agents working
> in this repository. Moved here from AGENTS.md to reduce token budget.

## Core Defaults

- **Automation-First**: Execute tasks autonomously within approved plans; minimize confirmation loops.
- **Parallelism**: Use parallel tool calls for independent operations when supported by the runtime.
- **Direct Action**: Proceed with actions immediately when intent and context are clear.
- **Diff-Oriented**: Report changes using concise, diff-focused summaries instead of long prose.
- **Voice & Context**: Adapt tone via `voice-profiles`. Default: `professional`+`blog`. Auto-detects context from cues (code, README, hashtags).
- **Always-Fix Pre-Existing Issues**: No discussion. No deferral. If a CI check, lint warning, or quality-gate finding is failing on `main` (regardless of who introduced it), agents MUST fix it as part of the current task. The only acceptable exit is a green CI for the current commit's run, with no new regressions and no inherited failures.

## Pre-Existing Issue Workflow

Load `.agents/skills/goap-agent/SKILL.md` (orchestrator) and `.agents/skills/agent-coordination/SKILL.md` (swarm dispatch). Retriever / Implementer / Verifier in parallel, atomic commits per issue, verify green before moving on. Full playbook: `agents-docs/AGENTS_GUIDANCE.md`.

## Triage Protocol for Unfixable Issues

If a pre-existing failure cannot be fixed in the current run (e.g., external CI service stale, upstream dependency broken, requires human credential):

1. Create an ADR in `plans/` documenting the issue, root cause, and why it's out of scope.
2. Create a GOAP task in `plans/GOAP_STATE.md` with status `blocked` and the ADR link.
3. Ensure the current commit's quality gate passes — the branch must be green even if inherited issues remain.
4. Never skip, suppress, or mark as `done` an issue that remains open.

## Agentic Abstention

When environment-revealed infeasibility makes further tool calls wasteful,
agents MUST follow the stopping rules in:
`.agents/skills/agentic-abstention/SKILL.md`
