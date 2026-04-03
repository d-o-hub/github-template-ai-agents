#!/bin/bash
# Simple skill format validator

echo "=== Validating SKILL.md Format ==="
ERRORS=0

for skill_dir in .agents/skills/*/; do
    if [[ -d "$skill_dir" ]]; then
        skill_file="${skill_dir}SKILL.md"
        skill_name=$(basename "$skill_dir")
        
        if [[ ! -f "$skill_file" ]]; then
            echo "[ERROR] $skill_name: Missing SKILL.md"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # Check starts with ---
        first=$(head -1 "$skill_file")
        if [[ "$first" != "---" ]]; then
            echo "[ERROR] $skill_name: Must start with '---'"
            ERRORS=$((ERRORS + 1))
            continue
        fi
        
        # Check has name field
        if ! grep -q "^name:" "$skill_file"; then
            echo "[ERROR] $skill_name: Missing 'name:' field"
            ERRORS=$((ERRORS + 1))
        fi
        
        # Check has description field
        if ! grep -q "^description:" "$skill_file"; then
            echo "[ERROR] $skill_name: Missing 'description:' field"
            ERRORS=$((ERRORS + 1))
        fi
        
        if [[ $ERRORS -eq 0 ]]; then
            lines=$(wc -l < "$skill_file")
            echo "[OK] $skill_name: Valid ($lines lines)"
        fi
    fi
done

echo ""
if [[ $ERRORS -eq 0 ]]; then
    echo "All SKILL.md files passed validation"
    exit 0
else
    echo "Found $ERRORS errors"
    exit 1
fi
