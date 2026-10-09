"""Feed the same definitions to the repository and standalone eval validators."""

import importlib.util
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from lib.eval_validators import EvalStatus, run_structure_check, validate_evals_format

SPEC = importlib.util.spec_from_file_location(
    "standalone_parity_checker", ROOT / ".agents/skills/skill-evaluator/scripts/check_structure.py"
)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def definition():
    return {"skill_name": "test-skill", "evals": [
        {"id": idx, "prompt": "Test", "expected_output": "Test", "assertions": ["It works"]}
        for idx in range(1, 4)
    ]}


def assert_parity(data, expected, skill=None):
    repo_issues = validate_evals_format(data, "test-skill", skill)
    standalone_issues = checker.check_eval_fields(data, skill)
    assert (not repo_issues) is expected, repo_issues
    assert (not standalone_issues) is expected, standalone_issues
    if skill is not None:
        (skill / "evals/evals.json").write_text(json.dumps(data), encoding="utf-8")
        assert (run_structure_check(skill).status == EvalStatus.PASS) is expected
        assert (checker.check_skill(skill)["status"] == "PASS") is expected


@pytest.fixture
def skill(tmp_path):
    root = tmp_path / "test-skill"
    (root / "evals").mkdir(parents=True)
    (root / "SKILL.md").write_text("# Fixture\n", encoding="utf-8")
    (root / "present.txt").write_text("fixture\n", encoding="utf-8")
    (root / "nested").mkdir()
    (root / "nested/input.txt").write_text("fixture\n", encoding="utf-8")
    outside = tmp_path / "outside.txt"
    outside.write_text("outside\n", encoding="utf-8")
    (root / "escape.txt").symlink_to(outside)
    (root / "inside.txt").symlink_to(root / "present.txt")
    return root


@pytest.mark.parametrize("buckets,expected", [
    ([], True), (["explicit"], False), (["contextual", "implicit"], False),
    (["explicit", "negative"], True), (["negative"], True),
    ([None], False), ([None, "negative"], False), ([[], "negative"], False),
    (["unknown", "negative"], False),
])
def test_optional_buckets_need_negative_when_declared(skill, buckets, expected):
    data = definition()
    for case, bucket in zip(data["evals"], buckets):
        case["bucket"] = bucket
    assert_parity(data, expected, skill)


@pytest.mark.parametrize("path,expected_without_root,expected_with_root", [
    ("present.txt", True, True), ("nested/input.txt", True, True),
    ("./present.txt", True, True), ("inside.txt", True, True),
    ("missing.txt", True, False), ("nested", True, False), ("escape.txt", True, False),
    ("../outside.txt", False, False), ("nested/../../outside.txt", False, False),
    ("/input.txt", False, False), ("C:/input.txt", False, False),
    ("C:input.txt", False, False), ("C:\\input.txt", False, False),
    ("\\\\server\\share\\input.txt", False, False),
    ("\\input.txt", False, False), ("nested\\input.txt", False, False),
    ("nested\\..\\outside.txt", False, False), ("", False, False), (" ", False, False),
    ("input\x00.txt", False, False),
])
def test_fixture_path_contract_on_both_readers(skill, path, expected_without_root, expected_with_root):
    data = definition()
    data["evals"][0]["files"] = [path]
    assert_parity(data, expected_without_root)
    assert_parity(data, expected_with_root, skill)
