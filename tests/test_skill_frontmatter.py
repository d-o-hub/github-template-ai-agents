"""Test the bounded frontmatter reader, independently of optional PyYAML."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from lib.skill_frontmatter import (
    FrontmatterError, read_frontmatter, validate_frontmatter,
)


def read(fields, body=""):
    return read_frontmatter(f"---\n{fields}\n---\n{body}")


def valid_fields():
    return {"name": "test-skill", "description": "Use when testing", "category": "testing"}


@pytest.mark.parametrize("name", ["", "Test-skill", "-test-skill", "test-skill-", "test--skill", "test_skill", "a" * 65, "test skill"])
def test_name_constraints(name):
    fields = valid_fields()
    fields["name"] = name
    assert validate_frontmatter(fields, name)


@pytest.mark.parametrize("name", ["a", "a" * 64, "test-skill", "test-1"])
def test_name_boundaries(name):
    fields = valid_fields()
    fields["name"] = name
    assert not validate_frontmatter(fields, name)


def test_name_must_match_parent():
    assert any("parent directory" in issue for issue in validate_frontmatter(valid_fields(), "other"))


@pytest.mark.parametrize("size,valid", [(0, False), (1, True), (1024, True), (1025, False)])
def test_description_length(size, valid):
    fields = valid_fields()
    fields["description"] = "é" * size
    assert (not validate_frontmatter(fields, "test-skill")) == valid


@pytest.mark.parametrize("field,value", [
    ("description", " "), ("description", None), ("name", True), ("category", ""),
    ("category", []), ("license", False), ("allowed-tools", []),
    ("compatibility", {"tools": ["bash"]}), ("compatibility", "a" * 501),
    ("metadata", {"version": 1}), ("metadata", {"triggers": ["test"]}),
    ("changelog", "not a list"), ("changelog", [{"1.0.0": False}]),
])
def test_field_types_and_bounds(field, value):
    fields = valid_fields()
    fields[field] = value
    assert validate_frontmatter(fields, "test-skill")


def test_unknown_keys_are_not_silently_accepted():
    fields = dict(valid_fields(), surprise="not documented")
    assert any("Undocumented" in issue for issue in validate_frontmatter(fields, "test-skill"))


@pytest.mark.parametrize("text", [
    "name: test-skill\ndescription: body-only", "---\nname: test-skill\n",
    "---extra\nname: test-skill\n---", "---\n- name: test-skill\n---",
])
def test_delimiters_and_mapping_are_required(text):
    with pytest.raises(FrontmatterError):
        read_frontmatter(text)


def test_body_keys_do_not_satisfy_frontmatter():
    fields, body = read("license: MIT", "name: test-skill\ndescription: body-only\ncategory: testing")
    issues = validate_frontmatter(fields, "test-skill")
    for name in ("name", "description", "category"):
        assert any(name in issue for issue in issues)
    assert "body-only" in body


@pytest.mark.parametrize("fields", [
    "name: test-skill\nname: duplicate", "name: test-skill\n\tcategory: testing",
    "description: lifecycle: validate", 'description: "unescaped "inner" quotes"',
    "name: &anchor test-skill", "description: *anchor", "description: !!str hi",
    "description: {invalid: flow}", "description: [flow, list]",
    "metadata:\n  author: test\n  author: duplicate",
])
def test_malformed_or_unsupported_yaml_fails_closed(fields):
    with pytest.raises(FrontmatterError):
        read(fields)


@pytest.mark.parametrize("marker,expected", [("|", "First\nSecond\n"), ("|-", "First\nSecond"), (">", "First Second\n"), (">-", "First Second")])
def test_block_scalar_semantics(marker, expected):
    fields, _ = read(f"name: test-skill\ndescription: {marker}\n  First\n  Second\ncategory: testing")
    assert fields["description"] == expected
    assert not validate_frontmatter(fields, "test-skill")


def test_valid_quoted_scalars_nested_maps_and_changelog():
    fields, _ = read('''name: 'test-skill' # comment
description: "Use when testing: \\"quoted\\" requests"
category: testing
license: MIT
compatibility: bash
metadata:
  author: 'it''s me'
  version: "1.0"
changelog:
  - 1.0.0: Initial version
  - 0.9.0: Earlier version''')
    assert fields["metadata"]["author"] == "it's me"
    assert fields["changelog"] == [{"1.0.0": "Initial version"}, {"0.9.0": "Earlier version"}]
    assert not validate_frontmatter(fields, "test-skill")


def test_crlf_and_no_final_newline():
    text = "---\r\nname: test-skill\r\ndescription: Test\r\ncategory: testing\r\n---"
    fields, _ = read_frontmatter(text)
    assert not validate_frontmatter(fields, "test-skill")


def test_comment_only_value_is_empty():
    fields, _ = read("name: test-skill\ndescription: # absent\ncategory: testing")
    assert fields["description"] is None
    assert validate_frontmatter(fields, "test-skill")


def test_multiline_plain_scalar_preserves_paragraphs():
    fields, _ = read("description: First\n  line\n\n  Second\n  line")
    assert fields["description"] == "First line\nSecond line"


def test_folded_block_preserves_paragraphs():
    fields, _ = read("description: >-\n  First\n  line\n\n  Second\n  line")
    assert fields["description"] == "First line\nSecond line"
