"""Differential checks of the actual bounded reader; PyYAML is test-only."""

import itertools
import subprocess
import sys
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from lib.skill_frontmatter import (
    MAX_DESCRIPTION_CHARS, FrontmatterError, read_frontmatter, validate_frontmatter,
)


def fields(extra):
    return "name: test-skill\ncategory: testing\n" + extra + "\nlicense: MIT\n"


def document(frontmatter):
    return "---\n" + frontmatter + "---\n# Fixture\n"


def actual_cli(tmp_path, frontmatter):
    skill = tmp_path / "test-skill"
    skill.mkdir(exist_ok=True)
    path = skill / "SKILL.md"
    path.write_text(document(frontmatter), encoding="utf-8")
    return subprocess.run(
        [sys.executable, "-S", str(ROOT / "scripts/lib/skill_frontmatter.py"), str(path)],
        capture_output=True, text=True, check=False,
    )


@pytest.mark.parametrize("indicator", ["-", "?", "- # comment", "? # comment"])
def test_bare_collection_indicators_are_not_plain_scalars(tmp_path, indicator):
    frontmatter = fields("description: " + indicator)
    with pytest.raises(yaml.YAMLError):
        yaml.safe_load(frontmatter)
    with pytest.raises(FrontmatterError):
        read_frontmatter(document(frontmatter))
    result = actual_cli(tmp_path, frontmatter)
    assert result.returncode == 1
    assert "unexpected YAML collection indicator" in result.stderr


@pytest.mark.parametrize("description", [
    "Release\n  2026", "Release\n  yes", "yes\n  Release", "2026\n  Release",
    "Release\n  false\n\n  2026", "Release\n  null", "Release\n  0xFF",
    "Release\n  2026 # final comment", '"Use # issues: carefully"',
])
def test_plain_scalar_is_folded_before_type_resolution(tmp_path, description):
    frontmatter = fields("description: " + description)
    reference = yaml.safe_load(frontmatter)
    actual, _ = read_frontmatter(document(frontmatter))
    assert actual == reference
    assert isinstance(actual["description"], str)
    assert not validate_frontmatter(actual, "test-skill")
    assert actual_cli(tmp_path, frontmatter).returncode == 0


@pytest.mark.parametrize("description", [
    "Release # comment\n  2026", "Release\n# comment\n  2026",
])
def test_comments_end_a_plain_scalar(description):
    frontmatter = fields("description: " + description)
    with pytest.raises(yaml.YAMLError):
        yaml.safe_load(frontmatter)
    with pytest.raises(FrontmatterError):
        read_frontmatter(document(frontmatter))


@pytest.mark.parametrize("indent", ["", "  "])
@pytest.mark.parametrize("key", ['"author name"', "'author''s name'", '"author: name"', '"2026"'])
def test_indentless_sequences_and_quoted_metadata_keys(tmp_path, indent, key):
    frontmatter = fields(
        "description: Use when testing\nmetadata:\n  " + key + ": Example\n"
        "changelog:\n" + indent + "- 0.1.0: initial\n"
        + indent + "- '0.2.0': follow-up\ntrigger: after a task"
    )
    reference = yaml.safe_load(frontmatter)
    actual, _ = read_frontmatter(document(frontmatter))
    assert actual == reference
    assert not validate_frontmatter(actual, "test-skill")
    assert actual_cli(tmp_path, frontmatter).returncode == 0


@pytest.mark.parametrize("marker", ["|", "|-", "|+", ">", ">-", ">+"])
def test_block_folding_differential_matrix(marker):
    # Exhaustive short combinations cover normal/more-indented/blank lines,
    # leading/trailing blanks, indentation detection, and all chomping modes.
    styles = {
        "normal": "  Normal", "more": "    Indented", "blank": "",
        "spaced_blank": "  ", "more_spaced_blank": "    ",
    }
    for length in range(5):
        for combination in itertools.product(styles, repeat=length):
            extra = "description: " + marker + "\n" + "\n".join(styles[s] for s in combination)
            frontmatter = fields(extra)
            try:
                reference = yaml.safe_load(frontmatter)
            except yaml.YAMLError:
                with pytest.raises(FrontmatterError):
                    read_frontmatter(document(frontmatter))
                continue
            actual, _ = read_frontmatter(document(frontmatter))
            assert actual == reference, (marker, combination, actual, reference)


@pytest.mark.parametrize("length", [MAX_DESCRIPTION_CHARS - 1, MAX_DESCRIPTION_CHARS, MAX_DESCRIPTION_CHARS + 1])
def test_more_indented_paragraph_at_description_boundary(tmp_path, length):
    template = "description: >-\n  {}\n    More\n\n  End"
    overhead = len(yaml.safe_load(fields(template.format("x")))["description"]) - 1
    frontmatter = fields(template.format("x" * (length - overhead)))
    reference = yaml.safe_load(frontmatter)
    assert len(reference["description"]) == length
    actual, _ = read_frontmatter(document(frontmatter))
    assert actual == reference
    assert len(actual["description"]) == length
    issues = validate_frontmatter(actual, "test-skill")
    assert bool(issues) == (length > MAX_DESCRIPTION_CHARS)
    result = actual_cli(tmp_path, frontmatter)
    assert result.returncode == (1 if length > MAX_DESCRIPTION_CHARS else 0)
    if length > MAX_DESCRIPTION_CHARS:
        assert "description must be 1-1024 characters" in result.stderr
