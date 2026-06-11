# Step 5: Interpret results

The JSON output contains the full `AnalysisResult`. See [references/output-format.md](references/output-format.md) for the complete schema.

**Quick reference for parsing:**

```bash

# Count issues by severity

codacy-analysis analyze --output-format json | jq '.issues | group_by(.severity) | map({severity: .[0].severity, count: length})'

# Get critical/high issues only

codacy-analysis analyze --output-format json | jq '[.issues[] | select(.severity == "Error" or .severity == "High")]'

# Issues grouped by file

codacy-analysis analyze --output-format json | jq '.issues | group_by(.filePath) | map({file: .[0].filePath, count: length})'

# Check for tool errors

codacy-analysis analyze --output-format json | jq '.errors'

# Per-tool summary

codacy-analysis analyze --output-format json | jq '.toolResults | map({toolId, status, issueCount, durationMs})'

```

**Exit codes:**
- `0` — Success, no issues found
- `1` — Issues found
- `2` — Execution error (tool crash, missing dependency, etc.)
