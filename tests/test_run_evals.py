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

# Import types for testing
from lib.eval_types import EvalReport, SkillEvalResult, EvalResult, EvalStatus

def test_generate_text_report_all_pass():
    """Test report generation when everything passes."""
    report = EvalReport(
        total_skills=1,
        skills_passed=1,
        skills_failed=0,
        total_evals=2,
        evals_passed=2,
        evals_failed=0,
        evals_skipped=0,
        skill_results=[
            SkillEvalResult(
                skill_name="test-skill",
                skill_path=Path("/tmp/test-skill"),
                status=EvalStatus.PASS,
                evals_run=2,
                evals_passed=2,
                eval_results=[
                    EvalResult(eval_id=1, status=EvalStatus.PASS, message="Success 1"),
                    EvalResult(eval_id=2, status=EvalStatus.PASS, message="Success 2")
                ]
            )
        ]
    )

    output = generate_text_report(report)

    assert "SKILL EVALUATION REPORT" in output
    assert "Total skills evaluated: 1" in output
    assert "Passed: 1" in output
    assert "Failed: 0" in output
    assert "OVERALL STATUS: PASS" in output
    assert "[PASS] test-skill" in output
    assert "[PASS] Eval #1: Success 1" in output
    assert "[PASS] Eval #2: Success 2" in output

def test_generate_text_report_with_failures():
    """Test report generation when there are failures."""
    report = EvalReport(
        total_skills=2,
        skills_passed=1,
        skills_failed=1,
        total_evals=2,
        evals_passed=1,
        evals_failed=1,
        evals_skipped=0,
        skill_results=[
            SkillEvalResult(
                skill_name="pass-skill",
                skill_path=Path("/tmp/pass-skill"),
                status=EvalStatus.PASS,
                evals_run=1,
                evals_passed=1,
                eval_results=[
                    EvalResult(eval_id=1, status=EvalStatus.PASS, message="Success")
                ]
            ),
            SkillEvalResult(
                skill_name="fail-skill",
                skill_path=Path("/tmp/fail-skill"),
                status=EvalStatus.FAIL,
                evals_run=1,
                evals_failed=1,
                errors=["Generic error"],
                eval_results=[
                    EvalResult(eval_id=1, status=EvalStatus.FAIL, message="Failure", details=["Line 10"])
                ]
            )
        ]
    )

    output = generate_text_report(report)

    assert "Total skills evaluated: 2" in output
    assert "Failed: 1" in output
    assert "OVERALL STATUS: FAIL" in output
    assert "[PASS] pass-skill" in output
    assert "[FAIL] fail-skill" in output
    assert "Errors:" in output
    assert "- Generic error" in output
    assert "[FAIL] Eval #1: Failure" in output
    assert "- Line 10" in output

def test_generate_text_report_with_skips():
    """Test report generation when there are skipped evals."""
    report = EvalReport(
        total_skills=1,
        skills_passed=1,
        skills_failed=0,
        total_evals=2,
        evals_passed=1,
        evals_failed=0,
        evals_skipped=1,
        skill_results=[
            SkillEvalResult(
                skill_name="skip-skill",
                skill_path=Path("/tmp/skip-skill"),
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

    assert "Skipped: 1" in output
    assert "[PASS] skip-skill" in output
    assert "[SKIP] Eval #2: Missing tool" in output
