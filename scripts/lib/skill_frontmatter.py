"""Dependency-free reader for the template's bounded YAML frontmatter subset.

Supports block mappings (including quoted string keys), indented/indentless
sequences, plain/quoted strings and literal/folded scalars. This is NOT a
complete YAML parser: aliases, tags, directives, flow
collections (except empty {} / []) and multiline quoted strings are rejected
explicitly. Unsupported YAML must not silently pass as regex key presence.
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

MAX_NAME_CHARS = 64
MAX_DESCRIPTION_CHARS = 1024
MAX_COMPATIBILITY_CHARS = 500
NAME_PATTERN = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
FRONTMATTER_FIELDS = frozenset({
    "name", "description", "license", "compatibility", "metadata", "allowed-tools",
    "category", "version", "template_version", "changelog", "trigger",
})
MAPPING_ENTRY = re.compile(
    r'''((?:"(?:[^"\\]|\\.)*"|'(?:[^']|'')*')|[A-Za-z0-9_.-]+):(?:[ \t]+(.*))?'''
)


class FrontmatterError(ValueError):
    """Malformed or unsupported frontmatter syntax."""


def _scalar(raw: str):
    raw = raw.strip()
    if raw.startswith('"'):
        # JSON string escapes are a safe, explicit subset of YAML escapes.
        try:
            value, end = json.JSONDecoder().raw_decode(raw)
        except ValueError as exc:
            raise FrontmatterError("invalid double-quoted scalar; use a block scalar") from exc
        remainder = raw[end:].strip()
        if remainder and not re.fullmatch(r"[ \t]+#.*", raw[end:]):
            raise FrontmatterError("unexpected text after quoted scalar")
        return value
    if raw.startswith("'"):
        match = re.fullmatch(r"'((?:[^']|'')*)'(?:\s+#.*)?", raw)
        if not match:
            raise FrontmatterError("invalid single-quoted scalar; use a block scalar")
        return match[1].replace("''", "'")
    raw = "" if raw.startswith("#") else re.split(r"\s+#", raw, maxsplit=1)[0].rstrip()
    if raw in ("{}", "[]"):
        return json.loads(raw)
    if raw.startswith(tuple("[{&*!%@`|>")) or re.search(r":(?:\s|$)", raw):
        raise FrontmatterError("unsupported or malformed scalar; quote it or use a block scalar")
    if raw.lower() in ("", "null", "~"):
        return None
    if raw.lower() in ("true", "false", "yes", "no", "on", "off"):
        return raw.lower() in ("true", "yes", "on")
    if re.fullmatch(r"[-+]?(?:0[xX][0-9a-fA-F]+|0[oO][0-7]+|0[bB][01]+|\.(?:inf|nan))", raw, re.IGNORECASE):
        raise FrontmatterError("non-string numeric scalar; quote it if text is intended")
    if re.fullmatch(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?", raw):
        return float(raw)
    if raw in ("-", "?") or raw.startswith(("- ", "? ", ": ")):
        raise FrontmatterError("unexpected YAML collection indicator")
    return raw


class _Reader:
    def __init__(self, lines: list[str]):
        self.lines = lines
        self.index = 0

    def skip(self):
        while self.index < len(self.lines):
            line = self.lines[self.index]
            if line.strip() and not line.lstrip().startswith("#"):
                break
            self.index += 1

    @staticmethod
    def indent(line: str) -> int:
        prefix = line[:len(line) - len(line.lstrip())]
        if "\t" in prefix:
            raise FrontmatterError("tabs are not supported for YAML indentation")
        return len(prefix)

    def value(self, raw: str, parent_indent: int):
        marker = re.split(r"\s+#", raw.strip(), maxsplit=1)[0].rstrip()
        if marker.startswith("#"):
            marker = ""
        if marker in ("|", "|-", "|+", ">", ">-", ">+"):
            return self.block_scalar(marker, parent_indent)
        before_skip = self.index
        self.skip()
        blank_count = sum(not line.strip() for line in self.lines[before_skip:self.index])
        if not marker:
            if self.index < len(self.lines) and self.indent(self.lines[self.index]) > parent_indent:
                return self.collection(self.indent(self.lines[self.index]))
            if (self.index < len(self.lines)
                    and self.indent(self.lines[self.index]) == parent_indent
                    and self.lines[self.index][parent_indent:].startswith("- ")):
                return self.collection(parent_indent, indentless=True)
            return None
        value = raw.strip()
        # Plain multiline scalars are folded. Quoted multiline scalars are
        # deliberately unsupported to avoid silently misinterpreting escapes.
        while self.index < len(self.lines) and self.indent(self.lines[self.index]) > parent_indent:
            if marker.startswith(("'", '"')):
                raise FrontmatterError("unexpected continuation; use a block scalar")
            # A comment terminates a plain scalar; following indented text is
            # not a continuation. Do not silently discard it while folding.
            if re.search(r"\s+#", raw) or any(
                line.lstrip().startswith("#") for line in self.lines[before_skip:self.index]
            ):
                raise FrontmatterError("unexpected continuation after a scalar comment")
            continuation = self.lines[self.index].strip()
            value += ("\n" * blank_count if blank_count else " ") + continuation
            raw = continuation
            self.index += 1
            before_skip = self.index
            self.skip()
            blank_count = sum(not line.strip() for line in self.lines[before_skip:self.index])
        # Resolve scalar type once, after folding the entire token. For example
        # 'Release\n  2026' and 'yes\n  Release' are strings, not per-line values.
        return _scalar(value)

    def block_scalar(self, marker: str, parent_indent: int) -> str:
        block = []
        while self.index < len(self.lines):
            line = self.lines[self.index]
            if line.strip() and self.indent(line) <= parent_indent:
                break
            block.append(line)
            self.index += 1
        nonblank = [line for line in block if line.strip()]
        indent = (self.indent(nonblank[0]) if nonblank else
                  max((self.indent(line) for line in block), default=parent_indent + 1))
        if any(self.indent(line) < indent for line in nonblank):
            raise FrontmatterError("inconsistent block scalar indentation")
        if nonblank:
            first_content = next(idx for idx, line in enumerate(block) if line.strip())
            if any(self.indent(line) > indent for line in block[:first_content]):
                raise FrontmatterError("leading block whitespace exceeds content indentation")
        # Spaces beyond the content indentation are scalar data, including on
        # otherwise blank lines. Dropping them changes descriptions and bounds.
        stripped = [line[indent:] for line in block]
        value = ""
        last_nonblank = ""
        for idx, line in enumerate(stripped):
            value += line
            if line:
                last_nonblank = line
            following = stripped[idx + 1] if idx + 1 < len(stripped) else None
            fold = (marker.startswith(">") and line and following
                    and not line.startswith(" ") and not following.startswith(" "))
            # Folded paragraphs have one fewer newline than literal scalars.
            after_paragraph = (marker.startswith(">") and not line and following
                               and not following.startswith(" ")
                               and last_nonblank and not last_nonblank.startswith(" "))
            value += " " if fold else "" if after_paragraph else "\n"
        if marker.endswith("-"):
            return value.rstrip("\n")
        if marker.endswith("+"):
            return value
        return value.rstrip("\n") + "\n" if nonblank else ""

    def pair(self, text: str, indent: int, mapping: dict):
        match = MAPPING_ENTRY.fullmatch(text)
        if not match:
            raise FrontmatterError(f"unsupported mapping entry: {text!r}")
        key, raw = _scalar(match[1]), match[2] or ""
        if not isinstance(key, str):
            raise FrontmatterError("mapping keys must be strings; quote numeric or boolean keys")
        if key in mapping:
            raise FrontmatterError(f"duplicate field '{key}'")
        mapping[key] = self.value(raw, indent)

    def collection(self, indent: int, *, indentless: bool = False):
        self.skip()
        sequence = self.lines[self.index][indent:].startswith("- ")
        result = [] if sequence else {}
        while self.index < len(self.lines):
            self.skip()
            if self.index == len(self.lines):
                break
            line = self.lines[self.index]
            current_indent = self.indent(line)
            if current_indent < indent:
                break
            if current_indent != indent:
                raise FrontmatterError("unexpected mapping indentation")
            text = line[indent:]
            if sequence and indentless and not text.startswith("- "):
                break
            self.index += 1
            if sequence:
                if not text.startswith("- "):
                    raise FrontmatterError("mixed mapping and sequence")
                item = text[2:]
                if MAPPING_ENTRY.fullmatch(item):
                    mapping = {}
                    self.pair(item, indent + 2, mapping)
                    result.append(mapping)
                else:
                    result.append(self.value(item, indent))
            else:
                self.pair(text, indent, result)
        return result


def read_frontmatter(text: str) -> tuple[dict, str]:
    lines = text.splitlines()
    if not lines or lines[0] != "---":
        raise FrontmatterError("Must start with '---'")
    try:
        end = lines.index("---", 1)
    except ValueError as exc:
        raise FrontmatterError("Missing closing frontmatter '---'") from exc
    reader = _Reader(lines[1:end])
    reader.skip()
    if reader.index == len(reader.lines):
        return {}, "\n".join(lines[end + 1:])
    data = reader.collection(0)
    if not isinstance(data, dict):
        raise FrontmatterError("frontmatter must be a mapping")
    return data, "\n".join(lines[end + 1:])


def validate_frontmatter(data: dict, parent_name: str) -> list[str]:
    issues = []
    for key in sorted(set(data) - FRONTMATTER_FIELDS):
        issues.append(f"Undocumented frontmatter field '{key}'")
    for key in ("name", "description", "category"):
        if not isinstance(data.get(key), str) or not data[key].strip():
            issues.append(f"Missing or empty '{key}:' field (must be a string)")
    name = data.get("name")
    if isinstance(name, str):
        if not 1 <= len(name) <= MAX_NAME_CHARS or not NAME_PATTERN.fullmatch(name):
            issues.append(f"name must be 1-{MAX_NAME_CHARS} lowercase letters/digits/hyphens, without edge or doubled hyphens")
        if name != parent_name:
            issues.append(f"name must match parent directory '{parent_name}'")
    description = data.get("description")
    if isinstance(description, str) and not 1 <= len(description) <= MAX_DESCRIPTION_CHARS:
        issues.append(f"description must be 1-{MAX_DESCRIPTION_CHARS} characters")
    for key in ("license", "compatibility", "allowed-tools", "version", "template_version", "trigger"):
        if key in data and (not isinstance(data[key], str) or not data[key].strip()):
            issues.append(f"'{key}' must be a non-empty string")
    compatibility = data.get("compatibility")
    if isinstance(compatibility, str) and len(compatibility) > MAX_COMPATIBILITY_CHARS:
        issues.append(f"compatibility must be at most {MAX_COMPATIBILITY_CHARS} characters")
    if "metadata" in data:
        metadata = data["metadata"]
        if not isinstance(metadata, dict) or not all(
            isinstance(k, str) and isinstance(v, str) for k, v in metadata.items()
        ):
            issues.append("metadata must be a string-to-string mapping")
    if "changelog" in data:
        changelog = data["changelog"]
        if not isinstance(changelog, list) or not all(
            isinstance(item, dict) and len(item) == 1 and all(isinstance(v, str) for v in item.values())
            for item in changelog
        ):
            issues.append("changelog must be a sequence of version-to-note mappings")
    return issues


def _validated_path(raw_path: str) -> Path:
    """Resolve a SKILL.md path beneath the caller-declared skill root."""
    root_value = os.environ.get("SKILL_FRONTMATTER_ROOT", "")
    if not root_value:
        raise FrontmatterError("SKILL_FRONTMATTER_ROOT is required")
    root = Path(root_value).resolve()
    path = Path(raw_path).resolve()
    if path.name != "SKILL.md":
        raise FrontmatterError("path must name a SKILL.md file")
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise FrontmatterError("path must stay within SKILL_FRONTMATTER_ROOT") from exc
    if not path.is_file():
        raise FrontmatterError("path must identify a regular file")
    return path


def main() -> int:
    try:
        if len(sys.argv) != 2:
            raise FrontmatterError("exactly one SKILL.md path is required")
        path = _validated_path(sys.argv[1])
        text = path.read_text(encoding="utf-8")
        data, _ = read_frontmatter(text)
        issues = validate_frontmatter(data, path.parent.name)
    except (OSError, UnicodeError, FrontmatterError, RecursionError) as exc:
        print(f"  ✗ {path.parent.name}: frontmatter: {exc}", file=sys.stderr)
        return 1
    for issue in issues:
        print(f"  ✗ {path.parent.name}: {issue}", file=sys.stderr)
    # Bounded output protocol for the shell wrapper; never evaluate file content.
    template_version = data.get("template_version", "")
    if not isinstance(template_version, str) or "\n" in template_version or ":" in template_version:
        template_version = ""
    print(f"{len(text.splitlines())}:{int('version' in data)}:{template_version}")
    return 1 if issues else 0


if __name__ == "__main__":
    sys.exit(main())
