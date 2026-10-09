"""Exercise copied validator/setup scripts against isolated adopter fixtures."""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

SOURCE_ROOT = Path(__file__).resolve().parents[1]
LIBRARIES = (
    "skill-validation.sh", "skill_frontmatter.py", "optional_skills.sh",
    "eval_validators.py", "eval_types.py",
)


def write_skill(root, name="test-skill", count=3):
    skill = root / ".agents/skills" / name
    (skill / "evals").mkdir(parents=True)
    (skill / "SKILL.md").write_text(
        f"---\nname: {name}\ndescription: Use when testing\ncategory: testing\n"
        "version: '1.0.0'\n---\n# Fixture\n## Rationalizations\n## Red Flags\n"
    )
    data = {"skill_name": name, "evals": [
        {"id": idx, "prompt": "Test", "expected_output": "Test", "assertions": ["It works"]}
        for idx in range(1, count + 1)
    ]}
    (skill / "evals/evals.json").write_text(json.dumps(data))
    return skill


@pytest.fixture
def repo(tmp_path):
    (tmp_path / "scripts/lib").mkdir(parents=True)
    for script in ("validate-skills.sh", "setup-skills.sh"):
        shutil.copy2(SOURCE_ROOT / "scripts" / script, tmp_path / "scripts")
    for library in LIBRARIES:
        shutil.copy2(SOURCE_ROOT / "scripts/lib" / library, tmp_path / "scripts/lib")
    write_skill(tmp_path)
    return tmp_path


def run(root, script="validate-skills.sh", **env):
    environment = dict(os.environ, REPO_ROOT=str(root), PYTHONDONTWRITEBYTECODE="1", **env)
    return subprocess.run(
        ["bash", str(root / "scripts" / script)], cwd=root, env=environment,
        capture_output=True, text=True, check=False,
    )


def rule(skill="test-skill"):
    return {"skill": skill, "triggers": {"keywords": ["test"], "patterns": ["test.*"], "files": []},
            "priority": "high", "autoActivate": True}


def test_valid_copied_fixture(repo):
    result = run(repo)
    assert result.returncode == 0, result.stdout + result.stderr


def test_frontmatter_reader_needs_no_site_packages(repo):
    result = subprocess.run(
        ["python3", "-S", str(repo / "scripts/lib/skill_frontmatter.py"),
         str(repo / ".agents/skills/test-skill/SKILL.md")],
        capture_output=True, text=True, check=False,
        env={**os.environ, "SKILL_FRONTMATTER_ROOT": str(repo / ".agents/skills")},
    )
    assert result.returncode == 0, result.stderr


def test_frontmatter_reader_rejects_path_outside_skill_root(repo, tmp_path):
    outside = tmp_path / "outside" / "SKILL.md"
    outside.parent.mkdir()
    outside.write_text("---\nname: outside\n---\n", encoding="utf-8")
    result = subprocess.run(
        ["python3", "-S", str(repo / "scripts/lib/skill_frontmatter.py"), str(outside)],
        capture_output=True,
        text=True,
        check=False,
        env={**os.environ, "SKILL_FRONTMATTER_ROOT": str(repo / ".agents/skills")},
    )
    assert result.returncode == 1
    assert "SKILL_FRONTMATTER_ROOT" in result.stderr


def test_frontmatter_reader_reports_missing_root_without_traceback(repo):
    result = subprocess.run(
        ["python3", "-S", str(repo / "scripts/lib/skill_frontmatter.py"),
         str(repo / ".agents/skills/test-skill/SKILL.md")],
        capture_output=True, text=True, check=False,
        env={key: value for key, value in os.environ.items()
             if key != "SKILL_FRONTMATTER_ROOT"},
    )
    assert result.returncode == 1
    assert "SKILL_FRONTMATTER_ROOT is required" in result.stderr
    assert "UnboundLocalError" not in result.stderr


def test_missing_shared_manifest_cannot_silently_change_policy(repo):
    (repo / "scripts/lib/optional_skills.sh").unlink()
    result = run(repo)
    assert result.returncode == 2


def test_empty_skill_set_still_checks_routing_references(repo):
    shutil.rmtree(repo / ".agents/skills/test-skill")
    (repo / ".agents/skill-rules.json").write_text(json.dumps({"rules": [rule()]}))
    result = run(repo)
    assert result.returncode == 2
    assert "referenced skill 'test-skill'" in result.stdout


@pytest.mark.parametrize("missing", ["category: testing\n", "## Rationalizations\n", "## Red Flags\n"])
def test_required_authoring_fields_fail(repo, missing):
    path = repo / ".agents/skills/test-skill/SKILL.md"
    path.write_text(path.read_text().replace(missing, ""))
    result = run(repo)
    assert result.returncode == 2
    assert missing.strip().split(":")[0] in result.stdout + result.stderr


@pytest.mark.parametrize("count", [0, 1, 2, 3])
def test_eval_minimum_is_a_hard_failure(repo, count):
    path = repo / ".agents/skills/test-skill/evals/evals.json"
    data = json.loads(path.read_text())
    data["evals"] = data["evals"][:count]
    path.write_text(json.dumps(data))
    result = run(repo)
    assert result.returncode == (2 if count < 3 else 0), result.stdout + result.stderr
    if count < 3:
        assert "at least 3 cases" in result.stdout


def test_aggregates_authoring_evals_and_routing_failures(repo):
    path = repo / ".agents/skills/test-skill/SKILL.md"
    path.write_text(path.read_text().replace("## Red Flags", "## Red FlagsMissing"))
    (repo / ".agents/skills/test-skill/evals/evals.json").write_text("[]")
    (repo / ".agents/skill-rules.json").write_text(json.dumps({"rules": [rule("missing")]}))
    result = run(repo)
    assert result.returncode == 2
    assert "Missing '## Red Flags'" in result.stdout
    assert "evals.json must be an object" in result.stdout
    assert "referenced skill 'missing'" in result.stdout
    assert "All skills valid" not in result.stdout


@pytest.mark.parametrize("location", [".agents/skill-rules.json", ".agents/skills/skill-rules.json"])
def test_routing_counts_array_not_top_level_keys_and_preserves_file(repo, location):
    path = repo / location
    text = json.dumps({"title": "Fixture", "rules": [rule(), rule()], "settings": {}, "$schema": "fixture"})
    path.write_text(text)
    result = run(repo)
    assert result.returncode == 0, result.stdout + result.stderr
    assert f"{location}: 2 rules defined" in result.stdout
    assert path.read_text() == text


@pytest.mark.parametrize("data,expected", [
    ({"rule1": "value1"}, "'rules' array"),
    ({"rules": {}}, "'rules' array"), ({"rules": [None]}, "must be an object"),
    ({"rules": [rule("../escape")]}, "canonical skill name"),
    ({"rules": [dict(rule(), autoActivate="yes")]}, "must be a boolean"),
    ({"rules": [dict(rule(), priority="urgent")]}, "priority"),
    ({"rules": [dict(rule(), triggers="test")]}, "triggers"),
    ({"rules": [dict(rule(), triggers={"keywords": "test", "patterns": ["["], "files": [None]})]}, "invalid trigger pattern"),
])
def test_routing_shape_and_types(repo, data, expected):
    (repo / ".agents/skill-rules.json").write_text(json.dumps(data))
    result = run(repo)
    assert result.returncode == 2
    assert expected in result.stdout


def test_both_routing_files_are_checked_without_overwriting(repo):
    first = repo / ".agents/skill-rules.json"
    second = repo / ".agents/skills/skill-rules.json"
    first.write_text(json.dumps({"rules": [rule()]}))
    second.write_text("{ invalid json }")
    before = (first.read_bytes(), second.read_bytes())
    result = run(repo)
    assert result.returncode == 2
    assert ".agents/skill-rules.json: 1 rules defined" in result.stdout
    assert ".agents/skills/skill-rules.json: Invalid JSON" in result.stdout
    assert before == (first.read_bytes(), second.read_bytes())


def test_optional_link_policy_is_shared_without_demotions(repo):
    write_skill(repo, "codacy")
    write_skill(repo, "secure-invite-and-access")
    setup = run(repo, "setup-skills.sh", LINK_OPTIONAL="false")
    assert setup.returncode == 0, setup.stderr
    for cli in (".claude", ".qwen"):
        assert not (repo / cli / "skills/codacy").is_symlink()
        assert (repo / cli / "skills/secure-invite-and-access").is_symlink()
    result = run(repo)
    assert result.returncode == 0, result.stdout + result.stderr
    (repo / ".claude/skills/secure-invite-and-access").unlink()
    assert run(repo).returncode == 2
    setup = run(repo, "setup-skills.sh", LINK_OPTIONAL="true")
    assert setup.returncode == 0
    assert (repo / ".qwen/skills/codacy").is_symlink()
    assert run(repo).returncode == 0


def test_line_limit_remains_warning(repo):
    path = repo / ".agents/skills/test-skill/SKILL.md"
    path.write_text(path.read_text() + "\n" * 260)
    result = run(repo)
    assert result.returncode == 0
    assert "exceeds 250 lines" in result.stderr


def test_leading_zero_template_version_does_not_trigger_octal_errors(repo):
    (repo / "VERSION").write_text("0.2.10\n")
    path = repo / ".agents/skills/test-skill/SKILL.md"
    path.write_text(path.read_text().replace("category: testing", "category: testing\ntemplate_version: 0.08.0"))
    result = run(repo)
    assert result.returncode == 0, result.stdout + result.stderr
