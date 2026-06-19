# Delegate Skill Evaluation: Rationalizations Check Trace

## Where the Check Lives

The Rationalizations check is in `scripts/validate-skills.sh`, lines 164–169, inside the **Check 4: Authoring compliance checks** loop (lines 127–200):

```bash
# Check: body must contain ## Rationalizations heading
has_rationalizations=$(grep -c "^## Rationalizations" "$skill_file" || true)
if [[ "$has_rationalizations" -eq 0 ]]; then
    printf "  ${RED}✗${NC} %s: Missing '## Rationalizations' section\n" "$skill_name"
    skill_failed=1
fi
```

It greps for lines starting with `## Rationalizations` in each skill's `SKILL.md`. A count of 0 triggers the error.

## What Happens When a Skill Is Missing It

1. **`skill_failed=1`** is set (line 168) — same flag used by missing `category`, missing `## Red Flags`, missing `evals.json`, and invalid `name` field.

2. **After the loop**, if any skill set `skill_failed`, then `AUTHORING_FAILED=1` (line 198).

3. **If `AUTHORING_FAILED` is set** (lines 202–213), the script prints a yellow warning banner:
   ```
   ─────────────────────────────────────────────────────────────
   │ ⚠ Skill authoring compliance issues found                   │
   ─────────────────────────────────────────────────────────────
   ```
   Then prints guidance pointing to `SKILL_TEMPLATE.md` and `CONTRIBUTING.md`.

4. **Critically**: `AUTHORING_FAILED` sets `WARNINGS=1` (line 212), **not** `FAILED=1`. The `FAILED` flag is only set by structural checks (missing SKILL.md, circular symlinks, broken CLI symlinks — lines 62, 72, 104, 109).

5. **Exit code**: The script only exits with code 2 (failure) if `FAILED` is non-zero (lines 232–241). Since missing Rationalizations only sets `WARNINGS`, **the script exits 0**.

## Summary

Missing `## Rationalizations` is a **soft failure** (warning), not a hard CI blocker. It:
- Prints a red `✗` error line per skill
- Triggers the yellow authoring compliance banner at the end
- Sets `WARNINGS=1` but **not** `FAILED=1`
- Does **not** cause the script to exit non-zero

The rationale: structural validity (SKILL.md exists, symlinks work) blocks CI; authoring quality (Rationalizations, Red Flags, evals) is advisory — it warns but doesn't fail the build.

## Files Touched
- `scripts/validate-skills.sh` (lines 164–169: the check; lines 197–213: the consequence)
- `scripts/lib/skill-validation.sh` (sourced but does NOT check Rationalizations — it only validates frontmatter format)

## Findings Worth Promoting
- The `validate_skill_file()` function in `lib/skill-validation.sh` does **not** check Rationalizations/Red Flags — those are authoring-level checks only in the main script
- `AUTHORING_FAILED` vs `FAILED` is the key distinction: authoring issues are warnings, structural issues are hard failures
