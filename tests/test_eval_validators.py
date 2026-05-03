import sys
from pathlib import Path

# Add scripts directory to path for internal imports
REPO_ROOT = Path(__file__).parent.parent
scripts_dir = REPO_ROOT / "scripts"
sys.path.append(str(scripts_dir))

from lib import eval_validators

validate_evals_format = eval_validators.validate_evals_format

def test_validate_evals_format_valid():
    """Test with a fully valid evals dict."""
    data = {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test prompt",
                "expected_output": "Test output",
                "assertions": [{"type": "exact_match", "value": "Test output"}],
                "files": ["test.py"]
            }
        ]
    }
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
    assert any("missing fields: expected_output" in issue for issue in issues)

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

    valid_data = '''{
        "skill_name": "test-skill",
        "evals": [
            {
                "id": 1,
                "prompt": "Test",
                "expected_output": "Test"
            }
        ]
    }'''
    evals_file.write_text(valid_data, encoding="utf-8")

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
