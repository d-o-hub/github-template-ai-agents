"""Unit and fixture tests for the paired behavioral evaluation adapter and runner."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, Dict

import pytest

# Ensure scripts and scripts/lib are on python path
repo_root = Path(__file__).resolve().parent.parent
scripts_dir = repo_root / "scripts"
if str(scripts_dir) not in sys.path:
    sys.path.insert(0, str(scripts_dir))

from lib.paired_eval_adapter import (
    UNAVAILABLE,
    PairedEvalAdapter,
    calculate_file_sha256,
    calculate_skill_content_digest,
)


@pytest.fixture
def mock_skills_env(tmp_path: Path) -> Dict[str, Path]:
    """Create a temporary skills and baselines directory structure for testing."""
    skills_dir = tmp_path / "skills"
    baselines_dir = tmp_path / "baselines"
    skills_dir.mkdir(parents=True)
    baselines_dir.mkdir(parents=True)

    # Sample skill
    sample_skill = skills_dir / "sample-skill"
    sample_skill.mkdir(parents=True)
    (sample_skill / "SKILL.md").write_text(
        "---\nname: sample-skill\ndescription: Use when testing.\ncategory: quality\n---\n# Sample\n## Rationalizations\n- none\n## Red Flags\n- none\n",
        encoding="utf-8",
    )
    evals_dir = sample_skill / "evals"
    evals_dir.mkdir(parents=True)
    evals_file = evals_dir / "evals.json"
    evals_file.write_text(
        json.dumps({
          "skill_name": "sample-skill",
          "evals": [
            {
              "id": 1,
              "bucket": "explicit",
              "prompt": "Test explicit task",
              "expected_output": "Expected 1",
              "assertions": ["Assertion 1"]
            },
            {
              "id": 2,
              "bucket": "implicit",
              "prompt": "Test implicit task",
              "expected_output": "Expected 2",
              "assertions": ["Assertion 2"]
            },
            {
              "id": 3,
              "bucket": "negative",
              "prompt": "Test negative task",
              "expected_output": "Out of scope",
              "assertions": ["Assertion 3"]
            }
          ]
        }, indent=2),
        encoding="utf-8",
    )

    return {
        "root": tmp_path,
        "skills_dir": skills_dir,
        "baselines_dir": baselines_dir,
        "sample_skill": sample_skill,
        "evals_file": evals_file,
    }


def test_digests_calculation(mock_skills_env: Dict[str, Path]) -> None:
    """Test SHA256 content digest computation for skill and fixture files."""
    sample_skill = mock_skills_env["sample_skill"]
    evals_file = mock_skills_env["evals_file"]

    skill_digest = calculate_skill_content_digest(sample_skill)
    fixture_digest = calculate_file_sha256(evals_file)

    assert skill_digest.startswith("sha256:")
    assert fixture_digest.startswith("sha256:")
    assert len(skill_digest) == 71  # sha256: + 64 hex chars
    assert len(fixture_digest) == 71


def test_keyless_unconfigured_model_returns_blocked(mock_skills_env: Dict[str, Path]) -> None:
    """Test that missing model configuration returns BLOCKED without fabricating metrics."""
    adapter = PairedEvalAdapter(
        skills_dir=mock_skills_env["skills_dir"],
        baselines_dir=mock_skills_env["baselines_dir"],
        agent_cmd=None,
    )

    report = adapter.evaluate_skill_paired("sample-skill")

    summary = report["summary"]
    assert summary["status"] == "BLOCKED"
    assert summary["blocked_cases"] == 3
    assert report["environment"]["provider"] == UNAVAILABLE
    assert report["environment"]["model_id"] == UNAVAILABLE
    assert report["metrics"]["duration_ms"] == UNAVAILABLE
    assert report["metrics"]["total_tokens"] == UNAVAILABLE


def test_paired_run_matching_and_outcomes(mock_skills_env: Dict[str, Path]) -> None:
    """Test paired run matching with simulated mock outcomes."""
    adapter = PairedEvalAdapter(
        skills_dir=mock_skills_env["skills_dir"],
        baselines_dir=mock_skills_env["baselines_dir"],
        agent_cmd="dummy_cmd",
        provider="test-provider",
        model_id="test-model",
    )

    mock_outcomes = {
        1: {
            "with_skill": {"status": "PASS", "assertions": [{"text": "Assertion 1", "passed": True}], "skill_loaded": True},
            "without_skill": {"status": "FAIL", "assertions": [{"text": "Assertion 1", "passed": False}], "skill_loaded": False},
        },
        2: {
            "with_skill": {"status": "PASS", "assertions": [{"text": "Assertion 2", "passed": True}], "skill_loaded": True},
            "without_skill": {"status": "PASS", "assertions": [{"text": "Assertion 2", "passed": True}], "skill_loaded": False},
        },
        3: {
            "with_skill": {"status": "PASS", "assertions": [{"text": "Assertion 3", "passed": True}], "skill_loaded": False},
            "without_skill": {"status": "PASS", "assertions": [{"text": "Assertion 3", "passed": True}], "skill_loaded": False},
        },
    }

    report = adapter.evaluate_skill_paired("sample-skill", mock_outcomes=mock_outcomes)

    summary = report["summary"]
    assert summary["status"] == "PASS"
    assert summary["total_cases"] == 3
    assert summary["passed_cases"] == 3
    assert summary["pass_rate_with_skill"] == 1.0
    assert summary["pass_rate_without_skill"] == pytest.approx(2 / 3)
    assert summary["skill_lift"] == pytest.approx(1 / 3)


def test_negative_case_false_positive_detection(mock_skills_env: Dict[str, Path]) -> None:
    """Test that a negative case fails if the target skill is false-activated/loaded."""
    adapter = PairedEvalAdapter(
        skills_dir=mock_skills_env["skills_dir"],
        baselines_dir=mock_skills_env["baselines_dir"],
        agent_cmd="dummy_cmd",
    )

    mock_outcomes = {
        1: {
            "with_skill": {"status": "PASS", "assertions": [{"text": "Assertion 1", "passed": True}], "skill_loaded": True},
            "without_skill": {"status": "FAIL", "assertions": [{"text": "Assertion 1", "passed": False}], "skill_loaded": False},
        },
        2: {
            "with_skill": {"status": "PASS", "assertions": [{"text": "Assertion 2", "passed": True}], "skill_loaded": True},
            "without_skill": {"status": "FAIL", "assertions": [{"text": "Assertion 2", "passed": False}], "skill_loaded": False},
        },
        3: {
            "with_skill": {"status": "PASS", "assertions": [{"text": "Assertion 3", "passed": True}], "skill_loaded": True},
            "without_skill": {"status": "PASS", "assertions": [{"text": "Assertion 3", "passed": True}], "skill_loaded": False},
        },
    }

    report = adapter.evaluate_skill_paired("sample-skill", mock_outcomes=mock_outcomes)

    summary = report["summary"]
    assert summary["status"] == "FAIL"
    case_3 = report["cases"][2]
    assert case_3["with_skill"]["status"] == "FAIL"
    assert "False positive" in case_3["with_skill"]["assertions"][-1]["evidence"]


def test_baseline_drift_and_blessing_flow(mock_skills_env: Dict[str, Path]) -> None:
    """Test baseline comparison, regression detection, and explicit blessing."""
    adapter = PairedEvalAdapter(
        skills_dir=mock_skills_env["skills_dir"],
        baselines_dir=mock_skills_env["baselines_dir"],
        agent_cmd="dummy_cmd",
    )

    mock_outcomes_passing = {
        1: {"with_skill": {"status": "PASS", "assertions": [{"text": "A1", "passed": True}], "skill_loaded": True}},
        2: {"with_skill": {"status": "PASS", "assertions": [{"text": "A2", "passed": True}], "skill_loaded": True}},
        3: {"with_skill": {"status": "PASS", "assertions": [{"text": "A3", "passed": True}], "skill_loaded": False}},
    }
    report_passing = adapter.evaluate_skill_paired("sample-skill", mock_outcomes=mock_outcomes_passing)
    assert report_passing["summary"]["status"] == "PASS"

    blessed_file = adapter.bless_baseline("sample-skill", report_passing)
    assert blessed_file.exists()

    mock_outcomes_degraded = {
        1: {"with_skill": {"status": "FAIL", "assertions": [{"text": "A1", "passed": False}], "skill_loaded": True}},
        2: {"with_skill": {"status": "PASS", "assertions": [{"text": "A2", "passed": True}], "skill_loaded": True}},
        3: {"with_skill": {"status": "PASS", "assertions": [{"text": "A3", "passed": True}], "skill_loaded": False}},
    }
    report_degraded = adapter.evaluate_skill_paired("sample-skill", mock_outcomes=mock_outcomes_degraded)

    comp = report_degraded["summary"]["baseline_comparison"]
    assert comp["blessed_baseline_found"] is True
    assert comp["regression_detected"] is True
    assert report_degraded["summary"]["status"] == "FAIL"


def test_malformed_evals_json_handling(mock_skills_env: Dict[str, Path]) -> None:
    """Test that malformed evals.json is handled gracefully without crashing."""
    evals_file = mock_skills_env["evals_file"]
    evals_file.write_text("INVALID JSON {{{", encoding="utf-8")

    adapter = PairedEvalAdapter(
        skills_dir=mock_skills_env["skills_dir"],
        baselines_dir=mock_skills_env["baselines_dir"],
    )

    report = adapter.evaluate_skill_paired("sample-skill")
    assert report["summary"]["status"] == "FAIL"
    assert len(report["summary"]["errors"]) > 0
