# Code Quality Issues - Main Branch

## CI Status
- **Status**: Passing (last run: 2026-06-18T15:45:10Z)
- **Workflow URL**: https://github.com/d-o-hub/github-template-ai-agents/actions/runs/27771228314

## Quality Gate Results

### ❌ Failed Checks

1. **LLM Context Files Out of Date**
   - `llms-full.txt` is out of date
   - **Fix**: Run `./scripts/generate-llms-txt.sh`

2. **Skills Reference Drift**
   - `agents-docs/skills-reference.md` is out of date
   - Multiple skill descriptions have been updated but the reference file hasn't been regenerated
   - **Fix**: Run `./scripts/generate-skills-reference.sh`

3. **Invalid Reference Format in SKILL.md Files** (5 errors)
   - `.agents/skills/task-decomposition/SKILL.md` line 182: Invalid Markdown link format
   - `.agents/skills/triz-solver/SKILL.md` lines 177-179: Invalid Markdown link format (3 occurrences)
   - `.agents/skills/web-search-researcher/SKILL.md` line 239: Invalid Markdown link format
   - **Fix**: Change `[text](references/guide.md)` to `` `references/guide.md` - Description ``

### ✅ Passed Checks

- Git hooks configuration: Valid
- GitHub Actions SHAs: All valid and pinned
- Gemini TOML commands: 8 files valid
- GitHub Actions Workflows: All valid
- Skills validation: All 58 skills valid
- Skill authoring compliance: Passed
- SKILL.md reference links: 0 broken links, but 5 format errors
- ADR compliance: All checks passed
- Metrics.jsonl validation: Valid
- Commitlint configuration: Syntax OK, consistent with AGENTS.md
- LOC limits: Passed
- WASM size limits: Passed (no WASM files found)
- Shell script checks: shellcheck passed (severity=error)
- Markdown checks: Not run (markdownlint-cli2 not installed locally)

## Recommendations

1. **High Priority**: Fix the 5 invalid reference formats in SKILL.md files
2. **Medium Priority**: Regenerate `llms-full.txt` and `skills-reference.md`
3. **Low Priority**: Install `markdownlint-cli2` for local markdown validation

## Technical Details

### Languages Detected
- Shell scripts
- Markdown files

### Tools Used
- ShellCheck (severity=error)
- Quality Gate script (full suite)
- GitHub Actions CI status check
