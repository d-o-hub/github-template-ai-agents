# Pre-existing Issues

These issues existed on the main branch before the PR resolution and were not addressed in this session. They are documented for follow-up.

## Quality Gate Warnings

The quality gate reports 31 skills missing the optional `version:` field in their SKILL.md frontmatter. This is a pre-existing convention issue affecting the following skills:

accessibility-auditor, agent-coordination, agents-md, anti-ai-slop, architecture-diagram, atomic-commit, cicd-pipeline, code-quality, code-review-assistant, codeberg-api, database-devops, do-web-doc-resolver, docs-hook, git-github-workflow, github-readme, github-workflow, goap-agent, intent-classifier, iterative-refinement, learn, migration-refactoring, parallel-execution, privacy-first, skill-creator, skill-evaluator, task-decomposition, testing-strategy, triz-analysis, triz-solver, ui-ux-optimize, web-search-researcher

**Recommendation:** Add `version:` field to all SKILL.md frontmatters in a separate PR.

## Copied PR Changes

These are the original PR changes that were pushed to their respective branches.

## PR #368 - validate-links.sh Robustness

The Codacy review expressed concern that `scripts/validate-links.sh` may hang on empty input. Investigation deferred.
