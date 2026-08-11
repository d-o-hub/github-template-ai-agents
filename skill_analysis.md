
---
**Skill to update:** `.agents/skills/static-analysis/`
**Upstream source:** `skills/codacy-analysis-cli/`
**Gap summary:** The upstream `codacy-analysis-cli` has comprehensive details about initialization (discovering repository stack), inspecting tool availability via `--inspect`, and specific git-aware analysis flags (`--staged`, `--diff`, `--pr`) with their precise scoping. The `static-analysis` skill has only brief mentions of these capabilities under its Codacy Git-Aware Analysis section and is missing the initialization and discovery phases completely.
**Specific additions:**
- [ ] Add: `codacy-analysis discover` command and explanation for auto-detecting the repository stack before initialization.
- [ ] Add: The "Inspect tool availability (dry-run)" section utilizing `codacy-analysis analyze --inspect --output-format json` and the `jq` parsing commands to identify missing dependencies.
- [ ] Add: The detailed "Install missing dependencies" step using `codacy-analysis analyze --install-dependencies`.
- [ ] Add: Explicit commands and definitions for advanced flags like `--parallel-tools`, `--tool-timeout`, `--fail-if-missing`, and `--config-file`.

---
**Skill to update:** `.agents/skills/codacy/`
**Upstream source:** `skills/codacy-cloud-cli/`
**Gap summary:** The upstream `codacy-cloud-cli` includes full sections for querying findings, tools, patterns, and managing local configuration imports (`--import`). Our `codacy` skill lacks detailed sub-commands for security findings and patterns/tools manipulation.
**Specific additions:**
- [ ] Add: The "Security findings" section including `codacy findings` and `codacy finding` with filter flags (`--severities`, `--statuses`, etc.).
- [ ] Add: The "Tools & patterns" section detailing `codacy tools`, `codacy patterns`, `codacy pattern`, and parameters (`--enable`, `--disable`, `--parameter`).
- [ ] Add: The "Importing configuration" section detailing the `codacy tools --import` command, `--force`, and how it handles cloud-only tools and config-file modes.
- [ ] Add: Handling of `Affected functions` (Vulnerable Functions block) for SCA issues/findings and reachability checks.

---
**Skill to update:** `.agents/skills/code-review-assistant/`
**Upstream source:** `skills/codacy-code-review/`
**Gap summary:** The upstream `codacy-code-review` enforces a strict 8-step review workflow integrating both local (`codacy-analysis analyze --pr`) and remote (`codacy pull-request`) results. `code-review-assistant` only has a truncated 4-command snippet for "Codacy PR Review Integration".
**Specific additions:**
- [ ] Adopt: The "Review workflow" 8-step checklist (Gather PR context, Run local analysis, Fetch Cloud PR data, Check introduced issues, Check coverage, Verify alignment, Propose test plan, Summarize).
- [ ] Add: Specific commands for ignoring false positive issues (`--ignore-issue`, `--ignore-all-false-positives`, `--unignore-issue`) during review.
- [ ] Add: Guidance on triggering remote reanalysis and blocking using `codacy pull-request ... --reanalyze-and-wait`.

---
**Skill to update:** `.agents/skills/codacy/`
**Upstream source:** `skills/configure-codacy-cloud/`
**Gap summary:** The upstream `configure-codacy-cloud` provides robust noise-evaluation guidance and per-tool tuning tips (Semgrep, Lizard, ESLint9, markdownlint) to reduce false positives. This methodology is entirely missing from the `codacy` skill.
**Specific additions:**
- [ ] Add: The "Noise-evaluation guidance" section (e.g., "Security patterns get extra caution", "Prefer parameter tuning over disabling").
- [ ] Add: The "Per-tool tuning tips" section for optimizing Semgrep (disable unused languages), Lizard (raise complexity thresholds), ESLint9 (local config), and markdownlint (exclude noisy files).
- [ ] Adopt: Handling and reporting of `EnforcedByCodingStandard` and `ConfigurationFile` conflicts.

---
**Skill to update:** `.agents/skills/codacy/`
**Upstream source:** `skills/configure-codacy/`
**Gap summary:** The upstream `configure-codacy` contains a "Security guardrail" strictly mandating that every security concern must be covered by at least one active pattern. The `codacy` skill does not include this critical safety constraint.
**Specific additions:**
- [ ] Add: The "Security guardrail" section explicitly stating that "Every security concern must be covered by at least one active pattern" and explaining how to handle noisy security patterns (prefer file exclusion over disabling).
- [ ] Add: The cloud verification workflow (`codacy repository --reanalyze-and-wait` and comparing overviews).
- [ ] Adopt: The workflow structure for local initialization, testing configurations, and applying changes.

---
**Skill to update:** `.agents/skills/cicd-pipeline/`
**Upstream source:** `skills/setup-coverage/`
**Gap summary:** Upstream `setup-coverage` provides an extensive matrix of CI platforms and languages, detailing how to generate coverage for 10+ environments (Jest, Vitest, JaCoCo, Go, SimpleCov, Coverlet, etc.). `cicd-pipeline` only covers Jest, Pytest, Go, and JaCoCo, and misses the troubleshooting context.
**Specific additions:**
- [ ] Add: Language-specific coverage generation snippets for Vitest, Kotlin, Android, Ruby (SimpleCov), C#/.NET (Coverlet), Scala (sbt-jacoco), PHP (PHPUnit), and Swift/Obj-C from Step 4.
- [ ] Add: The "Detect testing setup" heuristics for identifying test frameworks by language.
- [ ] Add: The "Troubleshooting" section addressing common upload issues like "Commit Not Found", "Pending", and path mismatches.

**`SKILL_TEMPLATE.md` / `skill-rules.json` updates (if any):**
- Adopt: Upstream uses `version` metadata inside the frontmatter (e.g., `version: 1.4.0`) rather than at the top level for some skills. Update the template instructions/rules to standardize the location or formatting of `version` in frontmatter.
