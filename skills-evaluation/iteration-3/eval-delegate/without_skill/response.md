# Rationalizations Check: Full Trace

## Where It's Checked

The Rationalizations section check lives in `scripts/validate-skills.sh`, **Check 4: Authoring compliance checks** (lines 127–213). Specifically, lines 164–169:

```bash
has_rationalizations=$(grep -c "^## Rationalizations" "$skill_file" || true)
if [[ "$has_rationalizations" -eq 0 ]]; then
    printf "  ${RED}✗${NC} %s: Missing '## Rationalizations' section\n" "$skill_name"
    skill_failed=1
fi
```

It uses `grep -c` to count lines matching the `^## Rationalizations` pattern. If the count is 0, it prints a red `✗` error and sets the per-skill `skill_failed` flag.

## Trace When a Skill Is Missing It

1. **`grep -c "^## Rationalizations" "$skill_file" || true`** — `grep -c` returns the count of matching lines. If no match, `grep` exits non-zero (no output), but `|| true` prevents `set -e` from killing the script (though `errexit` is already disabled via `set +e` at line 6). The result is `0`.

2. **`skill_failed=1`** — The per-skill failure flag is set.

3. **After the skill loop (line 197–199):**
   ```bash
   if [[ $skill_failed -ne 0 ]]; then
       AUTHORING_FAILED=1
   fi
   ```
   The global `AUTHORING_FAILED` flag is set to `1`.

4. **After all skills are processed (lines 202–213):**
   ```bash
   if [[ $AUTHORING_FAILED -ne 0 ]]; then
       echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
       echo -e "${YELLOW}│ ⚠ Skill authoring compliance issues found                   │${NC}"
       echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
       echo "New skills must have: category, ## Rationalizations, ## Red Flags,"
       echo "valid name field, and evals/evals.json with >= 3 eval cases."
       echo "See: .agents/skills/SKILL_TEMPLATE.md for the canonical structure."
       echo "See: CONTRIBUTING.md → Creating or Updating Skills for the workflow."
       WARNINGS=1
   fi
   ```
   A yellow `⚠` warning box is printed, and `WARNINGS=1` is set.

5. **Critical: `AUTHORING_FAILED` does NOT set `FAILED=1`.** The `FAILED` flag is only set by format checks (Check 1), circular symlinks (Check 2), broken symlinks (Check 3), and invalid skill-rules.json (Check 5). Authoring compliance issues (Check 4) only set `WARNINGS`, never `FAILED`.

6. **Exit code determination (lines 232–241):**
   ```bash
   if [[ $FAILED -ne 0 ]]; then
       echo "│ ✗ Skill Validation FAILED"
       exit 2
   fi
   ```
   Since `FAILED` remains `0`, the script prints the green success box and **exits with code 0** (success).

## Summary

| Stage | Variable | Value | Effect |
|-------|----------|-------|--------|
| grep finds no match | `has_rationalizations` | `0` | — |
| Match check fails | `skill_failed` | `1` | Per-skill error printed |
| After loop | `AUTHORING_FAILED` | `1` | Triggers warning box |
| Warning box | `WARNINGS` | `1` | Non-fatal |
| Final gate | `FAILED` | `0` | Script exits 0 (success) |

**Missing `## Rationalizations` is a WARNING, not a CI failure.** The script prints a yellow warning box listing what's needed, but exits with code 0. The pre-commit hook and CI will succeed — the skill passes validation despite the missing section. This is by design: authoring compliance is advisory (warnings), while format/symlink issues are hard failures (exit 2).
