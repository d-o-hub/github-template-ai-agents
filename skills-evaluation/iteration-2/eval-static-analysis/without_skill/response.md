## Triage SC2086 (Double quote to prevent globbing and word splitting)

**What it means**: An unquoted variable expansion (e.g., `$VAR`) can split on whitespace or expand as a glob. Quote it: `"$VAR"`.

**Quick triage steps:**

1. **Identify all occurrences:**
   ```bash
   shellcheck -s bash -f gcc scripts/deploy.sh | grep SC2086
   ```
   This gives you file:line references.

2. **Categorize by severity:**
   - **Variables in arguments/commands** — most instances, almost always need quotes: `"$1"`, `"$DIR"`, `"$VERSION"`
   - **Variables in `cd`, `rm`, `cp` paths** — dangerous if path contains spaces, always quote
   - **Variables already inside double-quoted strings** — no change needed
   - **Loop variables** — if the value is known-safe (e.g., numeric only), you may intentionally skip, but quote by default

3. **Fix pattern — wrap in double quotes:**
   ```bash
   # Bad
   rm -rf $BUILD_DIR
   cp $SRC_FILE $DEST

   # Good
   rm -rf "$BUILD_DIR"
   cp "$SRC_FILE" "$DEST"
   ```

4. **Exception cases where quoting is intentionally skipped:**
   - Word-splitting is desired (rare, intentional): `xargs <<< $UNQUOTED_LIST` — add `# shellcheck disable=SC2086` with a comment explaining why.
   - Array expansion that must remain unquoted: `${arr[@]}` (without quotes) only when word splitting is intended, otherwise quote it.

5. **Verify the fix:**
   ```bash
   shellcheck -s bash -e '' scripts/deploy.sh
   ```
   Confirm no remaining SC2086 warnings.

**Key principle:** When in doubt, double-quote it. Unquoted variables are the most common shell injection / path breakage vector.
