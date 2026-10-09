#!/usr/bin/env bash
# Static structural audit of the skills in .agents/skills.
#
# What this script actually checks:
#   1. Per-skill directory layout, via .agents/skills/skill-evaluator/scripts/
#      check_structure.py: no nested <skill>/<skill>/ duplicate, SKILL.md
#      present, and the presence of references/, scripts/ and evals/.
#   2. evals/evals.json, via the same script: the file exists and parses, a
#      top-level "evals" array is present, every case carries id + prompt +
#      expected_output + assertions, at least 3 cases are required, and the optional
#      4-bucket taxonomy is coherent (no unknown bucket; if any bucket is
#      declared, a "negative" case must exist).
#   3. Required eval fields, via an awk pass over every evals.json (both the
#      skills/<name>/evals.json and skills/<name>/evals/evals.json layouts):
#      expected_output + id + prompt + assertions must all appear. The legacy
#      "should_trigger" key is rejected, and "files" must be a plain array of
#      path strings rather than objects carrying path/content.
#   4. Zero-byte evals.json files, which satisfy no awk pattern and would
#      otherwise pass unnoticed; reported as missing all four required fields.
#   5. SKILL.md content, via an awk pass: the only content rule is that the
#      doc must not reference a non-existent "should_trigger" key.
#   6. Input fixtures, via a Python pass: every path in a non-empty
#      evals[].files must exist under the skill root, so a case cannot name a
#      fixture that was never committed.
#
# What this script does NOT check:
#   - SKILL.md YAML frontmatter. It is never parsed; no frontmatter key (name,
#     description, version, allowed-tools, ...) is validated here. Frontmatter
#     validation lives in scripts/lib/skill-validation.sh.
#   - Behaviour. No assertion is scored against model output. This and
#     scripts/run-evals.py are static/smoke checks; paired model runs require
#     the manual evidence workflow in skill-evaluator.
#
# Exit 0 = all pass, Exit 1 = needs work.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"
EVAL_SCRIPT="$SKILLS_DIR/skill-evaluator/scripts/check_structure.py"

echo "=== Static skill audit (template schema/layout/fixtures) ==="
echo ""

if [[ ! -f "$EVAL_SCRIPT" ]]; then
  printf "ERROR: check_structure.py not found at %s\n" "$EVAL_SCRIPT" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  printf "ERROR: python3 required but not found in PATH\n" >&2
  exit 1
fi

# Run the structure/eval checker
python3 "$EVAL_SCRIPT" --path "$SKILLS_DIR"

# Additional checks
echo ""
echo "=== Additional Validations ==="
echo ""

FAILED=0

# Optimization: Use batched awk pass via xargs for evals.json validation instead of loop with grep
if ! find "$SKILLS_DIR" -type f -name "evals.json" -print0 2>/dev/null | xargs -0 awk -- '
    BEGIN { failed = 0 }
    FNR == 1 {
      if (NR > 1) {
        if (!has_expected_output) { print " [FAIL] " skill_name ": evals missing \x27expected_output\x27 field"; failed = 1 }
        if (!has_id) { print " [FAIL] " skill_name ": evals missing \x27id\x27 field"; failed = 1 }
        if (!has_prompt) { print " [FAIL] " skill_name ": evals missing \x27prompt\x27 field"; failed = 1 }
        if (!has_assertions) { print " [FAIL] " skill_name ": evals missing \x27assertions\x27 field"; failed = 1 }
      }

      n = split(FILENAME, parts, "/")
      skill_name = parts[n-2]

      has_should_trigger = 0
      has_expected_output = 0
      has_id = 0
      has_prompt = 0
      has_assertions = 0
      has_path = 0
    }
    /"should_trigger"/ {
      if (!has_should_trigger) { print " [FAIL] " skill_name ": evals use \x27expected_output\x27 not \x27should_trigger\x27"; failed = 1; has_should_trigger = 1 }
    }
    /"expected_output"/ { has_expected_output = 1 }
    /"id"/ { has_id = 1 }
    /"prompt"/ { has_prompt = 1 }
    /"assertions"/ { has_assertions = 1 }
    /"path"/ {
      if (!has_path) { print " [FAIL] " skill_name ": evals \x27files\x27 must be string array of paths, not objects with \x27path\x27/\x27content\x27"; failed = 1; has_path = 1 }
    }
    END {
      if (NR > 0) {
        if (!has_expected_output) { print " [FAIL] " skill_name ": evals missing \x27expected_output\x27 field"; failed = 1 }
        if (!has_id) { print " [FAIL] " skill_name ": evals missing \x27id\x27 field"; failed = 1 }
        if (!has_prompt) { print " [FAIL] " skill_name ": evals missing \x27prompt\x27 field"; failed = 1 }
        if (!has_assertions) { print " [FAIL] " skill_name ": evals missing \x27assertions\x27 field"; failed = 1 }
      }
      if (failed) exit(1)
    }
  '; then
  FAILED=1
fi

# We also need to check if the file is empty, which awk skips.
# Fast path check for 0-byte files which would fail all field validations
# Optimization: Use native bash globbing instead of find process substitution
shopt -s nullglob
for eval_file in "$SKILLS_DIR"/*/evals.json "$SKILLS_DIR"/*/evals/evals.json; do
  [[ -f "$eval_file" ]] || continue
  if [[ ! -s "$eval_file" ]]; then
    # Extract skill name safely regardless of whether it's in root or evals/ subdir
    if [[ "$eval_file" == */evals/evals.json ]]; then
      dir_path="${eval_file%/*/*}"
    else
      dir_path="${eval_file%/*}"
    fi
    skill_name="${dir_path##*/}"
    printf " [FAIL] %s: evals missing 'expected_output' field\n" "$skill_name"
    printf " [FAIL] %s: evals missing 'id' field\n" "$skill_name"
    printf " [FAIL] %s: evals missing 'prompt' field\n" "$skill_name"
    printf " [FAIL] %s: evals missing 'assertions' field\n" "$skill_name"
    FAILED=1
  fi
done
shopt -u nullglob


# Check 6: every path in a non-empty evals[].files must exist.
#
# The agentskills.io / NVIDIA SkillEvaluator convention is that files[] names
# input fixtures relative to the skill root, staged into the eval workspace.
# Nothing in the repo verified they were real, so a case could name a path that
# was never committed and scripts/run-evals.py would then report it as a
# missing input -- indistinguishable from a genuinely absent fixture.
if ! python3 - "$SKILLS_DIR" <<'PYTHON_FIXTURE_CHECK'; then
import json
import sys
from pathlib import Path

skills_dir = Path(sys.argv[1])
failed = False

for evals_path in sorted(skills_dir.glob("*/evals/evals.json")) + sorted(
    skills_dir.glob("*/evals.json")
):
    skill_root = evals_path.parent.parent
    skill_name = skill_root.name
    try:
        evals = json.loads(evals_path.read_text()).get("evals", [])
    except (OSError, json.JSONDecodeError):
        continue  # reported by the field checks above

    for case in evals:
        for rel in case.get("files") or []:
            if not isinstance(rel, str):
                continue  # object form is rejected by the awk pass above
            if not (skill_root / rel).is_file():
                print(
                    f" [FAIL] {skill_name}: eval #{case.get('id', '?')} names "
                    f"files[] entry '{rel}', which does not exist under the "
                    f"skill root"
                )
                failed = True

sys.exit(1 if failed else 0)
PYTHON_FIXTURE_CHECK
  FAILED=1
fi


# Optimization: Use batched awk pass via xargs for SKILL.md validation instead of loop with grep
if ! find "$SKILLS_DIR" -maxdepth 2 -type f -name "SKILL.md" -print0 2>/dev/null | xargs -0 awk -- '
    BEGIN { failed = 0 }
    FNR == 1 {
      n = split(FILENAME, parts, "/")
      skill_name = parts[n-1]
      has_should_trigger = 0
    }
    /should_trigger/ {
      if (!has_should_trigger) {
        print " [FAIL] " skill_name ": SKILL.md references non-existent \x27should_trigger\x27"
        failed = 1
        has_should_trigger = 1
      }
    }
    END { if (failed) exit(1) }
  '; then
  FAILED=1
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
  echo "All eval checks passed"
  exit 0
else
  echo "Some checks failed -- fix and re-run"
  exit 1
fi
