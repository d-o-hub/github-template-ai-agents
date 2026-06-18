#!/bin/bash
# Full skill evaluation against acceptance criteria
SKILLS_DIR=".agents/skills"
RESULTS="skills-evaluation/iteration-1/structure_check.json"

echo "[" > "$RESULTS"
first=true

for skill_dir in "$SKILLS_DIR"/*/; do
  skill=$(basename "$skill_dir")
  skill_md="$skill_dir/SKILL.md"
  evals_json="$skill_dir/evals/evals.json"
  
  [ ! -f "$skill_md" ] && continue
  
  # Check if deprecated
  if grep -q "DEPRECATED.*Use git-github" "$skill_md" 2>/dev/null; then
    continue
  fi
  
  # 1. Frontmatter checks
  has_name=$(grep -c "^name:" "$skill_md" 2>/dev/null || echo 0)
  has_desc=$(grep -c "^description:" "$skill_md" 2>/dev/null || echo 0)
  [ "$has_desc" -eq 0 ] && has_desc=$(grep -c "^  description:" "$skill_md" 2>/dev/null || echo 0)
  has_cat=$(grep -c "^category:" "$skill_md" 2>/dev/null || echo 0)
  has_ver=$(grep -c "^version:" "$skill_md" 2>/dev/null || echo 0)
  
  # 2. Section checks
  has_when=$(grep -c "## When to Use" "$skill_md" 2>/dev/null || echo 0)
  has_rational=$(grep -c "^## Rationalizations" "$skill_md" 2>/dev/null || echo 0)
  has_flags=$(grep -c "^## Red Flags" "$skill_md" 2>/dev/null || echo 0)
  has_see_also=$(grep -c "## See Also" "$skill_md" 2>/dev/null || echo 0)
  
  # 3. Line count
  lines=$(wc -l < "$skill_md")
  
  # 4. Description length
  
  # 5. Trigger phrasing
  has_trigger=$(grep -ci "use this skill\|use when\|triggers on\|even if they" "$skill_md" 2>/dev/null || echo 0)
  
  # 6. Rationalizations headers
  wrong_headers=$(grep -c "Challenge|Rationale\|Concern|Counter-Argument\|Excuses|Counter-arguments" "$skill_md" 2>/dev/null || echo 0)
  
  # 7. Variant headings
  variant_headings=$(grep -c "## When To Use\|## When to use\|## When to run\|## When to activate\|## When to Use This Skill\|## Reference Files" "$skill_md" 2>/dev/null || echo 0)
  
  # 8. Evals
  eval_count=0
  assertion_count=0
  if [ -f "$evals_json" ]; then
    eval_count=$(jq '.evals | length' "$evals_json" 2>/dev/null || echo 0)
    assertion_count=$(jq '[.evals[].assertions // [] | length] | add // 0' "$evals_json" 2>/dev/null || echo 0)
  fi
  
  # 9. Has references dir
  has_refs="false"
  [ -d "$skill_dir/references" ] && has_refs="true"
  
  # 10. Has scripts dir
  [ -d "$skill_dir/scripts" ] && has_scripts="true"
  
  # Calculate score
  score=0
  [ "$has_name" -gt 0 ] && score=$((score + 1))
  [ "$has_desc" -gt 0 ] && score=$((score + 1))
  [ "$has_cat" -gt 0 ] && score=$((score + 1))
  [ "$has_ver" -gt 0 ] && score=$((score + 1))
  [ "$has_when" -gt 0 ] && score=$((score + 1))
  [ "$has_rational" -gt 0 ] && score=$((score + 1))
  [ "$has_flags" -gt 0 ] && score=$((score + 1))
  [ "$has_see_also" -gt 0 ] && score=$((score + 1))
  [ "$lines" -le 250 ] && score=$((score + 1))
  [ "$has_trigger" -gt 0 ] && score=$((score + 1))
  [ "$wrong_headers" -eq 0 ] && score=$((score + 1))
  [ "$variant_headings" -eq 0 ] && score=$((score + 1))
  [ "$eval_count" -ge 3 ] && score=$((score + 1))
  [ "$assertion_count" -gt 0 ] && score=$((score + 1))
  
  # Determine verdict
  verdict="PASS"
  [ "$score" -lt 14 ] && verdict="NEEDS_WORK"
  [ "$score" -lt 10 ] && verdict="FAIL"
  
  [ "$first" = true ] && first=false || echo "," >> "$RESULTS"
  
  cat >> "$RESULTS" << EOF
  {
    "skill": "$skill",
    "score": $score,
    "max_score": 14,
    "verdict": "$verdict",
    "lines": $lines,
    "eval_count": $eval_count,
    "assertion_count": $assertion_count,
    "has_trigger": $([ "$has_trigger" -gt 0 ] && echo "true" || echo "false"),
    "has_when_to_use": $([ "$has_when" -gt 0 ] && echo "true" || echo "false"),
    "has_see_also": $([ "$has_see_also" -gt 0 ] && echo "true" || echo "false"),
    "has_references": $has_refs,
    "wrong_headers": $wrong_headers,
    "variant_headings": $variant_headings
  }
EOF
done

echo "" >> "$RESULTS"
echo "]" >> "$RESULTS"
echo "Evaluation complete"
