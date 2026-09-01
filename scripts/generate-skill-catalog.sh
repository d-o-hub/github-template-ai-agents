#!/usr/bin/env bash
# generate-skill-catalog.sh - Regenerate intent-classifier skill catalog from frontmatter
#
# Usage: ./scripts/generate-skill-catalog.sh
# Writes: .agents/skills/intent-classifier/references/skill-catalog.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILLS_DIR="${SKILLS_DIR:-$REPO_ROOT/.agents/skills}"
OUTPUT_FILE="${OUTPUT_FILE:-$SKILLS_DIR/intent-classifier/references/skill-catalog.md}"

# perf: replace external dirname subshell with native bash expansion
out_dir="${OUTPUT_FILE%/*}"
[[ "$out_dir" == "$OUTPUT_FILE" ]] && out_dir="."
mkdir -p -- "$out_dir"

python3 - "$SKILLS_DIR" "$OUTPUT_FILE" <<'PY'
"""Generate intent-classifier skill-catalog.md from live SKILL.md frontmatter."""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

skills_dir = Path(sys.argv[1])
output_file = Path(sys.argv[2])
date_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d")


def parse_frontmatter(text: str) -> dict[str, str]:
    match = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not match:
        return {}
    fm = match.group(1)
    data: dict[str, str] = {}

    for key in ("name", "category", "version", "license"):
        key_match = re.search(rf"(?m)^{key}:\s*(.+)$", fm)
        if key_match:
            data[key] = key_match.group(1).strip().strip("\"'")

    desc_match = re.search(r"(?m)^description:\s*([>|][+-]?)?\s*\n?", fm)
    if not desc_match:
        data["description"] = ""
        return data

    end = desc_match.end()
    block = desc_match.group(1)
    if block:
        lines: list[str] = []
        for line in fm[end:].splitlines():
            if re.match(r"^[a-zA-Z_][\w-]*:", line):
                break
            if line.startswith((" ", "\t")) or line == "":
                stripped = line.strip()
                if stripped:
                    lines.append(stripped)
            else:
                break
        data["description"] = " ".join(lines)
    else:
        first = fm[desc_match.start() :].splitlines()[0]
        data["description"] = first.split(":", 1)[1].strip().strip("\"'")
    return data


rows: list[tuple[str, str, str]] = []
for skill_md in sorted(skills_dir.glob("*/SKILL.md")):
    name = skill_md.parent.name
    if name.endswith("-workspace"):
        continue
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    data = parse_frontmatter(text)
    skill = data.get("name") or name
    desc = re.sub(r"\s+", " ", (data.get("description") or "No description available")).strip()
    desc = desc.replace("|", "\\|")
    if len(desc) > 220:
        desc = desc[:217] + "..."
    category = data.get("category") or "general"
    rows.append((skill, desc, category))

rows.sort(key=lambda item: item[0].lower())
by_category: dict[str, list[str]] = defaultdict(list)
for skill, _desc, category in rows:
    by_category[category].append(skill)

lines = [
    "# Skill Catalog",
    "",
    "> Auto-generated from `.agents/skills/` directory.",
    f"> Last updated: {date_utc}",
    "> Do not edit manually. Run `./scripts/generate-skill-catalog.sh`.",
    "",
    "## Available Skills",
    "",
    "| Skill | Description | Category |",
    "|-------|-------------|----------|",
]
for skill, desc, category in rows:
    lines.append(f"| {skill} | {desc} | {category} |")

lines.extend(["", "## Skill Categories", ""])
for category in sorted(by_category):
    lines.append(f"### {category}")
    lines.append("")
    for skill in sorted(by_category[category], key=str.lower):
        lines.append(f"- {skill}")
    lines.append("")

lines.extend(
    [
        "## Usage",
        "",
        "The `intent-classifier` skill uses this catalog for routing.",
        "Regenerate after adding, renaming, or removing skills.",
        "",
    ]
)

output_file.write_text("\n".join(lines), encoding="utf-8")
print(f"Generated {output_file} with {len(rows)} skills")
PY
