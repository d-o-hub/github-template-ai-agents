#!/usr/bin/env bash
# Evaluates skill quality by running check_structure.py against .agents/skills.
# Validates eval coverage, frontmatter fields, and directory structure.
# Exit 0 = all pass, Exit 1 = needs work.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"
EVAL_SCRIPT="$SKILLS_DIR/skill-evaluator/scripts/check_structure.py"

echo "=== Evaluating Skills (agentskills.io spec) ==="
echo ""

if [ ! -f "$EVAL_SCRIPT" ]; then
  echo "ERROR: check_structure.py not found at $EVAL_SCRIPT"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 required but not found in PATH"
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
if ! find "$SKILLS_DIR" -type f -name "evals.json" -print0 2>/dev/null | xargs -0 -r awk -- '
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
  [ -f "$eval_file" ] || continue
  if [ ! -s "$eval_file" ]; then
    # Extract skill name safely regardless of whether it's in root or evals/ subdir
    if [[ "$eval_file" == */evals/evals.json ]]; then
      dir_path="${eval_file%/*/*}"
    else
      dir_path="${eval_file%/*}"
    fi
    skill_name="${dir_path##*/}"
    echo " [FAIL] $skill_name: evals missing 'expected_output' field"
    echo " [FAIL] $skill_name: evals missing 'id' field"
    echo " [FAIL] $skill_name: evals missing 'prompt' field"
    echo " [FAIL] $skill_name: evals missing 'assertions' field"
    FAILED=1
  fi
done
shopt -u nullglob


# Optimization: Use batched awk pass via xargs for SKILL.md validation instead of loop with grep
if ! find "$SKILLS_DIR" -maxdepth 2 -type f -name "SKILL.md" -print0 2>/dev/null | xargs -0 -r awk -- '
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
if [ $FAILED -eq 0 ]; then
  echo "All eval checks passed"
  exit 0
else
  echo "Some checks failed -- fix and re-run"
  exit 1
fi
