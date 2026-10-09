import sys
import importlib.util
import ast
import json
from pathlib import Path
import pytest

# Add scripts directory to path for internal imports
REPO_ROOT = Path(__file__).parent.parent
scripts_dir = REPO_ROOT / "scripts"
sys.path.append(str(scripts_dir))

# Import eval_validators using importlib
spec = importlib.util.spec_from_file_location("eval_validators", scripts_dir / "lib" / "eval_validators.py")
eval_validators = importlib.util.module_from_spec(spec)
spec.loader.exec_module(eval_validators)

validate_evals_format = eval_validators.validate_evals_format


def valid_data():
    return {
        "skill_name": "test-skill",
        "evals": [
            {"id": idx, "prompt": "Test prompt", "expected_output": "Test output",
             "assertions": ["It happened"], "files": []}
            for idx in range(1, eval_validators.MIN_EVAL_CASES + 1)
        ],
    }

def test_validate_evals_format_valid():
    """Test with a fully valid evals dict."""
    data = {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test prompt",
                "expected_output": "Test output",
                "assertions": ["The output equals Test output"],
                "files": ["test.py"]
            }
        ]
    }
    case = data["evals"][0]
    data["evals"] = [dict(case, id=idx) for idx in range(1, 4)]
    issues = validate_evals_format(data, "test-skill")
    assert not issues

def test_validate_evals_format_missing_skill_name():
    """Test missing skill_name."""
    data = {
        "evals": []
    }
    issues = validate_evals_format(data, "test-skill")
    assert "Missing required field: 'skill_name'" in issues

def test_validate_evals_format_skill_name_mismatch():
    """Test skill_name mismatch."""
    data = {
        "skill_name": "wrong-skill",
        "evals": []
    }
    issues = validate_evals_format(data, "test-skill")
    assert any("Skill name mismatch" in issue for issue in issues)

def test_validate_evals_format_missing_evals():
    """Test missing evals."""
    data = {
        "skill_name": "test-skill"
    }
    issues = validate_evals_format(data, "test-skill")
    assert "Missing required field: 'evals'" in issues

def test_validate_evals_format_evals_not_list():
    """Test evals is not a list."""
    data = {
        "skill_name": "test-skill",
        "evals": "not-a-list"
    }
    issues = validate_evals_format(data, "test-skill")
    assert "'evals' must be an array" in issues

def test_validate_evals_format_empty_evals():
    """Test empty evals list."""
    data = {
        "skill_name": "test-skill",
        "evals": []
    }
    issues = validate_evals_format(data, "test-skill")
    assert "'evals' array is empty" in issues

def test_validate_evals_format_eval_not_dict():
    """Test eval item is not a dict."""
    data = {
        "skill_name": "test-skill",
        "evals": ["not-a-dict"]
    }
    issues = validate_evals_format(data, "test-skill")
    assert "Eval #1 is not an object" in issues

def test_validate_evals_format_missing_eval_fields():
    """Test missing required fields in eval item."""
    data = {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test prompt"
                # Missing expected_output
            }
        ]
    }
    issues = validate_evals_format(data, "test-skill")
    assert any("missing fields:" in issue and "expected_output" in issue for issue in issues)

def test_validate_evals_format_assertions_not_list():
    """Test assertions is not a list."""
    data = {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test prompt",
                "expected_output": "Test output",
                "assertions": "not-a-list"
            }
        ]
    }
    issues = validate_evals_format(data, "test-skill")
    assert "Eval #1: 'assertions' must be an array" in issues

def test_validate_evals_format_empty_assertions():
    """Test assertions list is empty."""
    data = {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test prompt",
                "expected_output": "Test output",
                "assertions": []
            }
        ]
    }
    issues = validate_evals_format(data, "test-skill")
    assert "Eval #1: 'assertions' array is empty" in issues

def test_validate_evals_format_files_not_list():
    """Test files is not a list."""
    data = {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test prompt",
                "expected_output": "Test output",
                "files": "not-a-list"
            }
        ]
    }
    issues = validate_evals_format(data, "test-skill")
    assert "Eval #1: 'files' must be an array" in issues

def test_validate_evals_format_files_not_strings():
    """Test files list contains non-strings."""
    data = {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test prompt",
                "expected_output": "Test output",
                "files": ["test.py", 123]
            }
        ]
    }
    issues = validate_evals_format(data, "test-skill")
    assert "Eval #1: all 'files' must be strings" in issues


# Tests for run_structure_check and load_evals_file

def test_load_evals_file_success(tmp_path):
    """Test successful loading of evals.json"""
    evals_file = tmp_path / "evals.json"
    evals_file.write_text('{"skill_name": "test"}', encoding="utf-8")
    data, error = eval_validators.load_evals_file(evals_file)
    assert data == {"skill_name": "test"}
    assert error is None

def test_load_evals_file_not_found(tmp_path):
    """Test loading non-existent file."""
    evals_file = tmp_path / "evals.json"
    data, error = eval_validators.load_evals_file(evals_file)
    assert data is None
    assert "File not found" in error

def test_load_evals_file_invalid_json(tmp_path):
    """Test loading invalid JSON."""
    evals_file = tmp_path / "evals.json"
    evals_file.write_text('{invalid_json}', encoding="utf-8")
    data, error = eval_validators.load_evals_file(evals_file)
    assert data is None
    assert "Invalid JSON" in error

def test_load_evals_file_other_error(tmp_path, monkeypatch):
    """Test other exceptions during loading."""
    evals_file = tmp_path / "evals.json"
    evals_file.write_text('{}', encoding="utf-8")

    # Mock read_text to raise an arbitrary exception
    def mock_read_text(*args, **kwargs):
        raise PermissionError("Permission denied")

    monkeypatch.setattr(Path, "read_text", mock_read_text)

    data, error = eval_validators.load_evals_file(evals_file)
    assert data is None
    assert "Error reading file: Permission denied" in error

def test_run_structure_check_pass(tmp_path):
    """Test structure check passing."""
    skill_path = tmp_path / "test-skill"
    skill_path.mkdir()
    (skill_path / "SKILL.md").touch()

    evals_dir = skill_path / "evals"
    evals_dir.mkdir()
    evals_file = evals_dir / "evals.json"

    evals_file.write_text(json.dumps(valid_data()), encoding="utf-8")

    result = eval_validators.run_structure_check(skill_path)
    assert result.status == eval_validators.EvalStatus.PASS
    assert "Structure check passed" in result.message

def test_run_structure_check_missing_skill_md(tmp_path):
    """Test structure check with missing SKILL.md."""
    skill_path = tmp_path / "test-skill"
    skill_path.mkdir()

    result = eval_validators.run_structure_check(skill_path)
    assert result.status == eval_validators.EvalStatus.FAIL
    assert "Missing required file: SKILL.md" in result.details

def test_run_structure_check_nested_duplicate(tmp_path):
    """Test structure check with nested duplicate directory."""
    skill_path = tmp_path / "test-skill"
    skill_path.mkdir()
    (skill_path / "SKILL.md").touch()

    # Create duplicate dir
    duplicate_dir = skill_path / "test-skill"
    duplicate_dir.mkdir()

    result = eval_validators.run_structure_check(skill_path)
    assert result.status == eval_validators.EvalStatus.FAIL
    assert any("Nested duplicate directory" in detail for detail in result.details)

def test_run_structure_check_invalid_evals_json(tmp_path):
    """Test structure check with invalid evals.json format."""
    skill_path = tmp_path / "test-skill"
    skill_path.mkdir()
    (skill_path / "SKILL.md").touch()

    evals_dir = skill_path / "evals"
    evals_dir.mkdir()
    evals_file = evals_dir / "evals.json"

    invalid_data = '{"skill_name": "wrong-skill", "evals": []}'
    evals_file.write_text(invalid_data, encoding="utf-8")

    result = eval_validators.run_structure_check(skill_path)
    assert result.status == eval_validators.EvalStatus.FAIL
    assert any("Skill name mismatch" in detail for detail in result.details)

def test_run_structure_check_evals_file_load_error(tmp_path, monkeypatch):
    """Test structure check when evals.json fails to load."""
    skill_path = tmp_path / "test-skill"
    skill_path.mkdir()
    (skill_path / "SKILL.md").touch()

    evals_dir = skill_path / "evals"
    evals_dir.mkdir()
    evals_file = evals_dir / "evals.json"
    evals_file.write_text('invalid-json', encoding="utf-8")

    result = eval_validators.run_structure_check(skill_path)
    assert result.status == eval_validators.EvalStatus.FAIL
    assert any("evals.json error: Invalid JSON" in detail for detail in result.details)


def test_minimum_contract_matches_standalone_checker():
    """Pin the portable checker contract without importing a repo dependency into it."""
    path = REPO_ROOT / ".agents/skills/skill-evaluator/scripts/check_structure.py"
    tree = ast.parse(path.read_text(encoding="utf-8"))
    assignments = {
        target.id: ast.literal_eval(node.value)
        for node in tree.body if isinstance(node, ast.Assign)
        for target in node.targets if isinstance(target, ast.Name)
        and target.id == "MIN_EVAL_CASES"
    }
    assert assignments.get("MIN_EVAL_CASES") == eval_validators.MIN_EVAL_CASES == 3


@pytest.mark.parametrize("count", [0, 1, 2, 3, 4])
def test_minimum_eval_cases(count):
    data = valid_data()
    case = data["evals"][0]
    data["evals"] = [dict(case, id=idx) for idx in range(count)]
    issues = validate_evals_format(data, "test-skill")
    assert bool(issues) == (count < eval_validators.MIN_EVAL_CASES)


@pytest.mark.parametrize("data", [[], None, "invalid", 1, False])
def test_nonobject_eval_document(data):
    assert validate_evals_format(data, "test-skill") == ["evals.json must be an object"]


@pytest.mark.parametrize("field,value", [
    ("id", True), ("id", "1"), ("id", []), ("id", 1.5),
    ("prompt", " "), ("prompt", None), ("expected_output", False),
    ("assertions", [""]), ("assertions", [None]), ("assertions", [{}]),
    ("assertions", [{"type": "match", "value": False}]),
    ("assertions", [{"type": "match", "value": "thing"}]),
])
def test_eval_case_field_types(field, value):
    data = valid_data()
    data["evals"][0][field] = value
    issues = validate_evals_format(data, "test-skill")
    assert any(field in issue for issue in issues)


def test_duplicate_ids_and_missing_assertions_aggregate():
    data = valid_data()
    data["evals"][1]["id"] = data["evals"][0]["id"]
    del data["evals"][0]["assertions"]
    issues = validate_evals_format(data, "test-skill")
    assert any("duplicate id" in issue for issue in issues)
    assert any("missing fields: assertions" in issue for issue in issues)


@pytest.mark.parametrize("name", ["", " ", "../outside", "/etc/passwd", "C:/fixture", "C:fixture", "\\\\server\\fixture", "a/../../x", "a\\..\\x", "a\x00b"])
def test_fixture_paths_must_be_relative_and_contained(name):
    data = valid_data()
    data["evals"][0]["files"] = [name]
    assert any("skill root" in issue for issue in validate_evals_format(data, "test-skill"))


def test_fixture_existence_and_symlink_containment(tmp_path):
    root = tmp_path / "test-skill"
    root.mkdir()
    (root / "present.md").write_text("fixture")
    outside = tmp_path / "outside.md"
    outside.write_text("not a fixture")
    (root / "escape.md").symlink_to(outside)
    (root / "inside.md").symlink_to(root / "present.md")
    data = valid_data()
    data["evals"][0]["files"] = ["present.md", "inside.md"]
    assert not validate_evals_format(data, "test-skill", root)
    data["evals"][0]["files"] = ["missing.md", "escape.md"]
    issues = validate_evals_format(data, "test-skill", root)
    assert any("does not exist" in issue for issue in issues)
    assert any("escapes the skill root" in issue for issue in issues)


def test_missing_evals_is_a_structure_failure(tmp_path):
    skill = tmp_path / "test-skill"
    skill.mkdir()
    (skill / "SKILL.md").touch()
    result = eval_validators.run_structure_check(skill)
    assert result.status == eval_validators.EvalStatus.FAIL
    assert "Missing required file: evals/evals.json" in result.details
