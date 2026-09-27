# ADR-038: Skill Consolidation Execution (Dogfood Audit Verdicts)

Status: Accepted (build mode, 2026-09-27)
Date: 2026-09-27

## Context

Round 6 dogfood swarm audited all 56 skills (overlap, registry, scripts,
triggers). Static hygiene is good (versions, Rationalizations/Red Flags,
validate-skills PASS). Findings: verbatim duplications, trigger collisions,
stale generators/parsers (fixed in #916), and 9 narrow/vendor skills inflating
the default surface.

## Decision

1. **Merge (fold + delete dir):** `triz-analysis`→`triz-solver` (audit mode
   section); `github-pr-sentinel`→`git-github-workflow` (`--watch` mode,
   watcher script preserved); `agent-coordination`→`goap-agent/references/`
   (execution patterns); `testdata-builders`→`testing-strategy` appendix;
   `verification-template`→`skill-evaluator` references checklist;
   `template-version-management`→`agents-docs/` contributor doc;
   `docs-hook`→`git-github-workflow` hook phase.
2. **Demote to `SKILLS_OPTIONAL`** (dir stays, default symlinks skipped):
   `reader-ui-ux`, `document-rendering-and-locators`, `pwa-offline-sync`,
   `cloudflare-worker-api`, `codacy`, `lifecycle-management`.
3. **KEEP (deviations with rationale):** `jules-delegator` (repo ships via
   Jules; own workflow depends on it), `turso-db` (dedicated
   `sync-turso-skill.yml` automation), `do-web-doc-resolver` (hardcoded in
   `.opencode/commands/swarm-web-research` + `git-github-workflow/run.sh`;
   disambiguate description vs `web-search-researcher` instead).
4. **Safe edits:** `skill-creator` defers eval execution to `skill-evaluator`;
   `avoid-ai-writing` drops duplicated voice table (reference instead);
   trigger specificity (`ui-ux-optimize`, `triz-solver`, `dora-report`
   Not-for lines); `SKILL_TEMPLATE.md` gains Not-for + evals-scaffold +
   category/version fields; trigger-uniqueness registry step in
   `skill-creator`; `.opencode` phantom refs + `update-docs.md` stale refs.
5. Each group ships as its own PR (revertable); generators re-run;
   `skill-rules.json` updated where entries reference moved skills;
   `validate-skills.sh` + `quality_gate.sh` + full CI per PR.

## Consequences

- Positive: smaller default surface, no verbatim dups, routable triggers,
  template stays generic.
- Negative: adopters referencing removed skill names must re-link
  (CHANGELOG note in PR bodies); `git-github-workflow/SKILL.md` needs
  distillation to stay ≤250 lines.
- Risks: cross-ref drift — mitigated by generators + `git grep` checks per PR.
