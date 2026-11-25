# scripts/ AGENTS.md

> Scoped guidance for agents working in this directory.
> Nearest AGENTS.md takes precedence over root.

## Protected Scripts

Do NOT modify without explicit user instruction:
- `quality_gate.sh` - Core quality gate
- `pre-commit-hook.sh` - Git hook template
- `setup-skills.sh` - Skill symlink creation

## Naming Convention

Scripts use `snake_case.sh`. New scripts must follow this convention.

## REPO_ROOT Detection

Every script must detect repo root portably:

```bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
```

Never hardcode paths.

## Non-Obvious Lessons

- `validate-skills.sh` must use `set +e` explicitly to allow full error report (LESSON-011)
- Avoid generic Bash variables like `temp_table` in global scope; use script-specific prefixes (LESSON-012)
- CI hangs can be caused by BATS recursion if a script under test calls BATS itself (LESSON-013)
- Use `--severity=error` in Shellcheck CI to prevent style warnings from blocking functional PRs (LESSON-014)
- GitHub API 403 errors in CI usually mean the workflow needs explicit `permissions: issues: write` (LESSON-015)
- Linting results for `shellcheck` and `markdownlint` are cached in `.git/lint-cache/` to speed up subsequent runs. The cache is per-file and aware of configuration changes.
- The 250-line SKILL.md limit in `lib/skill-validation.sh` (`MAX_SKILL_LINES=250`) is a WARNING, not a CI failure — it uses yellow ⚠ prefix without incrementing the FAILED counter. Use `MAX_SKILL_LINES=999` to suppress for legitimately long skills.
- Before deleting/merging a skill, grep across the entire repo: `git grep -l <old-skill-name>` will reveal all 5 doc locations that need updates (skill-rules.json, registry docs, llms-full.txt, agent configs, command files).
- Repository and standalone skill-eval validators ship independently. Pin their
  acceptance parity with the same malformed/bucket/path fixtures, not just equal
  constants; both static commands must agree (LESSON-047).
- Validate git config by *resolved behaviour*, never by the configured string.
  `core.hooksPath` can be written relative or absolute, so `git config --get` plus a
  literal comparison both under-reports (`".git/hooks"` passed while `.githooks/` sat dead)
  and over-reports (`"<abs>/.githooks"` failed a correct install). Resolve with
  `git rev-parse --git-path hooks` and canonicalise before comparing.
- Linked worktrees share `.git/config` unless `extensions.worktreeConfig` is set, so one
  `git config --local` change silently applies to every worktree at once.
- `markdownlint-cli2` appends the config `globs` even when files are passed explicitly, so
  `lint_batch_if_changed`'s changed-files list still triggers a repo-wide walk. Any
  git-ignored tree that mutates mid-run (agent worktrees under `.qoder/`) aborts the whole
  lint with `ENOENT`, which the gate reports as a content failure. Exclude it in
  `.markdownlint-cli2.jsonc` `ignores`, not per-invocation.
- `while IFS=$'\t' read -r a b c; do …` silently drops a final record that has no trailing
  newline: `read` assigns the fields and *then* reports EOF, so the body never runs. Guard it
  with `|| [[ -n "$a" ]]`. `check-skill-references.sh` scanned 9 of 10 folded names this way,
  and every existing fixture wrote a terminated file, so no test could see it.
- `git diff --name-only` reports deletions as changed paths, so a changed-file lint batch can
  contain files that no longer exist and shellcheck exits 123 through `xargs` on them. Filter
  with `--diff-filter=d` (`_changed_files_z`) before handing any list to a linter.
- `VAR=x source lib.sh` does not leave `VAR` set for the statements that follow — the
  assignment is reverted with the command. A `GITHUB_BASE_REF` test written that way passed
  without ever exercising the branch it named; use `env VAR=x bash -c …`.
- A gate that could not run must not report success. `secretlint_gate.sh` returned 0 with
  "npx not found, skipping" even though `.secretlintrc.json` is itself the opt-in; it now
  fails closed with `SKIP_SECRETLINT=true` as the only escape, matching
  `check-plan-numbering.sh`, which already exits 1 when its `python3` is missing.
- A security check that is *conditional on a tool* is a fail-open. `check_link` only ran its
  traversal test when `realpath` existed and had returned a root, and `command -v realpath`
  succeeds on BSD where `realpath -m` errors — so escaping links passed on macOS. Any guard
  gated on tool availability needs a tool-free fallback (`_resolve_lexical`), plus a test that
  forces the tool-missing branch instead of only running the working one.
- A validator's remediation text is part of its contract. `validate-git-hooks.sh` advised
  `git config --local core.hooksPath .git/hooks` to escape a global hooks path, which the
  same script then rejects whenever `.githooks/` exists — and is the likely cause of this
  checkout's disabled hooks. Derive the hint from the detected hooks dir and assert it by
  running the advised command inside the test.
- `((VAR++))` is not a safe statement under `set -euo pipefail`. Post-increment evaluates to the
  *old* value, so the first bump of a zero counter returns status 1 and aborts with no message:
  `verify-commands.sh` died on its first validated command, `swarm-worktree-web-research.sh`
  before its first query. Use `VAR=$((VAR + 1))` (`((++VAR))` is also safe — it yields the new
  value). It is only fatal where the call is untested: `if fn; then` suspends `set -e` through
  the whole of `fn`, which is why the same idiom in skill scripts never surfaced.
- CI discovers tests by file name only (`bats tests/*.bats`, `pytest tests/`), so 13 of the 14
  passing suites under `tests/*.sh` (only `test-commitlint-rules.sh` was wired, via
  `quality_gate.sh`) and `tests/test-handoff-schema.py` never ran — the hyphen also
  misses pytest's `test_*.py` pattern, and a script whose checks live in `validate_schema()`
  yields zero tests even when the file is passed explicitly. Name matters as much as content:
  `tests/*.sh` now runs in the `Run tests (Shell scripts)` step, and the handoff schema lives
  in `tests/test_handoff_schema.py`. `pytest --collect-only -q` is how you prove a suite runs.
- A test that edits a tracked generated file is not self-cleaning. Test 3 of
  `test-llms-txt-generation.sh` appended `Tampered` to the repository's `llms.txt` and "restored"
  it by re-running the generator with `LLMS_TXT` still exported to the sandbox path, so the
  tampering stayed behind in the working tree. Copy the artifact into `$TEST_DIR` instead. Same
  class in `test-core-skills-compliance.sh`: it computed `agents-docs/dora-reports/$(date +%Y-%m).md`,
  `rm -f`'d it to force a fresh generation, then `rm -f`'d it again as "cleanup" — deleting a
  tracked report on every run, invisible in CI's disposable checkout. Snapshot the path, restore it
  from an `EXIT` trap, and prove the behaviour with `tests/test-core-skills-compliance.bats`.
- bats runs `setup_file` under errexit, so a gate-style command written as `cmd > out 2>&1`
  aborts the whole file with "setup_file failed with status N" when the command is *supposed*
  to fail. Capture it instead: `status=0; cmd > out 2>&1 || status=$?`, then judge the
  transcript from the tests.
- One `quality_gate.sh` pass costs ~33s, so `tests/quality-gate.bats` must not run it per test.
  It used to (13 runs) while asserting `[ "$status" -eq 0 ] || [ "$status" -eq 2 ]`, which both
  verdicts satisfy — no gate behaviour could fail it. Run once in `setup_file`, then assert the
  correspondence: exit 0 ⇒ PASSED banner, 2 ⇒ FAILED banner, 1 ⇒
  drift-on-main, exactly one verdict banner, `✗` markers present if and only if the gate
  failed, and every section header present.
- Portability work is a behaviour change until proven otherwise. `propagate-version.sh` used
  GNU-only `sed -i`, `\+` in BRE, and `sed "1a\…"`; the rewrite was validated by running the old
  and new scripts over identical `/tmp` fixtures and diffing the trees, which is what caught the
  first attempt dropping the backticks around the replacement in the `| \`VERSION\` |` cell. That
  comparison also exposed a pre-existing defect worth not copying: the `1a` append left a blank
  line at EOF for a one-line `CHANGELOG.md`, which markdownlint rejects as MD012.

## Adding a New Script

1. Must pass `shellcheck` with no warnings
2. Must have a `bats` test if stateful
3. Add to `agents-docs/SCRIPTS.md`
4. Use `#!/usr/bin/env bash` shebang
