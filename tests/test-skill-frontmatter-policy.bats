#!/usr/bin/env bats
# Policy tests: SKILL.md frontmatter keys must match the documented policy.
#
# The Agent Skills specification (https://agentskills.io/specification) allows
# exactly six top-level frontmatter fields. This template deliberately adds five
# more (version, category, template_version, changelog, trigger) as a local
# convention, which means the permitted key set lives in a document, not in the
# spec. That is drift-prone: a new non-spec key can be added to a SKILL.md with
# no signal that the policy is now wrong.
#
# agents-docs/SKILLS.md -> "Frontmatter Field Policy" is therefore the source of
# truth. The checker below parses those tables and fails when a skill uses a key
# the policy does not list, so a new non-spec key cannot land without a policy
# entry. See issue #941.

setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export SKILLS_DIR="$REPO_ROOT/.agents/skills"
    export POLICY_DOC="$REPO_ROOT/agents-docs/SKILLS.md"
    export FIXTURE_DIR="$(mktemp -d)"
    # The corpus tests and the fixture tests share one checker, so the fixture
    # tests prove the corpus test can actually fail.
    export POLICY_CHECK="$FIXTURE_DIR/check_policy.py"
    cat > "$POLICY_CHECK" <<'PY'
#!/usr/bin/env python3
"""Check SKILL.md frontmatter keys against the documented field policy.

Usage: check_policy.py <skills-dir> <policy-doc>

Prints one FAIL line per finding and exits 1 when the corpus and the policy
disagree. The policy tables in the doc ("Frontmatter Field Policy") declare
each key, whether the specification defines it ("spec"), and its status
(REQUIRED / RECOMMENDED / OPTIONAL).
"""
import glob
import os
import re
import sys

import yaml

POLICY_HEADING = "Frontmatter Field Policy"
SPEC_FIELDS = ("allowed-tools", "compatibility", "description", "license", "metadata", "name")
STATUS_LABELS = ("REQUIRED", "RECOMMENDED", "OPTIONAL")
TEMPLATE_LOCAL_EXPECTED = ("category", "changelog", "template_version", "trigger", "version")
ISSUE_941_KEY = "template_version"

ROW_RE = re.compile(
    r"^\|\s*`([A-Za-z0-9_.-]+)`\s*\|\s*(spec|template-local)\s*\|\s*"
    r"([A-Z]+)\s*\|"
)


def cells(line):
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def policy_rows(doc_text):
    """Parse the policy tables. Returns (rows, problems).

    A table qualifies as a policy table when its header row is
    | Key | Source | Status | ... |. Every body row of such a table must
    parse, so a typo in a policy row fails loudly instead of silently dropping
    the key from the permitted set.
    """
    lines = doc_text.splitlines()
    start = None
    for index, line in enumerate(lines):
        if start is None and line.startswith("## ") and line[3:].strip() == POLICY_HEADING:
            start = index + 1
            continue
        if start is not None and line.startswith("## "):
            lines = lines[start:index]
            break
    else:
        if start is None:
            return [], ["policy doc has no '## {}' section".format(POLICY_HEADING)]
        lines = lines[start:]

    rows = []
    problems = []
    in_policy_table = False
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("|"):
            in_policy_table = False
            continue
        if re.match(r"^\|[\s|:-]+\|?$", stripped):
            continue  # table separator row
        header = cells(line)
        if len(header) >= 3 and header[0] == "Key" and header[1] == "Source" and header[2] == "Status":
            in_policy_table = True
            continue
        match = ROW_RE.match(stripped)
        if match:
            key, source, status = match.groups()
            if status not in STATUS_LABELS:
                problems.append("key '{}' has status '{}' outside {}".format(key, status, list(STATUS_LABELS)))
            rows.append((key, source, status))
            continue
        if in_policy_table:
            problems.append("unparseable policy row: " + stripped)
    return rows, problems


def frontmatter_block(text):
    """Return the raw frontmatter text, or None when delimiters are absent."""
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    return parts[1] if len(parts) > 2 else None


def main(argv):
    if len(argv) != 3:
        print("usage: check_policy.py <skills-dir> <policy-doc>", file=sys.stderr)
        return 2
    skills_dir, policy_doc = argv[1], argv[2]
    failures = 0

    if not os.path.isfile(policy_doc):
        print("FAIL policy doc not found: " + policy_doc)
        return 1
    with open(policy_doc, encoding="utf-8") as handle:
        rows, problems = policy_rows(handle.read())
    for problem in problems:
        print("FAIL " + problem)
        failures += 1
    if not rows:
        print("FAIL policy doc declares no frontmatter fields")
        return 1

    policy = {}
    for key, source, status in rows:
        if key in policy and policy[key] != (source, status):
            print("FAIL policy declares '{}' twice with conflicting entries".format(key))
            failures += 1
        policy[key] = (source, status)

    spec_declared = tuple(sorted(k for k, (s, _) in policy.items() if s == "spec"))
    if spec_declared != tuple(sorted(SPEC_FIELDS)):
        print("FAIL policy labels these keys as spec: {} (specification allows {})".format(
            list(spec_declared), list(SPEC_FIELDS)))
        failures += 1
    local_declared = tuple(sorted(k for k, (s, _) in policy.items() if s == "template-local"))
    if local_declared != tuple(sorted(TEMPLATE_LOCAL_EXPECTED)):
        print("FAIL policy labels these keys as template-local: {} (expected {})".format(
            list(local_declared), list(TEMPLATE_LOCAL_EXPECTED)))
        failures += 1

    paths = sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md")))
    if not paths:
        print("FAIL no SKILL.md files found under " + skills_dir)
        return 1

    required = {k for k, (_, status) in policy.items() if status == "REQUIRED"}
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
            print("FAIL {}: unparseable YAML frontmatter: {}".format(
                path, str(exc).splitlines()[0]))
            failures += 1
            continue
        if not isinstance(data, dict):
            print("FAIL {}: frontmatter is {}, expected a mapping".format(path, type(data).__name__))
            failures += 1
            continue
        for key in sorted(data):
            if key not in policy:
                print("FAIL {}: top-level key '{}' has no entry in the {}".format(
                    path, key, POLICY_HEADING))
                failures += 1
        for key in sorted(required - set(data)):
            print("FAIL {}: policy marks '{}' REQUIRED but frontmatter omits it".format(path, key))
            failures += 1

    print("checked {} skills against {} policy keys ({} spec, {} template-local): {} failure(s)".format(
        len(paths), len(policy), len(spec_declared), len(local_declared), failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
PY
}

teardown_file() {
    [ -n "${FIXTURE_DIR:-}" ] && rm -rf "$FIXTURE_DIR"
}

# --- Real corpus: policy and skills must agree ------------------------------

@test "every skill frontmatter key is permitted by the policy doc" {
    run python3 "$POLICY_CHECK" "$SKILLS_DIR" "$POLICY_DOC"
    [ "$status" -eq 0 ]
    [[ ! "$output" == *"FAIL"* ]]
    [[ "$output" == *"0 failure(s)"* ]]
}

@test "corpus scan covers every skill directory" {
    # Guards the corpus test against a silently empty glob: the checked count
    # must equal the number of skill directories on disk.
    run python3 "$POLICY_CHECK" "$SKILLS_DIR" "$POLICY_DOC"
    [ "$status" -eq 0 ]
    expected=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
    [[ "$output" == *"checked $expected skills against"* ]]
    [ "$expected" -gt 0 ]
}

@test "policy doc lists the six spec fields and the five template-local keys" {
    # The specification is external, so the test pins its own copy of the six
    # allowed fields. If the spec ever changes, this test is where the
    # divergence becomes visible.
    run python3 "$POLICY_CHECK" "$SKILLS_DIR" "$POLICY_DOC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"6 spec, 5 template-local"* ]]
}

@test "issue #941 is settled: template_version is OPTIONAL, category is REQUIRED" {
    # The open question in issue #941 was whether template_version is required
    # or optional. The policy answers OPTIONAL; category stays REQUIRED because
    # scripts/validate-skills.sh hard-fails without it.
    run grep -E '^\| `(template_version|category)` \| template-local \| (REQUIRED|OPTIONAL) \|' "$POLICY_DOC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"| \`category\` | template-local | REQUIRED |"* ]]
    [[ "$output" == *"| \`template_version\` | template-local | OPTIONAL |"* ]]
}

@test "SKILL_TEMPLATE.md frontmatter only uses keys the policy permits" {
    # The scaffolding template must not teach a key the policy rejects.
    run python3 - "$REPO_ROOT/.agents/skills/SKILL_TEMPLATE.md" "$POLICY_CHECK" <<'PY'
import os
import subprocess
import sys
import tempfile

import yaml

skill_md, checker = sys.argv[1], sys.argv[2]
with open(skill_md, encoding="utf-8") as handle:
    data = yaml.safe_load(handle.read().split("---", 2)[1])

with tempfile.TemporaryDirectory() as tmp:
    target = os.path.join(tmp, "skill-template")
    os.makedirs(target)
    with open(os.path.join(target, "SKILL.md"), "w", encoding="utf-8") as handle:
        handle.write("---\nname: skill-template\n{}\n---\n\n# Skill Template\n".format(
            yaml.safe_dump(data, sort_keys=True)))
    result = subprocess.run(
        [sys.executable, checker, tmp, os.path.join(os.path.dirname(os.path.dirname(
            os.path.dirname(skill_md))), "agents-docs", "SKILLS.md")],
        capture_output=True, text=True)
    print(result.stdout.strip())
    sys.exit(result.returncode)
PY
    [ "$status" -eq 0 ]
    [[ ! "$output" == *"FAIL"* ]]
}

# --- Fixtures: prove the checker fails on a new non-spec key ---------------

@test "flags a new non-spec key that has no policy entry" {
    mkdir -p "$FIXTURE_DIR/newkey/skill-newkey"
    cat > "$FIXTURE_DIR/newkey/skill-newkey/SKILL.md" <<'MD'
---
name: skill-newkey
description: A skill that invents a top-level key.
license: MIT
category: workflow
version: "0.1.0"
maintainer: someone
---

# Skill Newkey
MD
    run python3 "$POLICY_CHECK" "$FIXTURE_DIR/newkey" "$POLICY_DOC"
    [ "$status" -eq 1 ]
    [[ "$output" == *"skill-newkey"* ]]
    [[ "$output" == *"top-level key 'maintainer' has no entry"* ]]
    [[ "$output" == *"failure(s)"* ]]
}

@test "flags a policy row whose status is outside the allowed vocabulary" {
    cp "$POLICY_DOC" "$FIXTURE_DIR/badstatus.md"
    sed -i 's/| `version` | template-local | RECOMMENDED |/| `version` | template-local | MANDATORY |/' \
        "$FIXTURE_DIR/badstatus.md"
    run python3 "$POLICY_CHECK" "$SKILLS_DIR" "$FIXTURE_DIR/badstatus.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"MANDATORY"* ]]
}

@test "accepts a fixture skill that uses only permitted keys" {
    mkdir -p "$FIXTURE_DIR/clean/skill-clean"
    cat > "$FIXTURE_DIR/clean/skill-clean/SKILL.md" <<'MD'
---
name: skill-clean
description: A skill that only uses permitted keys.
license: MIT
compatibility: Requires git and jq
allowed-tools: Read Bash(git:*)
metadata:
  author: example-org
category: tool
version: "0.1.0"
template_version: "0.2"
changelog:
- 0.1.0: initial
trigger: after a task
---

# Skill Clean
MD
    run python3 "$POLICY_CHECK" "$FIXTURE_DIR/clean" "$POLICY_DOC"
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 failure(s)"* ]]
    # Policy acceptance must also exercise the actual frontmatter reader. The
    # fixture uses YAML's valid indentless changelog sequence.
    run python3 "$REPO_ROOT/scripts/lib/skill_frontmatter.py" "$FIXTURE_DIR/clean/skill-clean/SKILL.md"
    [ "$status" -eq 0 ]
}

@test "flags a skill missing a key the policy marks REQUIRED" {
    mkdir -p "$FIXTURE_DIR/nocat/skill-nocat"
    cat > "$FIXTURE_DIR/nocat/skill-nocat/SKILL.md" <<'MD'
---
name: skill-nocat
description: A skill with no category.
license: MIT
version: "0.1.0"
---

# Skill Nocat
MD
    run python3 "$POLICY_CHECK" "$FIXTURE_DIR/nocat" "$POLICY_DOC"
    [ "$status" -eq 1 ]
    [[ "$output" == *"policy marks 'category' REQUIRED"* ]]
}

@test "flags a missing policy doc, an empty skills dir, and a missing policy section" {
    run python3 "$POLICY_CHECK" "$SKILLS_DIR" "$FIXTURE_DIR/does-not-exist.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"policy doc not found"* ]]

    mkdir -p "$FIXTURE_DIR/void"
    run python3 "$POLICY_CHECK" "$FIXTURE_DIR/void" "$POLICY_DOC"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no SKILL.md files found"* ]]

    printf '# Skills\n\nNo policy section here.\n' > "$FIXTURE_DIR/nosection.md"
    run python3 "$POLICY_CHECK" "$SKILLS_DIR" "$FIXTURE_DIR/nosection.md"
    [ "$status" -eq 1 ]
    [[ "$output" == *"no '## Frontmatter Field Policy' section"* ]]
}

# --- Dead-code guard: the template_version staleness check -----------------

@test "template_version staleness check is deliberately skipped at the template pin" {
    # VERSION is pinned to 0.0.0 in a template repository, so the minor-version
    # comparison is meaningless here. It must be skipped visibly, not silently,
    # so a reader does not mistake the guard for broken code.
    local sandbox="$FIXTURE_DIR/pinned"
    mkdir -p "$sandbox/scripts/lib" "$sandbox/.agents/skills/tv-pinned"
    cp "$REPO_ROOT/scripts/lib/skill-validation.sh" "$sandbox/scripts/lib/"
    cp "$REPO_ROOT/scripts/lib/skill_frontmatter.py" "$sandbox/scripts/lib/"
    printf '0.0.0\n' > "$sandbox/VERSION"
    cat > "$sandbox/.agents/skills/tv-pinned/SKILL.md" <<'MD'
---
name: tv-pinned
category: testing
description: Fixture skill carrying a template_version.
version: "0.1.0"
template_version: 0.8.0
---

# TV Pinned

## Rationalizations
| Excuse | Reality |
| --- | --- |
| "It is fine" | "It is not" |

## Red Flags
- [ ] stale template_version
MD
    # REPO_ROOT must be overridden explicitly: setup_file exports the real repo
    # root, and the lib resolves VERSION relative to it.
    run bash -c 'cd "$1" && export REPO_ROOT="$1" && source scripts/lib/skill-validation.sh && validate_skill_file .agents/skills/tv-pinned/SKILL.md' _ "$sandbox"
    [ "$status" -eq 0 ]
    [[ "$output" == *"template_version staleness check skipped"* ]]
    [[ "$output" == *"template pin 0.0.0"* ]]
    [[ ! "$output" == *">1 minor behind"* ]]
}

@test "template_version staleness check still runs against a real VERSION" {
    # Proves the guard is a deliberate skip, not dead code: with a real VERSION
    # the same skill set warns again.
    local sandbox="$FIXTURE_DIR/consumer"
    mkdir -p "$sandbox/scripts/lib" "$sandbox/.agents/skills/tv-consumer"
    cp "$REPO_ROOT/scripts/lib/skill-validation.sh" "$sandbox/scripts/lib/"
    cp "$REPO_ROOT/scripts/lib/skill_frontmatter.py" "$sandbox/scripts/lib/"
    printf '0.10.0\n' > "$sandbox/VERSION"
    cat > "$sandbox/.agents/skills/tv-consumer/SKILL.md" <<'MD'
---
name: tv-consumer
category: testing
description: Fixture skill carrying a template_version.
version: "0.1.0"
template_version: 0.8.0
---

# TV Consumer

## Rationalizations
| Excuse | Reality |
| --- | --- |
| "It is fine" | "It is not" |

## Red Flags
- [ ] stale template_version
MD
    run bash -c 'cd "$1" && export REPO_ROOT="$1" && source scripts/lib/skill-validation.sh && validate_skill_file .agents/skills/tv-consumer/SKILL.md' _ "$sandbox"
    [ "$status" -eq 0 ]
    [[ "$output" == *"is >1 minor behind current 0.10.0"* ]]
    [[ ! "$output" == *"staleness check skipped"* ]]
}
