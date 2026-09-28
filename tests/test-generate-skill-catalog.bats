#!/usr/bin/env bats
# Regression tests for scripts/generate-skill-catalog.sh description handling.
#
# The catalog is a routing table, not a summary index: intent-classifier reads
# it to choose between sibling skills, so the load-bearing text is the "Not for
# <sibling>" guard and the secondary trigger phrases -- both of which live at
# the TAIL of a description. The generator used to slice descriptions at 220
# characters, which discarded exactly that text: 52 of 54 descriptions (96.3%)
# were cut mid-sentence and only 2 of the 50 "Not for" guards survived.
#
# These tests pin the three properties that make the catalog routable again:
#   1. no emitted description exceeds the documented budget;
#   2. an elided description is cut on a word boundary, never mid-word;
#   3. a "Not for" guard that sits past the old 220-char mark is still emitted.
#
# The budget is read back from the generated artifact rather than hardcoded, so
# re-tuning MAX_CATALOG_DESCRIPTION_CHARS does not require editing assertions.

setup() {
    export REPO_ROOT="$BATS_TEST_DIRNAME/.."
    export SKILLS_DIR="$REPO_ROOT/.agents/skills"
    FIXTURE_DIR="$(mktemp -d)"
    export FIXTURE_DIR
    # Historical budget that used to drop the routing guards. Kept as a named
    # constant because the whole point of these tests is that guards *past* it
    # used to be discarded.
    export LEGACY_DESCRIPTION_BUDGET=220
    # The corpus and fixture tests below share one word-boundary checker, so
    # the fixture tests prove the corpus assertion can actually fail.
    export BOUNDARY_CHECK="$FIXTURE_DIR/check_word_boundary.py"
    cat > "$BOUNDARY_CHECK" <<'PY'
#!/usr/bin/env python3
"""Assert every catalog description is a token-aligned reduction of its source.

Usage: check_word_boundary.py <skills-dir> <catalog-file> [skill-name]

The generator elides text by dropping whole whitespace-separated tokens, so
every token it emits must appear verbatim in the source description. A
character-level slice instead yields a token that is a strict prefix of a
source token, which is what this flags.

Prints one line per finding and exits 1 when any description was cut mid-word.
"""
import re
import sys

MARKER = "..."


def split_cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]


def catalog_rows(path):
    for line in open(path, encoding="utf-8").read().splitlines():
        if not line.startswith("| ") or line.startswith("| Skill"):
            continue
        if set(line) <= set("| -"):
            continue
        cells = split_cells(line)
        yield cells[0], cells[1].replace("\\|", "|")


def frontmatter_description(path):
    """Whitespace-normalized YAML description, or None when unparseable."""
    import yaml

    parts = open(path, encoding="utf-8", errors="replace").read().split("---", 2)
    if len(parts) < 2:
        return None
    try:
        data = yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError:
        return None
    description = data.get("description")
    if not isinstance(description, str):
        return None
    return re.sub(r"\s+", " ", description).strip()


def unaligned_tokens(desc, source_tokens):
    """Tokens in `desc` that no whole source token accounts for.

    The elision marker stands alone when a guard follows it, but the
    guard-retaining path glues it to the last kept word, so both forms are
    accepted -- while a genuine mid-word slice is still rejected.
    """
    tokens = desc.split()
    bad = []
    for index, token in enumerate(tokens):
        if token == MARKER:
            continue
        if token.endswith(MARKER) and index == len(tokens) - 1:
            token = token[: -len(MARKER)]
            if not token:
                continue
        if token not in source_tokens:
            bad.append(token)
    return bad


def main(argv):
    if len(argv) not in (3, 4):
        print("usage: check_word_boundary.py <skills-dir> <catalog> [skill]", file=sys.stderr)
        return 2
    skills_dir, catalog_path = argv[1], argv[2]
    only = argv[3] if len(argv) == 4 else None

    checked, failures = 0, 0
    for skill, desc in catalog_rows(catalog_path):
        if only is not None and skill != only:
            continue
        description = frontmatter_description(skills_dir + "/" + skill + "/SKILL.md")
        if description is None:
            print("SKIP {}: no parseable description".format(skill))
            continue
        checked += 1
        bad = unaligned_tokens(desc, set(description.split()))
        for token in bad:
            print("FAIL {}: mid-word elision {!r}".format(skill, token))
        failures += len(bad)
    if not checked:
        print("FAIL no skill matched -- the assertion would pass vacuously")
        return 1
    print("checked {} description(s): {} mid-word cut(s)".format(checked, failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PY
}

teardown() {
    rm -rf "$FIXTURE_DIR"
}

# Emits a SKILL.md whose description is long enough to force the generator's
# truncation path, with the "Not for" guard placed past the legacy budget.
# $1 = skill dir name, $2 = filler clause, $3 = guard clause.
make_long_skill() {
    local dir="$FIXTURE_DIR/$1"
    mkdir -p "$dir"
    python3 - "$dir/SKILL.md" "$2" "$3" <<'PY'
import sys

path, filler, guard = sys.argv[1], sys.argv[2], sys.argv[3]
# Folded block scalar so the description can contain ": " without YAML
# ambiguity -- the shape the real catalog skills use.
body = " ".join([filler] * 40) + " " + guard
with open(path, "w", encoding="utf-8") as handle:
    handle.write("---\n")
    handle.write("name: " + path.rsplit("/", 2)[-2] + "\n")
    handle.write("category: quality\n")
    handle.write("description: >-\n")
    for line in body.split(" "):
        handle.write("  " + line + "\n")
    handle.write("license: MIT\n")
    handle.write("---\n\n# Fixture\n")
PY
}

# Prints "<skill>|<description>" per catalog row, pipes unescaped.
dump_rows() {
    python3 - "$1" <<'PY'
import re
import sys

rows = []
for line in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if not line.startswith("| ") or line.startswith("| Skill") or set(line) <= set("| -"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    rows.append((cells[0], cells[1].replace("\\|", "|")))
for skill, desc in rows:
    print("{}|{}".format(skill, desc))
PY
}

# Prints the budget the artifact documents in its own header.
read_budget() {
    python3 - "$1" <<'PY'
import re
import sys

match = re.search(r"^> Description budget: (\d+) chars",
                  open(sys.argv[1], encoding="utf-8").read(), re.M)
print(match.group(1) if match else 0)
PY
}

# --- Corpus ----------------------------------------------------------------

@test "generated catalog documents its own description budget" {
    run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]
    [[ "$output" == *"chars"* ]]

    budget="$(read_budget "$SKILLS_DIR/intent-classifier/references/skill-catalog.md")"
    [ "$budget" -gt "$LEGACY_DESCRIPTION_BUDGET" ]
}

@test "no catalog description exceeds the documented budget" {
    OUTPUT_FILE="$FIXTURE_DIR/catalog.md" run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]

    budget="$(read_budget "$FIXTURE_DIR/catalog.md")"
    [ "$budget" -gt 0 ]

    run python3 - "$FIXTURE_DIR/catalog.md" "$budget" <<'PY'
import sys

limit = int(sys.argv[2])
over = []
count = 0
for line in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if not line.startswith("| ") or line.startswith("| Skill") or set(line) <= set("| -"):
        continue
    skill = line.strip().strip("|").split("|")[0].strip()
    desc = line.strip().strip("|").split("|")[1].strip()
    count += 1
    if len(desc) > limit:
        over.append("{}: {} chars".format(skill, len(desc)))
print("checked {} descriptions against a {} char budget".format(count, limit))
for entry in over:
    print("FAIL over budget -> " + entry)
sys.exit(1 if over or not count else 0)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"descriptions against a"* ]]
}

@test "guards sitting past the legacy budget survive into the catalog" {
    # The measured regression: under the old 220-char slice these guards were
    # sliced away, leaving 2 of 50 intact and making sibling skills
    # indistinguishable to the router.
    OUTPUT_FILE="$FIXTURE_DIR/catalog.md" run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]

    run python3 - "$SKILLS_DIR" "$FIXTURE_DIR/catalog.md" "$LEGACY_DESCRIPTION_BUDGET" <<'PY'
import glob
import os
import re
import sys

import yaml

skills_dir, catalog_path, legacy = sys.argv[1], sys.argv[2], int(sys.argv[3])

catalog = {}
for line in open(catalog_path, encoding="utf-8").read().splitlines():
    if not line.startswith("| ") or line.startswith("| Skill") or set(line) <= set("| -"):
        continue
    cells = [c.strip() for c in line.strip().strip("|").split("|")]
    catalog[cells[0]] = cells[1].replace("\\|", "|")

past, lost = 0, []
for path in sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md"))):
    name = os.path.basename(os.path.dirname(path))
    with open(path, encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    parts = text.split("---", 2)
    if len(parts) < 2:
        continue
    # Parse rather than regex: a "Not for" clause runs to the end of the
    # description, and a regex over the raw frontmatter block would run past
    # it into the next key ("license: MIT").
    try:
        data = yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError:
        continue
    description = re.sub(r"\s+", " ", str(data.get("description") or "")).strip()
    index = description.find("Not for")
    if index < 0 or index < legacy:
        continue
    past += 1
    guard = description[index:].rstrip().rstrip(".").rstrip()
    if guard and guard not in catalog.get(name, ""):
        lost.append("{}: {!r}".format(name, guard[:60]))

print("{} guards start past the legacy {} char mark".format(past, legacy))
for entry in lost:
    print("FAIL guard dropped -> " + entry)
# Guard against a vacuous pass: the corpus must actually contain the hazard.
sys.exit(1 if lost or past < 2 else 0)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"guards start past the legacy"* ]]
}

# --- Truncation path -------------------------------------------------------

@test "elision lands on a word boundary and keeps the guard" {
    make_long_skill skill-long \
        "Routine explanation that pads the description well past any sane budget." \
        "Not for sibling-skill, other-skill."
    OUTPUT_FILE="$FIXTURE_DIR/catalog.md" \
        SKILLS_DIR="$FIXTURE_DIR" run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]

    run python3 - "$FIXTURE_DIR/skill-long/SKILL.md" "$FIXTURE_DIR/catalog.md" <<'PY'
import re
import sys

row = [l for l in open(sys.argv[2], encoding="utf-8").read().splitlines()
       if l.startswith("| skill-long")][0]
desc = [c.strip() for c in row.strip().strip("|").split("|")][1]

problems = []
if "..." not in desc:
    problems.append("fixture did not exercise the truncation path: {!r}".format(desc[-40:]))
# The guard is the routing discriminator and must survive whole.
if "Not for sibling-skill, other-skill." not in desc:
    problems.append("guard dropped: {!r}".format(desc[-60:]))
for problem in problems:
    print("FAIL " + problem)
if not problems:
    print("guard retained in a shortened description: {} chars".format(len(desc)))
sys.exit(1 if problems else 0)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"guard retained in a shortened description"* ]]

    run python3 "$BOUNDARY_CHECK" "$FIXTURE_DIR" "$FIXTURE_DIR/catalog.md" skill-long
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 mid-word cut(s)"* ]]
}

@test "a description past the budget is shortened, not passed through" {
    make_long_skill skill-long \
        "Routine explanation that pads the description well past any sane budget." \
        "Not for sibling-skill."
    OUTPUT_FILE="$FIXTURE_DIR/catalog.md" \
        SKILLS_DIR="$FIXTURE_DIR" run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]

    budget="$(read_budget "$FIXTURE_DIR/catalog.md")"
    run dump_rows "$FIXTURE_DIR/catalog.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skill-long|"* ]]
    emitted="${output#*skill-long|}"
    [ "${#emitted}" -le "$budget" ]
    [[ "$emitted" == *"..."* ]]
}

@test "a guardless description past the budget still ends on a word boundary" {
    # Exercises the sentence-boundary and word-boundary fallbacks, which the
    # guard-retaining path bypasses. A run-on token with no sentence boundary
    # anywhere forces the word-boundary fallback.
    make_long_skill skill-runon \
        "OneVeryLongRunOnClauseWithoutAnySentenceBoundaryAtAll" \
        ""
    OUTPUT_FILE="$FIXTURE_DIR/catalog.md" \
        SKILLS_DIR="$FIXTURE_DIR" run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]

    budget="$(read_budget "$FIXTURE_DIR/catalog.md")"
    run dump_rows "$FIXTURE_DIR/catalog.md"
    [ "$status" -eq 0 ]
    emitted="${output#*skill-runon|}"
    [ "${#emitted}" -le "$budget" ]
    [[ "$emitted" == *"..."* ]]

    # No guard here, so the elision is pure word-boundary work and this is
    # where a mid-word slice would show up.
    run python3 "$BOUNDARY_CHECK" "$FIXTURE_DIR" "$FIXTURE_DIR/catalog.md" skill-runon
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 mid-word cut(s)"* ]]
}

@test "no corpus description is cut mid-word" {
    OUTPUT_FILE="$FIXTURE_DIR/catalog.md" run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]

    run python3 "$BOUNDARY_CHECK" "$SKILLS_DIR" "$FIXTURE_DIR/catalog.md"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 mid-word cut(s)"* ]]
    # Non-vacuous: the scan must actually have inspected the corpus.
    run python3 - "$SKILLS_DIR" "$FIXTURE_DIR/catalog.md" <<'PY'
import sys

rows = [l for l in open(sys.argv[2], encoding="utf-8").read().splitlines()
        if l.startswith("| ") and not l.startswith("| Skill") and set(l) > set("| -")]
print("rows {}".format(len(rows)))
sys.exit(0 if len(rows) > 1 else 1)
PY
    [ "$status" -eq 0 ]
}

@test "the word-boundary checker rejects a character-level slice" {
    # Proves the corpus test can fail: a hand-built catalog row sliced mid-word
    # must be reported, otherwise "0 mid-word cut(s)" proves nothing.
    mkdir -p "$FIXTURE_DIR/skill-slice"
    cat > "$FIXTURE_DIR/skill-slice/SKILL.md" <<'MD'
---
name: skill-slice
category: quality
description: Boundarycheckingdescriptor Not for sibling-skill.
license: MIT
---

# Fixture
MD
    cat > "$FIXTURE_DIR/sliced.md" <<'MD'
# Skill Catalog

## Available Skills

| Skill | Description | Category |
|-------|-------------|----------|
| skill-slice | Boundarycheckingdescrip... | quality |
MD
    run python3 "$BOUNDARY_CHECK" "$FIXTURE_DIR" "$FIXTURE_DIR/sliced.md" skill-slice
    [ "$status" -eq 1 ]
    [[ "$output" == *"mid-word elision"* ]]
    [[ "$output" != *"Traceback"* ]]
}

@test "a description inside the budget is emitted verbatim" {
    # The budget is a safety valve, not the normal path: nothing in a
    # conformant catalog should be shortened.
    mkdir -p "$FIXTURE_DIR/skill-short"
    cat > "$FIXTURE_DIR/skill-short/SKILL.md" <<'MD'
---
name: skill-short
category: quality
description: Triage findings. Not for code-review-assistant.
license: MIT
---

# Fixture
MD
    OUTPUT_FILE="$FIXTURE_DIR/catalog.md" \
        SKILLS_DIR="$FIXTURE_DIR" run ./scripts/generate-skill-catalog.sh
    [ "$status" -eq 0 ]

    run dump_rows "$FIXTURE_DIR/catalog.md"
    [ "$status" -eq 0 ]
    [ "$output" = "skill-short|Triage findings. Not for code-review-assistant." ]
}
