#!/usr/bin/env bats
# Regression tests: every SKILL.md frontmatter block must be valid YAML.
#
# The Agent Skills specification (https://agentskills.io/specification) requires
# valid YAML frontmatter, so a spec-conformant parser hard-errors on broken
# input. scripts/lib/skill-validation.sh cannot catch this class of bug because
# it matches fields with a line-prefix regex instead of parsing YAML -- these
# tests therefore parse the frontmatter with yaml.safe_load().
#
# Historical breakage: five skills shipped frontmatter that yaml.safe_load()
# rejected -- plain scalars containing ": " (git-github-workflow, goap-agent,
# progressive-delivery, secrets-management) and a double-quoted scalar with
# unescaped inner quotes (skill-evaluator).

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SKILLS_DIR="$REPO_ROOT/.agents/skills"
    export FIXTURE_DIR="$(mktemp -d)"
    # The corpus test and the fixture tests share one checker, so the fixture
    # tests prove the corpus test can actually fail.
    export FRONTMATTER_CHECK="$FIXTURE_DIR/check_frontmatter.py"
    cat > "$FRONTMATTER_CHECK" <<'PY'
#!/usr/bin/env python3
"""Validate SKILL.md YAML frontmatter with a real YAML parser.

Usage: check_frontmatter.py <skills-dir>

Prints one line per finding and exits 1 when any SKILL.md is unusable.
"""
import glob
import os
import sys

import yaml

REQUIRED_KEYS = ("name", "description")


def frontmatter_block(text):
    """Return the raw frontmatter text, or None when delimiters are absent."""
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    return parts[1] if len(parts) > 1 else None


def main(argv):
    if len(argv) != 2:
        print("usage: check_frontmatter.py <skills-dir>", file=sys.stderr)
        return 2
    skills_dir = argv[1]
    paths = sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md")))
    if not paths:
        print("FAIL no SKILL.md files found under " + skills_dir)
        return 1

    failures = 0
    for path in paths:
        with open(path, encoding="utf-8") as handle:
            block = frontmatter_block(handle.read())
        if block is None:
            print("FAIL {}: missing YAML frontmatter delimiters".format(path))
            failures += 1
            continue
        try:
            data = yaml.safe_load(block)
        except yaml.YAMLError as exc:
            reason = str(exc).splitlines()[0]
            print("FAIL {}: unparseable YAML frontmatter: {}".format(path, reason))
            failures += 1
            continue
        if not isinstance(data, dict):
            print("FAIL {}: frontmatter is {}, expected a mapping".format(
                path, type(data).__name__))
            failures += 1
            continue
        for key in REQUIRED_KEYS:
            value = data.get(key)
            if not isinstance(value, str) or not value.strip():
                print("FAIL {}: missing or empty '{}' in frontmatter".format(path, key))
                failures += 1

    print("checked {} SKILL.md files: {} failure(s)".format(len(paths), failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PY
}

teardown_file() {
    [ -n "${FIXTURE_DIR:-}" ] && rm -rf "$FIXTURE_DIR"
}

# --- Real corpus -----------------------------------------------------------

@test "every skill frontmatter parses as YAML with name and description" {
    run python3 "$FRONTMATTER_CHECK" "$SKILLS_DIR"
    [ "$status" -eq 0 ]
    [ -z "${lines[0]:-}" ] || [[ ! "$output" == *"FAIL"* ]]
    [[ "$output" == *"failure(s)"* ]]
}

@test "corpus scan covers every skill directory" {
    # Guards the corpus test against a silently empty glob: the checked count
    # must equal the number of skill directories on disk.
    run python3 "$FRONTMATTER_CHECK" "$SKILLS_DIR"
    [ "$status" -eq 0 ]
    expected=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    [[ "$output" == *"checked $expected SKILL.md files"* ]]
    [ "$expected" -gt 0 ]
}

@test "repaired descriptions retain their trigger phrases" {
    # The five repaired skills lost their parse errors by switching to a folded
    # block scalar. Text must survive that change: trigger phrases and
    # "Not for X" guards are what skill routing depends on.
    run python3 - "$SKILLS_DIR" <<'PY'
import os
import sys

import yaml

expected = {
    "git-github-workflow": ['lifecycle: validate', '"push it"', 'Not for simple one-off git operations'],
    "goap-agent": ['intelligent planning: analyze', '"plan this out"', 'Not for simple single-step tasks'],
    "progressive-delivery": ['gated loop: reproduce the failure', '"canary this fix"', 'Not for shipping changes through git/GitHub'],
    "secrets-management": ['secret lifecycle: detect leaked secrets', '"rotate this key"', 'Not for privacy-first'],
    "skill-evaluator": ['structure checks, eval coverage review', '"evaluate this skill"', 'Not for skill-creator'],
}

skills_dir = sys.argv[1]
problems = []
for skill, phrases in sorted(expected.items()):
    path = os.path.join(skills_dir, skill, "SKILL.md")
    with open(path, encoding="utf-8") as handle:
        data = yaml.safe_load(handle.read().split("---", 2)[1])
    description = data.get("description") or ""
    for phrase in phrases:
        if phrase not in description:
            problems.append("{}: missing {!r}".format(skill, phrase))
if problems:
    for problem in problems:
        print("FAIL " + problem)
    sys.exit(1)
print("trigger phrases preserved in {} descriptions".format(len(expected)))
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"trigger phrases preserved"* ]]
}

# --- Fixtures: prove the checker fails on each historical breakage ---------

@test "flags a plain scalar description containing a colon-space" {
    mkdir -p "$FIXTURE_DIR/plain/skill-plain"
    cat > "$FIXTURE_DIR/plain/skill-plain/SKILL.md" <<'MD'
---
name: skill-plain
description: Orchestrates the lifecycle: validate then commit.
license: MIT
---

# Skill Plain
MD
    run python3 "$FRONTMATTER_CHECK" "$FIXTURE_DIR/plain"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skill-plain"* ]]
    [[ "$output" == *"unparseable YAML frontmatter"* ]]
}

@test "flags a double-quoted description with unescaped inner quotes" {
    mkdir -p "$FIXTURE_DIR/quoted/skill-quoted"
    cat > "$FIXTURE_DIR/quoted/skill-quoted/SKILL.md" <<'MD'
---
name: skill-quoted
description: "Use when they just say "evaluate this skill" or "check it"."
license: MIT
---

# Skill Quoted
MD
    run python3 "$FRONTMATTER_CHECK" "$FIXTURE_DIR/quoted"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skill-quoted"* ]]
}

@test "accepts a folded block scalar and keeps the description text intact" {
    mkdir -p "$FIXTURE_DIR/blocked/skill-blocked"
    cat > "$FIXTURE_DIR/blocked/skill-blocked/SKILL.md" <<'MD'
---
name: skill-blocked
description: >-
  Orchestrates the lifecycle: validate then commit. Use when they just say
  "ship it". Not for one-off edits.
license: MIT
---

# Skill Blocked
MD
    run python3 "$FRONTMATTER_CHECK" "$FIXTURE_DIR/blocked"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 failure(s)"* ]]

    run python3 - "$FIXTURE_DIR/blocked/skill-blocked/SKILL.md" <<'PY'
import sys

import yaml

with open(sys.argv[1], encoding="utf-8") as handle:
    description = yaml.safe_load(handle.read().split("---", 2)[1])["description"]
expected = ('Orchestrates the lifecycle: validate then commit. '
            'Use when they just say "ship it". Not for one-off edits.')
if description != expected:
    print("FAIL folded text changed: {!r}".format(description))
    sys.exit(1)
print("folded description round-trips")
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *"folded description round-trips"* ]]
}

@test "flags a missing or empty name and description" {
    mkdir -p "$FIXTURE_DIR/empty/skill-empty"
    cat > "$FIXTURE_DIR/empty/skill-empty/SKILL.md" <<'MD'
---
name: skill-empty
description: "   "
license: MIT
---

# Skill Empty
MD
    run python3 "$FRONTMATTER_CHECK" "$FIXTURE_DIR/empty"
    [ "$status" -eq 1 ]
    [[ "$output" == *"empty 'description'"* ]]

    mkdir -p "$FIXTURE_DIR/noname/skill-noname"
    cat > "$FIXTURE_DIR/noname/skill-noname/SKILL.md" <<'MD'
---
description: A skill with no name field.
license: MIT
---

# Skill Noname
MD
    run python3 "$FRONTMATTER_CHECK" "$FIXTURE_DIR/noname"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty 'name'"* ]]
}

@test "flags frontmatter without delimiters and an empty skills dir" {
    mkdir -p "$FIXTURE_DIR/bare/skill-bare"
    printf '# Skill Bare\n\nNo frontmatter here.\n' > "$FIXTURE_DIR/bare/skill-bare/SKILL.md"
    run python3 "$FRONTMATTER_CHECK" "$FIXTURE_DIR/bare"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing YAML frontmatter delimiters"* ]]

    mkdir -p "$FIXTURE_DIR/void"
    run python3 "$FRONTMATTER_CHECK" "$FIXTURE_DIR/void"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no SKILL.md files found"* ]]
}
