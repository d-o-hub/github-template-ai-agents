# Skills - Authoring Guide

> Reference doc - not loaded by default.

## Canonical Location

All skills live in `.agents/skills/` (the canonical source).
Claude Code and Qwen Code use symlinks; Gemini CLI and OpenCode read directly:

```text
.agents/skills/<name>/          <- CANONICAL (all agents read from here)
.claude/skills/<name>           -> symlink -> ../../.agents/skills/<name>
.qwen/skills/<name>             -> symlink -> ../../.agents/skills/<name>
```

Run `./scripts/setup-skills.sh` after cloning to create symlinks
for Claude Code and Qwen Code.
Run `./scripts/validate-skills.sh` to verify integrity.

## Why .agents/ as Canonical?

`.claude/` is Claude Code-specific. `.agents/` is tool-agnostic -
it works when you
add Gemini CLI, OpenCode, Codex, or any future harness without moving
files.

## Progressive Disclosure

Skills prevent instruction budget exhaustion: a skill's `SKILL.md` is loaded only
when the agent decides it is needed. Do not pre-load all skills at session start.

## Directory Structure

```text
.agents/skills/
+-- skill-name/
    +-- SKILL.md          # Primary instructions (<= 250 lines)
    +-- references/        # Detailed docs linked from SKILL.md
    +-- scripts/          # Executable scripts the agent can run directly
    +-- assets/           # Templates, examples
```

## SKILL.md Template

```markdown
---
# --- spec fields (agentskills.io) ---
name: skill-name
description: One-line description saying what it does and when to use it.
license: MIT
# --- template-local fields (see Frontmatter Field Policy) ---
category: workflow
version: "0.2.10"
---

# Skill Name

Brief description.

## When to Use
Activate when: [specific triggers]

## Rationalizations
| Rationalization | Reality |
|-----------------|---------|
| "Excuse goes here" | "Rebuttal goes here" |

## Red Flags
- [ ] List of early warning behaviors that signal cutting corners

## Reference Files
- `references/guide.md` - [when to read]
- `scripts/run.sh` - [what it does]

## Examples
[Concrete usage]
```

The table in the next section is the authority on fields and their status; the
example above only illustrates the shape.

## Frontmatter Field Policy

This section is authoritative for the template. The two tables below are the
single source of truth for which top-level `SKILL.md` frontmatter keys are
permitted and how each is classified.
`tests/test-skill-frontmatter-policy.bats` parses these tables and fails when a
skill uses a key that is not listed here, so a new non-spec key cannot land
without a policy entry.

Status vocabulary:

| Status | Meaning |
| --- | --- |
| REQUIRED | Validation fails without it. |
| RECOMMENDED | Expected on every skill; absence is a warning, not a failure. |
| OPTIONAL | May be absent. No validator reads it. |

### Spec fields

The Agent Skills specification defines exactly six top-level frontmatter fields
and no others: <https://agentskills.io/specification>.

| Key | Source | Status | Constraint and intent |
| --- | --- | --- | --- |
| `name` | spec | REQUIRED | 1-64 chars, `a-z0-9-` only, no leading, trailing, or doubled hyphen, and must match the parent directory name. |
| `description` | spec | REQUIRED | 1-1024 chars. Must say what the skill does **and** when to use it, with the keywords that drive routing. |
| `license` | spec | RECOMMENDED | Short license name or a reference to a bundled license file. |
| `compatibility` | spec | OPTIONAL | Max 500 chars. Add only for real environment requirements (tools, packages, network). |
| `metadata` | spec | OPTIONAL | String-to-string map for anything the spec does not define. This is where non-spec keys belong. |
| `allowed-tools` | spec | OPTIONAL | Space-separated pre-approved tools. Experimental; support varies by client. |

Keys nested inside `metadata` are unconstrained by the spec. The spec's own
example puts a version under `metadata`, not at top level.

### Template-local keys

These five keys are **not** part of the specification. They are a local
convention of this template, kept at top level because this repository's own
generators, validators, and docs match them as top-level fields.

| Key | Source | Status | Why it exists and who reads it |
| --- | --- | --- | --- |
| `category` | template-local | REQUIRED | Groups skills for the catalog. Hard-enforced: `scripts/validate-skills.sh` fails a skill whose frontmatter has no `category`. |
| `version` | template-local | RECOMMENDED | Release stamp for the skill set. Warn-only: `scripts/lib/skill-validation.sh` warns when it is missing. See the `version` policy below. |
| `template_version` | template-local | OPTIONAL | Minimum template version a skill was authored against. Derived from the root `VERSION` file. See the `template_version` policy below. |
| `changelog` | template-local | OPTIONAL | Per-skill change list (a sequence of version-to-note mappings). Two skills use it. |
| `trigger` | template-local | OPTIONAL | Legacy free-text routing hint. One skill uses it. Prefer folding the text into `description`, which is what clients actually route on. |

This resolves the ambiguity raised in issue #941: `template_version` is
**OPTIONAL**. No validator requires it, and adopters do not need to add it to new
skills.

### Static validator input syntax

`scripts/lib/skill_frontmatter.py` checks the delimited frontmatter with a
dependency-free **bounded YAML reader**, not a complete YAML implementation.
Use block mappings/sequences, plain or quoted single-line strings, and literal
or folded block scalars. Quote numeric/boolean-looking text values. The reader
rejects aliases, tags, directives, flow collections other than empty `{}`/`[]`,
and multiline quoted strings; rewrite those forms as block syntax. Metadata
keys and values must be strings, and `compatibility` is a string, not a tools map.

Validation enforces name/directory agreement, field types and description
length; required authoring sections and at least three eval cases fail the gate.
Add a new top-level field to this policy **and** the reader's field allowlist.
These checks validate structure and inputs; they do not prove skill behavior.

### version policy

`version` is a **release stamp, not per-skill semver**. Evidence: 43 of 54
skills carry the identical value `0.2.10`, which is the template's release
series rather than 43 independent version lines.

- Bump it when the skill set ships, not when a single skill's prose changes.
- A skill lagging behind the set is normal and legal.
  `agentic-abstention` sits at `0.1.0` while the set is at `0.2.10`; that is
  not a defect and must not be force-bumped to quiet a diff.
- There is no official per-skill semver to conform to. The Skills API assigns
  immutable `skver_...` versions server-side on upload, and catalog-level
  versions live in a bundle manifest, not in skill frontmatter
  (<https://platform.claude.com/docs/en/api/beta/skills/versions>).

### template_version policy

`template_version` records which template generation a skill was authored
against, and is **OPTIONAL**.

Its reference value is the root `VERSION` file, which `AGENTS.md` defines as the
single source of truth for version. In a **template** repository `VERSION` is
intentionally pinned to `0.0.0` (see `agents-docs/VERSION.md`), so a staleness
comparison against `VERSION` can never fire here. `scripts/lib/skill-validation.sh`
therefore skips that comparison deliberately and visibly rather than leaving
dead code in place. In a **consumer** repository, once `VERSION` holds a real
version, the comparison is live and warns when a skill lags more than one minor
behind.

### Compatibility consequence

Local harnesses are lenient by design. The spec's integration guidance is
warn-don't-block: warn on odd fields but still load the skill, and skip it only
when `description` is missing or the YAML is unparseable
(<https://agentskills.io/integrate-skills>). So the template-local keys above
load fine in Claude Code, Qwen Code, Gemini CLI, and OpenCode.

Strict upload paths are not lenient. Anthropic's claude.ai skill upload and the
Skills API reject unknown top-level keys as a hard error: "Unexpected key(s) in
SKILL.md frontmatter. Allowed properties are: allowed-tools, compatibility,
description, license, metadata, name"
(<https://code.claude.com/docs/en/skills>).

Consequence: a skill copied verbatim out of `.agents/skills/` **cannot** be
uploaded to claude.ai as-is. Any packaging step must transform the
template-local keys first:

| Template-local key | Packaged form |
| --- | --- |
| `category` | Nest as `metadata.category` |
| `version` | Nest as `metadata.version` |
| `template_version` | Nest as `metadata.template_version` |
| `changelog` | Drop, or move to the bundle manifest |
| `trigger` | Drop; `description` already carries the trigger text |

This template does not ship that packaging step yet, so the mapping table is
the contract an adopter must implement. Note the precedent it mirrors: Claude
Code keeps its catalog version in `plugin.json` ("users only receive updates when
you bump this field") and its collection version in `marketplace.json`, not in
each skill's frontmatter (<https://code.claude.com/docs/en/plugins-reference>).

## Rules

- `SKILL.md` <= 250 lines - detailed content in `references/`
- Bundle executable scripts when they add reusable verification; scripts are optional
- Cite sources as `filepath:line` so the parent agent can find context
- Do not duplicate content already in `AGENTS.md`
- Never install skills from untrusted registries - read them first
- Add a new frontmatter key only together with a policy entry in this section

## Agent vs Skill

| Use a Skill | Use a Sub-Agent |
| --- | --- |
| Reusable reference knowledge | Complex multi-step execution |
| Main agent executes with guidance | Needs isolated context window |
| No context isolation needed | Different tool access than parent |
