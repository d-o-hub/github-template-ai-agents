#!/usr/bin/env bash
# generate-skill-catalog.sh - Regenerate intent-classifier skill catalog from frontmatter
#
# Usage: ./scripts/generate-skill-catalog.sh
# Writes: .agents/skills/intent-classifier/references/skill-catalog.md
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILLS_DIR="${SKILLS_DIR:-$REPO_ROOT/.agents/skills}"
OUTPUT_FILE="${OUTPUT_FILE:-$SKILLS_DIR/intent-classifier/references/skill-catalog.md}"

# ---------------------------------------------------------------------------
# Catalog description budget (characters), including the trailing ellipsis.
#
# The catalog is a routing table: intent-classifier reads it to pick between
# sibling skills, so what matters is not the opening summary but the
# discriminators -- the "Not for <sibling>" guard and the secondary trigger
# phrases. In this repo those live at the TAIL of the description, which is
# exactly what a blind char slice discards. At the previous 220-char budget,
# 52 of 54 descriptions (96.3%) were cut and 48 of the 50 "Not for" guards
# were thrown away, leaving 2 intact.
#
# 1024 is the Agent Skills specification's hard cap on `description`
# (https://agentskills.io/specification), so it is the largest budget that still
# guarantees every conformant description is emitted verbatim -- 44% headroom
# over the longest description in the catalog (progressive-delivery, 711).
# It also stays clear of Claude Code's 1536-char per-entry skill-listing cap
# for `description` + `when_to_use` (skillListingMaxDescChars,
# https://code.claude.com/docs/en/skills), leaving 512 chars of margin, so
# the text rendered here is the same text the runtime gets to trigger on.
# A routing window over the 5 longest skills is 3090 chars (~780 tokens).
#
# Truncation is now a safety valve for non-conformant input, not the normal
# path: when it does fire it lands on a word boundary and always keeps the
# guard clause verbatim.
# ---------------------------------------------------------------------------
readonly MAX_CATALOG_DESCRIPTION_CHARS=1024

# perf: replace external dirname subshell with native bash expansion
out_dir="${OUTPUT_FILE%/*}"
[[ "$out_dir" == "$OUTPUT_FILE" ]] && out_dir="."
mkdir -p -- "$out_dir"

python3 - "$SKILLS_DIR" "$OUTPUT_FILE" "$MAX_CATALOG_DESCRIPTION_CHARS" <<'PY'
"""Generate intent-classifier skill-catalog.md from live SKILL.md frontmatter."""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

skills_dir = Path(sys.argv[1])
output_file = Path(sys.argv[2])
max_desc_chars = int(sys.argv[3])
date_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d")

# Marks the sibling-discriminating clause every description in this repo ends
# with ("Not for css-render-performance."). Matched at a clause start so a
# mid-sentence "not for" in the prose cannot be mistaken for a guard.
GUARD_PATTERN = re.compile(r"(?:\A|(?<=[.!?;]))\s*(not\s+for\b)", re.IGNORECASE)

# A sentence needs this much room to be worth cutting back to; a shorter stub
# carries no trigger phrases and routes worse than an honestly elided
# paragraph would.
MIN_SENTENCE_CHARS = 80

# ASCII, not U+2026, so character counts and byte counts agree in assertions.
TRUNCATION_SUFFIX = "..."

# Stripped from a cut text before TRUNCATION_SUFFIX is appended, so an elision
# that lands on a sentence end reads "clearly..." rather than "clearly....".
TRAILING_SENTENCE_CHARS = " \t.,;:"

# A sentence end followed by whitespace or end-of-text -- a period inside an
# abbreviation or a decimal is not a boundary.
SENTENCE_END_PATTERN = re.compile(r"[.!?](?=\s|\Z)")


def split_guard(text: str) -> tuple[str, str]:
    """Split `text` into (prose, guard) on its "Not for" clause.

    Returns (text, "") when the description carries no guard.
    """
    match = GUARD_PATTERN.search(text)
    if match is None:
        return text, ""
    prose = text[: match.start()].rstrip(" .,;")
    return prose, text[match.start(1) :].strip()


def clamp_to_words(text: str, budget: int) -> str:
    """Longest prefix of `text` fitting `budget`, cut only between words.

    A single token longer than `budget` yields "" -- the caller decides whether
    to fall back rather than emit half a token.
    """
    if budget <= 0:
        return ""
    if len(text) <= budget:
        return text
    kept: list[str] = []
    used = 0
    for word in text.split():
        cost = len(word) + (1 if kept else 0)
        if used + cost > budget:
            break
        kept.append(word)
        used += cost
    return " ".join(kept).rstrip(TRAILING_SENTENCE_CHARS)


def clamp_to_sentence(text: str, budget: int) -> str:
    """Cut `text` at its last usable sentence end within `budget`.

    Returns "" when no sentence boundary qualifies, so the caller can fall back
    to a word boundary instead of ending on a stub.
    """
    if len(text) <= budget:
        return text
    ends = [m.end() for m in SENTENCE_END_PATTERN.finditer(text[:budget])]
    for end in reversed(ends):
        if end >= MIN_SENTENCE_CHARS:
            return text[:end].rstrip(TRAILING_SENTENCE_CHARS)
    return ""


def shorten(desc: str, limit: int) -> str:
    """Bound `desc` to `limit` characters without dropping routing signal.

    Preference order, most routing signal first:
      1. verbatim -- the description already fits, the common case;
      2. elide only the prose in front of the "Not for" guard, keeping the
         guard verbatim, because the guard is what separates this skill from
         its siblings;
      3. elide at a sentence boundary;
      4. elide at a word boundary.

    Every path ends on a word boundary, and each path is budgeted so the
    result is never longer than `limit`: the guard path reserves the guard
    plus the " ... " separator before clamping prose, and the other paths clamp
    against `limit - len(TRUNCATION_SUFFIX)` before appending the marker.
    """
    if len(desc) <= limit:
        return desc

    prose, guard = split_guard(desc)
    if guard:
        separator = 1 + len(TRUNCATION_SUFFIX) + 1
        kept = clamp_to_words(prose, limit - len(guard) - separator)
        if kept:
            return f"{kept} {TRUNCATION_SUFFIX} {guard}"
        # Prose cannot spare a single word: the guard is still the whole
        # routing signal, so keep it and drop the ellipsis.
        return clamp_to_words(guard, limit)

    kept = clamp_to_sentence(prose, limit - len(TRUNCATION_SUFFIX))
    if kept:
        return f"{kept}{TRUNCATION_SUFFIX}"
    kept = clamp_to_words(prose, limit - len(TRUNCATION_SUFFIX))
    return f"{kept}{TRUNCATION_SUFFIX}" if kept else TRUNCATION_SUFFIX


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

    # NOTE: only horizontal whitespace may precede the newline — a greedy
    # \s* here would swallow the next line's indentation and break block
    # scalars (|, >) by starting mid-content (empty description as result).
    desc_match = re.search(r"(?m)^description:[ \t]*([>|][+-]?)?[ \t]*\r?\n?", fm)
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
shortened = 0
for skill_md in sorted(skills_dir.glob("*/SKILL.md")):
    name = skill_md.parent.name
    if name.endswith("-workspace"):
        continue
    text = skill_md.read_text(encoding="utf-8", errors="replace")
    data = parse_frontmatter(text)
    skill = data.get("name") or name
    desc = re.sub(r"\s+", " ", (data.get("description") or "No description available")).strip()
    # Escape pipes before measuring: the escaped text is what lands in the
    # table, so the budget has to apply to it, not to the raw description.
    desc = desc.replace("|", "\\|")
    if len(desc) > max_desc_chars:
        desc = shorten(desc, max_desc_chars)
        shortened += 1
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
    f"> Description budget: {max_desc_chars} chars (Agent Skills spec cap).",
    "> Elided text ends on a word boundary and always keeps the `Not for <sibling>` guard.",
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
print(f"Generated {output_file} with {len(rows)} skills ({shortened} shortened to {max_desc_chars} chars)")
PY
