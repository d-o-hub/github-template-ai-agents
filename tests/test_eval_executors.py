import sys
from pathlib import Path

# Add scripts directory to path for internal imports
REPO_ROOT = Path(__file__).parent.parent
scripts_dir = REPO_ROOT / "scripts"
sys.path.append(str(scripts_dir))

from lib import eval_executors


def test_run_command_check_no_scripts_dir(tmp_path):
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    result = eval_executors.run_command_check({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.SKIP
    assert result.message == "No scripts directory found"

def test_run_command_check_no_scripts(tmp_path):
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    scripts_dir = skill_path / "scripts"
    scripts_dir.mkdir()
    result = eval_executors.run_command_check({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.SKIP
    assert result.message == "No executable scripts found"

def test_run_command_check_no_recognized_command(tmp_path):
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    scripts_dir = skill_path / "scripts"
    scripts_dir.mkdir()
    (scripts_dir / "other.py").touch()
    result = eval_executors.run_command_check({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.SKIP
    assert result.message == "No recognized command found to execute"

def test_run_command_check_success(tmp_path, monkeypatch):
    import subprocess
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    scripts_dir = skill_path / "scripts"
    scripts_dir.mkdir()
    check_structure = scripts_dir / "check_structure.py"
    check_structure.touch()

    class MockResult:
        returncode = 0
        stdout = "success"
        stderr = ""

    def mock_run(*args, **kwargs):
        return MockResult()

    monkeypatch.setattr(subprocess, "run", mock_run)
    result = eval_executors.run_command_check({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.PASS
    assert result.message == "Command executed successfully"

def test_run_command_check_fail(tmp_path, monkeypatch):
    import subprocess
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    scripts_dir = skill_path / "scripts"
    scripts_dir.mkdir()
    check_structure = scripts_dir / "check_structure.py"
    check_structure.touch()

    class MockResult:
        returncode = 1
        stdout = "output"
        stderr = "error"

    def mock_run(*args, **kwargs):
        return MockResult()

    monkeypatch.setattr(subprocess, "run", mock_run)
    result = eval_executors.run_command_check({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.FAIL
    assert result.message == "Command failed"
    assert result.details == ["output", "error"]

def test_run_command_check_timeout(tmp_path, monkeypatch):
    import subprocess
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    scripts_dir = skill_path / "scripts"
    scripts_dir.mkdir()
    check_structure = scripts_dir / "check_structure.py"
    check_structure.touch()

    def mock_run(*args, **kwargs):
        raise subprocess.TimeoutExpired(cmd="cmd", timeout=30)

    monkeypatch.setattr(subprocess, "run", mock_run)
    result = eval_executors.run_command_check({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.ERROR
    assert result.message == "Command timed out after 30 seconds"

def test_run_command_check_error(tmp_path, monkeypatch):
    import subprocess
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    scripts_dir = skill_path / "scripts"
    scripts_dir.mkdir()
    check_structure = scripts_dir / "check_structure.py"
    check_structure.touch()

    def mock_run(*args, **kwargs):
        raise RuntimeError("Something went wrong")

    monkeypatch.setattr(subprocess, "run", mock_run)
    result = eval_executors.run_command_check({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.ERROR
    assert "Command execution error: Something went wrong" in result.message

def test_run_file_validation_no_files(tmp_path):
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    result = eval_executors.run_file_validation({"id": 1}, skill_path, False)
    assert result.status == eval_executors.EvalStatus.SKIP
    assert result.message == "No files to validate"

def test_run_file_validation_all_found(tmp_path):
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    (skill_path / "test1.py").touch()
    (skill_path / "test2.py").touch()

    eval_case = {"id": 1, "files": ["test1.py", "test2.py"]}
    result = eval_executors.run_file_validation(eval_case, skill_path, False)
    assert result.status == eval_executors.EvalStatus.PASS
    assert result.message == "All 2 file(s) validated"
    assert result.details == ["Found: test1.py", "Found: test2.py"]

def test_run_file_validation_missing_files(tmp_path):
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    (skill_path / "test1.py").touch()

    eval_case = {"id": 1, "files": ["test1.py", "missing.py"]}
    result = eval_executors.run_file_validation(eval_case, skill_path, False)
    assert result.status == eval_executors.EvalStatus.FAIL
    assert result.message == "Missing 1 file(s)"
    assert result.details == ["Missing: missing.py", "Found: test1.py"]

def test_run_file_validation_path_traversal(tmp_path):
    skill_path = tmp_path / "skill"
    skill_path.mkdir()
    (skill_path.parent / "secret.txt").touch()

    eval_case = {"id": 1, "files": ["../secret.txt"]}
    result = eval_executors.run_file_validation(eval_case, skill_path, False)
    assert result.status == eval_executors.EvalStatus.FAIL
    assert result.message == "Missing 1 file(s)"
    assert result.details == ["Missing: ../secret.txt"]
