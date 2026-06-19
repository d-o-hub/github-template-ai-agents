**Status**: success
**Summary**: Provided triage guidance for SC2086 errors in deploy.sh following static-analysis skill.

**Deliverable**:

To triage SC2086 errors in `scripts/deploy.sh`:

1. **Run shellcheck locally**: `shellcheck scripts/deploy.sh` to see exact lines. Use `--severity=error` to check if they are treated as errors in CI.
2. **Classify severity**: SC2086 is a warning ("Double quote to prevent globbing and word splitting"). Determine if CI blocks on warnings (check quality_gate.sh uses `--severity=error`; if your CI runs shellcheck without severity flag, warnings will fail).
3. **Auto-fix safe findings**: Add double quotes around variable expansions (`"$var"`). This is safe and recommended.
4. **Suppress if intentional**: If word splitting is intentional, add a suppression comment in the required format:
   ```bash
   # [tool-disable] SC2086: Intentional word splitting for multiple arguments -- <agent-id> (<date>)
   ```
   Document the reason.
5. **Verify**: Run `./scripts/quality_gate.sh` locally to ensure the fix passes.

**Files touched**: (none)
**Findings worth promoting**:
- The project uses `--severity=error` in CI, so only errors block; warnings are non-blocking.
- Existing suppression format in repo is `# shellcheck disable=SCXXXX`, but skill mandates `[tool-disable]` format for auditability.