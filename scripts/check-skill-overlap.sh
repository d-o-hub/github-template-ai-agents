#!/usr/bin/env bash
# scripts/check-skill-overlap.sh — keyless Tier-2 skill overlap check.
# Reuse of NVIDIA SkillEvaluator Tier 2 (inter-skill similarity) without
# embeddings: word-5-gram Jaccard over normalized SKILL.md bodies flags
# verbatim duplication. Advisory by default (exit 0); --strict gates.
# See agents-docs/SKILL_EVAL_TIERS.md and ADR-037.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SKILLS_DIR="$REPO_ROOT/.agents/skills"
THRESHOLD="0.04"
STRICT=0
FORMAT="text"

usage() {
    printf 'Usage: %s [--skills-dir DIR] [--threshold FLOAT] [--strict] [--format text|json]\n' "$(basename "$0")"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills-dir) SKILLS_DIR="$2"; shift 2 ;;
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --strict) STRICT=1; shift ;;
        --format) FORMAT="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

export SKILLS_DIR THRESHOLD FORMAT STRICT
python3 <<'PYEOF'
import glob
import json
import os
import re
from itertools import combinations

skills_dir = os.environ["SKILLS_DIR"]
threshold = float(os.environ["THRESHOLD"])
format_out = os.environ["FORMAT"]

def shingles(path, n=5):
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read().lower()
    words = re.findall(r"[a-z0-9]+", text)
    return {tuple(words[i:i + n]) for i in range(len(words) - n + 1)}

names = {}
for skill_md in sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md"))):
    skill = os.path.basename(os.path.dirname(skill_md))
    names[skill] = shingles(skill_md)

pairs = []
for left, right in combinations(sorted(names), 2):
    set_left, set_right = names[left], names[right]
    union = set_left | set_right
    if not union:
        continue
    score = len(set_left & set_right) / len(union)
    if score >= threshold:
        pairs.append({"left": left, "right": right, "score": round(score, 4)})

pairs.sort(key=lambda item: item["score"], reverse=True)

if format_out == "json":
    print(json.dumps({"threshold": threshold, "pairs": pairs}, indent=2))
else:
    if pairs:
        for pair in pairs:
            print(f"OVERLAP {pair['score']:.4f} {pair['left']} {pair['right']}")
    else:
        print(f"No skill pairs at or above threshold {threshold}.")

if os.environ["STRICT"] == "1" and pairs:
    sys.exit(1)
PYEOF
