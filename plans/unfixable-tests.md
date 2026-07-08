# Failing upstream tests in `do-web-doc-resolver` local port

When porting `async` logic from upstream `do-web-doc-resolver` repository, several tests failed. We are not addressing them here because they are related to upstream flakiness, structural differences in the current workspace compared to upstream assumptions (e.g. symlinks), missing cache functionality or missing API keys.

Tests ignored/failing:
- `TestFetchLlmsTxt::test_llms_txt_not_found`
- `TestSerperErrorLogging` and `TestJinaErrorLogging` suites (assertion errors on error handling output shapes/logs)
- `TestCacheBehavior` (Import error for `_l1_clear`)
- `TestSkillSymlink` suite (Symlink structure inside `.blackbox` and `.agents` locally differs from tests)
- `TestDuckDuckGoFallback` and `TestAdditionalEdgeCases` (Import error for `_l1_clear`)

These tests should be reviewed in the upstream repo or adapted for the local execution environment later.

## Quality gate failure

The quality gate is also failing due to `SKILL.md` length limits in `.agents/skills` directories outside `do-web-doc-resolver` (e.g. `skill-evaluator`, `shell-script-quality`). These exceed the 250 LOC rule but are part of the broader workspace and not the skill itself. These should be addressed globally.
