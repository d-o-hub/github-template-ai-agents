# Pre-Existing Issues — GOAP + Swarm Workflow

When a failing check is **pre-existing** (i.e. it fails on the parent commit, not because of the current branch's changes), use the **GOAP + swarm** workflow. The `AGENTS.md` Behavioral Defaults section is the high-level rule; this file is the detailed playbook.

## Orchestrator

Load `.agents/skills/goap-agent/SKILL.md` — the default orchestrator for any multi-step remediation. Decompose the work into retriever / implementer / verifier tasks with explicit dependencies.

## Swarm Dispatch

Load `.agents/skills/agent-coordination/SKILL.md` and dispatch a **swarm of agents** in parallel:

| Role | Skill | Responsibility |
|------|-------|----------------|
| Retriever | `delegate` | Diagnose root cause; read logs; map dependencies; identify offending commit/PR. |
| Implementer | `implementer` | Apply the fix on the appropriate file(s) in a feature branch or directly on `main` per project policy. |
| Verifier | `static-analysis` + `test-runner` | Re-run the failing check; confirm green; capture before/after evidence. |

## Handoff Coordination

Each agent writes its handoff summary to `.agents/metrics.jsonl` (Post-Task Protocol) **and** to the orchestration log. The orchestrator consumes the handoffs, resolves cross-agent conflicts (e.g. shared file edits), and triggers the next agent.

## Commit Strategy

- One pre-existing issue per commit, even when multiple are fixed in one go.
- Use the **git-github-workflow** skill for the commit/PR/merge lifecycle.
- Reference the failing job/run URL in the commit body so future archeology is easy.

## CI Verification

After each commit, wait for the full CI run to complete. Do not move on until the previously-failing check is `success`. Re-iterate if a fix introduces a new failure.

## Don't Stop Until Green

A pre-existing issue is not "acknowledged" or "documented" — it is fixed. Filing a tracking issue is acceptable as a parallel action, but is never a substitute for the fix itself.

## Rationalizations to Reject

| Excuse | Why it's wrong |
|--------|----------------|
| "It was already broken before my changes." | Your CI is your responsibility until green. Regressions you inherit are still regressions you ship. |
| "Let me file an issue and move on." | Issues are not fixes. The user expects green CI, not green issues. |
| "It's the maintainer's problem." | You are the agent on duty. There is no "the maintainer" — there is you. |
| "I shouldn't modify that script — it's for downstream consumers." | True, but the pre-existing failure is in the workflow that *uses* the script, not the script itself. Fix the workflow. |
| "It's a permissions/secret issue I can't fix." | Then make the check pass without the secret (e.g. conditional `--upload`), or skip the check via a documented `--if` guard. Do not leave a red `X` on the dashboard. |
