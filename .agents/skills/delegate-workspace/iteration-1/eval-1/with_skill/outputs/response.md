# Delegate Skill: Find Rationalizations Check in validate-skills.sh

**Status**: success  
**Summary**: Found the Rationalizations section check in `validate-skills.sh` at lines 165-169, and traced the failure path.

## Where the Check Occurs

The script `scripts/validate-skills.sh` checks for the `## Rationalizations` heading in each skill's `SKILL.md` file during the authoring compliance checks (Check 4). The specific code is:

```bash
# Check: body must contain ## Rationalizations heading
has_rationalizations=$(grep -c "^## Rationalizations" "$skill_file" || true)
if [[ "$has_rationalizations" -eq 0 ]]; then
    printf "  ${RED}✗${NC} %s: Missing '## Rationalizations' section\n" "$skill_name"
    skill_failed=1
fi
```

Lines 164-169 in `/workspaces/github-template-ai-agents/scripts/validate-skills.sh`.

## What Happens When Missing

1. The script prints an error message with a red `✗` symbol:  
   `✗ <skill_name>: Missing '## Rationalizations' section`

2. The `skill_failed` variable is set to `1` for that skill.

3. After processing all skills, if any skill failed authoring checks, `AUTHORING_FAILED` is set to `1` (line 198).

4. If `AUTHORING_FAILED` is non-zero, the script:
   - Prints a yellow warning box (lines 202-213)
   - Outputs guidance: "New skills must have: category, ## Rationalizations, ## Red Flags, valid name field, and evals/evals.json with >= 3 eval cases."
   - Sets `WARNINGS=1`

5. However, note that the authoring compliance failure does **not** cause the script to exit with failure (exit code 2). Only `FAILED` (from symlink/format checks) triggers exit 2. The authoring compliance issues are treated as warnings, not hard failures.

## Additional Context

The script also checks for `## Red Flags` section (lines 172-176) and other authoring requirements (category field, name format, evals). All authoring checks use the same pattern: set `skill_failed=1` and eventually `AUTHORING_FAILED=1`, which triggers the warning box.

**Files touched**: /workspaces/github-template-ai-agents/scripts/validate-skills.sh  
**Findings worth promoting**: 
- The validate-skills.sh script uses `grep -c` with a pattern anchored to line start (`^## Rationalizations`) to detect the section.
- Authoring compliance failures (missing Rationalizations/Red Flags) are warnings, not CI failures; only symlink/format issues cause exit code 2.
- The script's warning box provides actionable guidance and references to skill templates.