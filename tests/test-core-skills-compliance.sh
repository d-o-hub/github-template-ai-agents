#!/usr/bin/env bash
set -euo pipefail

# test-core-skills-compliance.sh - Verify the four new core skills follow repo standards.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/.agents/skills"
CORE_SKILLS=("anti-ai-slop" "skill-creator" "skill-evaluator" "dora-report")

echo "=== Verifying Core Skills Compliance ==="

# 1. Verify dora-report has >= 3 eval cases
DORA_EVALS="$SKILLS_DIR/dora-report/evals/evals.json"
if [[ -f "$DORA_EVALS" ]]; then
    count=$(python3 -c "import json, sys; print(len(json.load(open(sys.argv[1]))['evals']))" "$DORA_EVALS")
    if [[ "$count" -ge 3 ]]; then
        echo "✓ dora-report has $count eval cases (>= 3)"
    else
        echo "✗ dora-report only has $count eval cases (expected >= 3)"
        exit 1
    fi
else
    echo "✗ dora-report/evals/evals.json not found"
    exit 1
fi

# 2. Verify core skills use X.Y.Z versioning
for skill in "${CORE_SKILLS[@]}"; do
    skill_file="$SKILLS_DIR/$skill/SKILL.md"
    version=$(grep "^version:" "$skill_file" | head -n 1 | cut -d'"' -f2)
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "✓ $skill version format is valid: $version"
    else
        echo "✗ $skill has invalid version format: '$version' (expected X.Y.Z)"
        exit 1
    fi
done

# 3. Verify agents-docs/dora-reports/ directory exists
if [[ -d "$REPO_ROOT/agents-docs/dora-reports" ]]; then
    echo "✓ agents-docs/dora-reports/ directory exists"
else
    echo "✗ agents-docs/dora-reports/ directory missing"
    exit 1
fi

# 4. Verify automated generation of monthly report
echo "Running dora-report generation script..."
python3 "$SKILLS_DIR/dora-report/scripts/generate_report.py"
report_file="$REPO_ROOT/agents-docs/dora-reports/$(date +%Y-%m).md"
if [[ -f "$report_file" ]]; then
    echo "✓ Monthly report generated: $report_file"
else
    echo "✗ Monthly report NOT generated at $report_file"
    exit 1
fi

echo "=== All Core Skills Compliance Checks Passed ==="
