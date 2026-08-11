
---
**Skill to update:** `.agents/skills/static-analysis/`
**Upstream source:** `skills/codacy-analysis-cli/`
**Gap summary:** The upstream `codacy-analysis-cli` has comprehensive details about initialization, discovering tools, inspecting availability, and git-aware scoping, which are only briefly mentioned or missing in `static-analysis`.
**Specific additions:**
- [ ] Add: `codacy-analysis discover --output-format json` command for discovering the repository stack.
- [ ] Add: `codacy-analysis analyze --inspect --output-format json` command for inspecting tool availability.
- [ ] Add: Details on installing missing dependencies using `codacy-analysis analyze --install-dependencies`.
- [ ] Add: Advanced analysis flags including `--parallel-tools`, `--tool-timeout`, `--fail-if-missing`, and `--config-file`.

---
**Skill to update:** `.agents/skills/codacy/`
**Upstream source:** `skills/codacy-cloud-cli/`
**Gap summary:** The upstream `codacy-cloud-cli` includes detailed commands for managing tools, patterns, and importing configurations that are absent in our `codacy` skill.
**Specific additions:**
- [ ] Add: Commands for listing and managing tools (`codacy tools`, `codacy tool`).
- [ ] Add: Commands for listing and managing patterns (`codacy patterns`, `codacy pattern`), including the use of `--search`.
- [ ] Add: The `--import` workflow for syncing local configuration to Codacy Cloud (`codacy tools --import`).
- [ ] Add: Clarification on `Affected functions` for SCA issues and how they appear in the CLI.

---
**Skill to update:** `.agents/skills/code-review-assistant/`
**Upstream source:** `skills/codacy-code-review/`
**Gap summary:** Upstream provides a highly structured 8-step review workflow integrating local and cloud data, whereas `code-review-assistant` only has a brief "Codacy PR Review Integration" section.
**Specific additions:**
- [ ] Adopt: The 8-step "Review workflow" structure (Gather PR context, Run local analysis, Fetch Cloud PR data, Check introduced issues, Check coverage, Verify alignment, Propose test plan, Summary).
- [ ] Add: Commands for ignoring issues (`--ignore-issue`, `--ignore-all-false-positives`, `--unignore-issue`).
- [ ] Add: `codacy pull-request <provider> <org> <repo> <prNumber> --reanalyze-and-wait` command for stale or missing remote analysis.

---
**Skill to update:** `.agents/skills/codacy/`
**Upstream source:** `skills/configure-codacy-cloud/`
**Gap summary:** The upstream skill `configure-codacy-cloud` provides a detailed methodology for evaluating noise and reducing false positives, which is missing in our `codacy` skill.
**Specific additions:**
- [ ] Add: The "Noise-evaluation guidance" section (e.g., "Security patterns get extra caution", "Prefer parameter tuning over disabling").
- [ ] Add: The "Per-tool tuning tips" section for tools like Semgrep, Lizard, ESLint9, and markdownlint.
- [ ] Adopt: The concept of checking for Coding Standard conflicts (`EnforcedByCodingStandard`).

---
**Skill to update:** `.agents/skills/codacy/`
**Upstream source:** `skills/configure-codacy/`
**Gap summary:** Upstream `configure-codacy` contains a detailed 7-step process for configuring Codacy locally and verifying changes in the cloud, including the "Security guardrail".
**Specific additions:**
- [ ] Add: The "Security guardrail" section ("Every security concern must be covered by at least one active pattern").
- [ ] Add: The cloud verification workflow (`codacy repository --reanalyze-and-wait` and comparing overviews).
- [ ] Adopt: The workflow structure for local initialization, testing configurations, and applying changes.

---
**Skill to update:** `.agents/skills/cicd-pipeline/`
**Upstream source:** `skills/setup-coverage/`
**Gap summary:** The upstream `setup-coverage` skill includes a comprehensive list of test framework detection heuristics and language-specific setup instructions for generating coverage, which `cicd-pipeline` lacks.
**Specific additions:**
- [ ] Add: Language-specific coverage setup for JavaScript (Vitest), Kotlin, Android, Ruby, C#/.NET, Scala, PHP, and Swift/Obj-C.
- [ ] Add: The "Troubleshooting" section for common coverage upload issues.
- [ ] Add: The "Detect testing setup" heuristics (Step 1).

**`SKILL_TEMPLATE.md` / `skill-rules.json` updates (if any):**
- Adopt: Upstream uses `version: "x.y.z"` inside the `metadata` block (e.g., `version: 1.4.0`) rather than at the top level in some skills. We should standardize the location of `version` in the template if necessary (though our template currently has it at the top level, we might want to note this).
