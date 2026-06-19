# Skills Directory Assessment

## Summary

- **Total skills in `.agents/skills/`**: 58
- **Total skills in `.claude/skills/`**: 0
- **Skills with evals (`evals.json`)**: 58 (100%)

## Skills with Evals (58)

All 58 skills in `.agents/skills/` have corresponding `evals.json` files:

| # | Skill Name | Has evals.json |
|---|------------|----------------|
| 1 | accessibility-auditor | Yes |
| 2 | agent-browser | Yes |
| 3 | agent-coordination | Yes |
| 4 | agents-md | Yes |
| 5 | anti-ai-slop | Yes |
| 6 | api-design-first | Yes |
| 7 | architecture-diagram | Yes |
| 8 | cicd-pipeline | Yes |
| 9 | cloudflare-worker-api | Yes |
| 10 | codacy | Yes |
| 11 | codacy-cloud-cli | Yes |
| 12 | code-review-assistant | Yes |
| 13 | codeberg-api | Yes |
| 14 | css-render-performance | Yes |
| 15 | database-devops | Yes |
| 16 | delegate | Yes |
| 17 | dist-channel-selection | Yes |
| 18 | do-web-doc-resolver | Yes |
| 19 | docs-hook | Yes |
| 20 | document-rendering-and-locators | Yes |
| 21 | dogfood | Yes |
| 22 | dora-report | Yes |
| 23 | durable-objects | Yes |
| 24 | eu-ai-act-compliance | Yes |
| 25 | git-github-workflow | Yes |
| 26 | github-pr-sentinel | Yes |
| 27 | goap-agent | Yes |
| 28 | implementer | Yes |
| 29 | intent-classifier | Yes |
| 30 | iterative-refinement | Yes |
| 31 | jules-delegator | Yes |
| 32 | learn | Yes |
| 33 | lifecycle-management | Yes |
| 34 | memory-context | Yes |
| 35 | migration-refactoring | Yes |
| 36 | parallel-execution | Yes |
| 37 | privacy-first | Yes |
| 38 | pwa-offline-sync | Yes |
| 39 | reader-ui-ux | Yes |
| 40 | readme-best-practices | Yes |
| 41 | secure-invite-and-access | Yes |
| 42 | security-code-auditor | Yes |
| 43 | self-fix-loop | Yes |
| 44 | shell-script-quality | Yes |
| 45 | skill-creator | Yes |
| 46 | skill-evaluator | Yes |
| 47 | static-analysis | Yes |
| 48 | task-decomposition | Yes |
| 49 | template-version-management | Yes |
| 50 | test-runner | Yes |
| 51 | testdata-builders | Yes |
| 52 | testing-strategy | Yes |
| 53 | triz-analysis | Yes |
| 54 | triz-solver | Yes |
| 55 | turso-db | Yes |
| 56 | ui-ux-optimize | Yes |
| 57 | verification-template | Yes |
| 58 | web-search-researcher | Yes |

## Notes

- The `.claude/skills/` directory exists but contains no `SKILL.md` files (all canonical skills are in `.agents/skills/`).
- Some skills have additional eval artifacts beyond `evals.json`:
  - `git-github-workflow`: README.md, README_ATOMIC_COMMIT.md, README_GITHUB_WORKFLOW.md
  - `skill-creator`: bad-references-input.md
  - `ui-ux-optimize`: golden-tokens.json, eval-prompt.md
- Coverage is 100% — every skill has evals.
