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

def test_generate_text_report_basic():
    report = EvalReport(
        total_skills=1,
        skills_passed=1,
        total_evals=1,
        evals_passed=1,
        skill_results=[
            SkillEvalResult(
                skill_name="test-skill",
                skill_path=Path("/tmp/test-skill"),
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
                skill_path=Path("/tmp/fail-skill"),
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
