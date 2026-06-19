## Where `validate-skills.sh` checks for Rationalizations

The check lives in **"Check 4: Authoring compliance checks"** at `scripts/validate-skills.sh:164-168`:

```bash
has_rationalizations=$(grep -c "^## Rationalizations" "$skill_file" || true)
if [[ "$has_rationalizations" -eq 0 ]]; then
    printf "  ${RED}✗${NC} %s: Missing '## Rationalizations' section\n" "$skill_name"
    skill_failed=1
fi
```

It uses `grep -c` to count lines matching `^## Rationalizations` (must be a top-level `##` heading). If the count is 0, it prints a red error marker and sets `skill_failed=1`.

Note: The `|| true` prevents `grep` from returning non-zero when no matches are found (which would trigger `set -e` in some contexts, though this script uses `set +e`).

## What happens when a skill is missing it

The failure cascades as follows — and it is **only a warning, not a hard failure**:

1. **`skill_failed=1`** is set (line 168)
2. At the end of the compliance loop (line 197-199): `skill_failed` non-zero → sets **`AUTHORING_FAILED=1`**
3. After the loop (lines 202-213): `AUTHORING_FAILED` non-zero → prints a **yellow warning box** listing required sections (Rationalizations, Red Flags, category, evals) and sets **`WARNINGS=1`** — critically, it does **NOT** set `FAILED=1`
4. At script exit (line 232): only `$FAILED` triggers `exit 2`. Since only `$WARNINGS` was set, the script **exits 0** (success)
5. `quality_gate.sh:161`: `if ! ./scripts/validate-skills.sh; then FAILED=1` — since exit code is 0, this branch is not taken, so the quality gate **also passes**

**Result**: A missing `## Rationalizations` section produces a visible yellow warning during validation but does **not** block commits, CI, or the quality gate.

## The `validate_skill_file` library function does NOT check Rationalizations

The library function at `scripts/lib/skill-validation.sh:33-141` (sourced on line 12) only validates frontmatter fields: `name`, `description`, `version`, `template_version`, line count, and first-line `---`. It has no awareness of body content sections like Rationalizations. The Rationalizations/Red Flags checks are performed exclusively in the main loop of `validate-skills.sh` (Check 4, lines 131-200).

## Summary of the distinction

| Check | Variable set | Effect |
|-------|-------------|--------|
| Missing `## Rationalizations` | `WARNINGS=1` | Warning only, exit 0 |
| Missing `## Red Flags` | `WARNINGS=1` | Warning only, exit 0 |
| Missing frontmatter `category` | `AUTHORING_FAILED=1` → `WARNINGS=1` | Warning only, exit 0 |
| Missing `name:` in frontmatter | `FAILED=1` (via `validate_skill_file`) | Hard failure, exit 2 |
| Missing `---` on line 1 | `FAILED=1` (via `validate_skill_file`) | Hard failure, exit 2 |
| Missing `evals/evals.json` | `AUTHORING_FAILED=1` → `WARNINGS=1` | Warning only, exit 0 |

The authoring compliance checks (Check 4) are intentionally softer than the format/symlink checks (Checks 1-3), which set `FAILED` and cause hard failures.
