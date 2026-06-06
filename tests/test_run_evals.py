import sys
import importlib.util
from pathlib import Path
import pytest

# Add scripts directory to path for internal imports
REPO_ROOT = Path(__file__).parent.parent
scripts_dir = REPO_ROOT / "scripts"
sys.path.append(str(scripts_dir))

# Import run-evals.py using importlib
spec = importlib.util.spec_from_file_location("run_evals", scripts_dir / "run-evals.py")
run_evals = importlib.util.module_from_spec(spec)
spec.loader.exec_module(run_evals)

generate_text_report = run_evals.generate_text_report

from unittest.mock import patch, MagicMock

# Import types for testing
from lib.eval_types import EvalReport, SkillEvalResult, EvalResult, EvalStatus, EvalType

# Test skill paths are relative identifiers, not real filesystem locations:
# every callsite passes them to a mocked function, so the contents of the
# Path object are never dereferenced.  Using relative paths avoids the
# SonarCloud S5443 hotspot (publicly writable directory usage).
TEST_SKILL_PATH = Path("test-skill")
TEST_FAIL_SKILL_PATH = Path("fail-skill")
TEST_SKIP_SKILL_PATH = Path("skip-skill")

def test_evaluate_skill_success():
    """Test evaluate_skill when all eval cases pass or are skipped."""
    skill_path = TEST_SKILL_PATH
    eval_types = [EvalType.COMMAND]
    verbose = False

    mock_data = {
        "evals": [
            {"id": 1, "prompt": "test 1"},
            {"id": 2, "prompt": "test 2"}
        ]
    }

    with patch.object(run_evals, "load_evals_file") as mock_load, \
         patch.object(run_evals, "validate_evals_format") as mock_validate, \
         patch.object(run_evals, "run_eval_case") as mock_run_case:

        mock_load.return_value = (mock_data, None)
        mock_validate.return_value = []
        mock_run_case.side_effect = [
            EvalResult(eval_id=1, status=EvalStatus.PASS, message="Success"),
            EvalResult(eval_id=2, status=EvalStatus.SKIP, message="Skipped")
        ]

        result = run_evals.evaluate_skill(skill_path, eval_types, verbose)

        assert result.skill_name == "test-skill"
        assert result.status == EvalStatus.PASS
        assert result.evals_run == 2
        assert result.evals_passed == 1
        assert result.evals_skipped == 1
        assert result.evals_failed == 0
        assert len(result.eval_results) == 2
        assert result.eval_results[0].status == EvalStatus.PASS
        assert result.eval_results[1].status == EvalStatus.SKIP

def test_evaluate_skill_failure_in_case():
    """Test evaluate_skill when an eval case fails."""
    skill_path = TEST_SKILL_PATH
    eval_types = [EvalType.COMMAND]
    verbose = False

    mock_data = {
        "evals": [
            {"id": 1, "prompt": "test 1"}
        ]
    }

    with patch.object(run_evals, "load_evals_file") as mock_load, \
         patch.object(run_evals, "validate_evals_format") as mock_validate, \
         patch.object(run_evals, "run_eval_case") as mock_run_case:

        mock_load.return_value = (mock_data, None)
        mock_validate.return_value = []
        mock_run_case.return_value = EvalResult(eval_id=1, status=EvalStatus.FAIL, message="Failure")

        result = run_evals.evaluate_skill(skill_path, eval_types, verbose)

        assert result.status == EvalStatus.FAIL
        assert result.evals_run == 1
        assert result.evals_passed == 0
        assert result.evals_failed == 1

def test_evaluate_skill_load_error():
    """Test evaluate_skill when evals.json fails to load."""
    skill_path = TEST_SKILL_PATH

    with patch.object(run_evals, "load_evals_file") as mock_load:
        mock_load.return_value = (None, "File not found")

        result = run_evals.evaluate_skill(skill_path, [], False)

        assert result.status == EvalStatus.FAIL
        assert "File not found" in result.errors

def test_evaluate_skill_validation_error():
    """Test evaluate_skill when evals.json has format issues."""
    skill_path = TEST_SKILL_PATH

    with patch.object(run_evals, "load_evals_file") as mock_load, \
         patch.object(run_evals, "validate_evals_format") as mock_validate:
        mock_load.return_value = ({"evals": []}, None)
        mock_validate.return_value = ["Invalid format"]

        result = run_evals.evaluate_skill(skill_path, [], False)

        assert result.status == EvalStatus.FAIL
        assert "Invalid format" in result.errors

def test_evaluate_skill_with_structure_check():
    """Test evaluate_skill when structure check is included."""
    skill_path = TEST_SKILL_PATH
    eval_types = [EvalType.STRUCTURE, EvalType.COMMAND]

    mock_data = {"evals": [{"id": 1}]}

    with patch.object(run_evals, "load_evals_file") as mock_load, \
         patch.object(run_evals, "validate_evals_format") as mock_validate, \
         patch.object(run_evals, "run_structure_check") as mock_structure, \
         patch.object(run_evals, "run_eval_case") as mock_run_case:

        mock_load.return_value = (mock_data, None)
        mock_validate.return_value = []
        mock_structure.return_value = EvalResult(eval_id=0, status=EvalStatus.PASS, message="Structure OK")
        mock_run_case.return_value = EvalResult(eval_id=1, status=EvalStatus.PASS, message="Command OK")

        result = run_evals.evaluate_skill(skill_path, eval_types, False)

        assert result.evals_run == 2
        assert result.evals_passed == 2
        assert mock_structure.called

def test_generate_text_report_basic():
    report = EvalReport(
        total_skills=1,
        skills_passed=1,
        total_evals=1,
        evals_passed=1,
        skill_results=[
            SkillEvalResult(
                skill_name="test-skill",
                skill_path=TEST_SKILL_PATH,
                status=EvalStatus.PASS,
                evals_run=1,
                evals_passed=1,
                eval_results=[
                    EvalResult(eval_id=1, status=EvalStatus.PASS, message="Success")
                ]
            )
        ]
    )

    output = generate_text_report(report)

    assert "Total skills evaluated: 1" in output
    assert "- Passed: 1" in output
    assert "Total eval scenarios: 1" in output
    assert "[PASS] test-skill" in output

def test_generate_text_report_failure():
    report = EvalReport(
        total_skills=1,
        skills_passed=0,
        skills_failed=1,
        total_evals=1,
        evals_passed=0,
        evals_failed=1,
        skill_results=[
            SkillEvalResult(
                skill_name="fail-skill",
                skill_path=TEST_FAIL_SKILL_PATH,
                status=EvalStatus.FAIL,
                evals_run=1,
                evals_passed=0,
                eval_results=[
                    EvalResult(eval_id=1, status=EvalStatus.FAIL, message="Error message")
                ]
            )
        ]
    )

    output = generate_text_report(report)

    assert "Total skills evaluated: 1" in output
    assert "- Failed: 1" in output
    assert "[FAIL] fail-skill" in output
    assert "Eval #1: Error message" in output

def test_generate_text_report_with_skips():
    report = EvalReport(
        total_skills=1,
        skills_passed=1,
        total_evals=2,
        evals_passed=1,
        evals_skipped=1,
        skill_results=[
            SkillEvalResult(
                skill_name="skip-skill",
                skill_path=TEST_SKIP_SKILL_PATH,
                status=EvalStatus.PASS,
                evals_run=2,
                evals_passed=1,
                evals_skipped=1,
                eval_results=[
                    EvalResult(eval_id=1, status=EvalStatus.PASS, message="Success"),
                    EvalResult(eval_id=2, status=EvalStatus.SKIP, message="Missing tool")
                ]
            )
        ]
    )

    output = generate_text_report(report)

    assert "- Skipped: 1" in output
    assert "[PASS] skip-skill" in output
    assert "[SKIP] Eval #2: Missing tool" in output

def test_discover_skills_traversal():
    """Test that discover_skills rejects path traversal payloads."""
    skills_dir = Path("/app/.agents/skills")

    # Relative traversal
    assert run_evals.discover_skills(skills_dir, "../../../tmp/exploit") == []
    assert run_evals.discover_skills(skills_dir, "skill/../../etc") == []

    # Absolute path
    assert run_evals.discover_skills(skills_dir, "/etc/passwd") == []
