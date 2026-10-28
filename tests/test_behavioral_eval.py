"""End-to-end tests for scripts/behavioral-eval.py using a deterministic stub adapter."""

import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
CLI = REPO_ROOT / "scripts" / "behavioral-eval.py"
STUB = REPO_ROOT / "tests" / "fixtures" / "behavioral" / "stub_adapter.py"
SKILL = "skill-evaluator"
SCHEMA_VERSION = "behavioral-eval/v1"


def run_cli(*args, stub_mode=None, adapter=True):
    env = os.environ.copy()
    env.pop("BEHAVIORAL_EVAL_ADAPTER", None)
    env.pop("BEHAVIORAL_EVAL_PROVIDER_NAME", None)
    env.pop("BEHAVIORAL_EVAL_PROVIDER_MODEL", None)
    env["STUB_MODE"] = stub_mode or "ok"
    command = [sys.executable, str(CLI), *args]
    if adapter and args[0] == "run":
        command += ["--adapter-command", f"{sys.executable} {STUB}"]
    return subprocess.run(command, cwd=REPO_ROOT, capture_output=True, text=True, env=env, timeout=120)


def report_from(result):
    return json.loads(result.stdout)


def test_plan_withholds_prompts_and_withholds_expected_output(tmp_path):
    out = tmp_path / "plan"
    result = run_cli("plan", "--skill", SKILL, "--cases", "1,4", "--output-dir", str(out))
    assert result.returncode == 0, result.stderr
    plan = json.loads((out / "plan.json").read_text(encoding="utf-8"))
    assert plan["prompt_capture"] == "withheld"
    assert len(plan["tasks"]) == 4
    for case in plan["cases"]:
        assert "prompt" not in case
        assert "expected_output" not in case
        assert case["prompt_digest"].startswith("sha256:")


def test_plan_rejects_unknown_case_id(tmp_path):
    result = run_cli("plan", "--skill", SKILL, "--cases", "9999", "--output-dir", str(tmp_path))
    assert result.returncode == 2
    assert "unknown case id" in result.stderr


def test_run_without_adapter_is_blocked_not_passing(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out), adapter=False)
    assert result.returncode == 3, result.stdout + result.stderr
    report = json.loads((out / "report.json").read_text(encoding="utf-8"))
    assert report["configurations"]["with_skill"]["cases_graded"] == 0
    assert report["configurations"]["with_skill"]["cases_not_run"] == 1
    assert report["baseline"]["status"] == "not_blessed"
    assert "BLOCKED: no adapter configured" in result.stdout


def test_run_with_stub_adapter_grades_both_configurations(tmp_path):
    out = tmp_path / "run"
    result = run_cli(
        "run", "--skill", SKILL, "--cases", "1,4", "--output-dir", str(out),
        "--provider-name", "stub", "--provider-model", "stub-1", "--format", "json",
        stub_mode="ok",
    )
    assert result.returncode == 0, result.stdout + result.stderr
    report = report_from(result)
    assert report["configurations"]["with_skill"]["cases_passed"] == 2
    assert report["configurations"]["without_skill"]["cases_passed"] == 2
    assert report["configurations"]["with_skill"]["measurements"]["total_tokens"]["available"] is True
    assert report["provider"]["observed"] is True
    assert report["baseline"]["status"] == "not_blessed"
    # A run may not invent an accepted baseline.
    assert not (out / "candidate-baseline.json").exists()
    assert (out / "tasks" / "case-1" / "with_skill" / "result.json").is_file()


def test_run_failing_assertion_exits_findings(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                     "--format", "json", stub_mode="fail")
    assert result.returncode == 1, result.stdout + result.stderr
    report = report_from(result)
    assert report["configurations"]["with_skill"]["cases_failed"] == 1
    assert any("assertion(s) failed" in reason for reason in report["cases"][0]["reasons"])


def test_run_malformed_adapter_output_is_a_contract_error(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                     "--format", "json", stub_mode="malformed")
    assert result.returncode == 2, result.stdout + result.stderr
    report = report_from(result)
    assert report["contract_errors"]
    assert "not a single JSON object" in report["contract_errors"][0]


def test_run_crashing_adapter_is_a_contract_error(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                     "--format", "json", stub_mode="crash")
    assert result.returncode == 2, result.stdout + result.stderr
    report = report_from(result)
    assert "no output" in report["contract_errors"][0]


def test_blocked_adapter_result_is_not_counted_as_passing(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                     "--format", "json", stub_mode="blocked")
    assert result.returncode == 3, result.stdout + result.stderr
    report = report_from(result)
    assert report["configurations"]["with_skill"]["cases_graded"] == 0
    assert report["configurations"]["with_skill"]["cases_blocked"] == 1


def test_unobserved_activation_blocks_instead_of_passing(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                     "--format", "json", stub_mode="no_activation")
    assert result.returncode == 3, result.stdout + result.stderr
    report = report_from(result)
    assert report["cases"][0]["verdict"] == "blocked"


def test_negative_case_detects_false_activation(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "11", "--output-dir", str(out),
                     "--format", "json", stub_mode="negative_trigger")
    assert result.returncode == 1, result.stdout + result.stderr
    report = report_from(result)
    assert report["cases"][0]["verdict"] == "fail"
    assert any("false activation" in reason for reason in report["cases"][0]["reasons"])


def test_negative_case_passes_when_skill_stays_unloaded(tmp_path):
    out = tmp_path / "run"
    result = run_cli("run", "--skill", SKILL, "--cases", "11", "--output-dir", str(out),
                     "--format", "json", stub_mode="ok")
    assert result.returncode == 0, result.stdout + result.stderr
    report = report_from(result)
    assert report["cases"][0]["verdict"] == "pass"


def test_bless_requires_accept_and_never_overwrites_silently(tmp_path):
    out = tmp_path / "run"
    baseline = tmp_path / "baseline.json"
    run = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                  "--baseline", str(baseline), "--format", "json", stub_mode="ok")
    assert run.returncode == 0, run.stdout + run.stderr
    assert not baseline.exists()

    refused = run_cli("bless", "--skill", SKILL, "--report", str(out / "report.json"),
                      "--baseline", str(baseline))
    assert refused.returncode == 1, refused.stdout + refused.stderr
    assert not baseline.exists()
    assert (tmp_path / "baseline.candidate.json").is_file()

    unattributed = run_cli("bless", "--skill", SKILL, "--report", str(out / "report.json"),
                           "--baseline", str(baseline), "--accept")
    assert unattributed.returncode == 2
    assert not baseline.exists()

    accepted = run_cli("bless", "--skill", SKILL, "--report", str(out / "report.json"),
                       "--baseline", str(baseline), "--accept", "--blessed-by", "reviewer",
                       "--note", "pilot acceptance")
    assert accepted.returncode == 0, accepted.stdout + accepted.stderr
    blessed = json.loads(baseline.read_text(encoding="utf-8"))
    assert blessed["blessed_by"] == "reviewer"
    assert blessed["schema_version"] == SCHEMA_VERSION
    assert blessed["floors"]["with_skill"]["case_pass_rate"] == 1.0


def test_bless_refuses_a_failing_run(tmp_path):
    out = tmp_path / "run"
    baseline = tmp_path / "baseline.json"
    run = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                  "--format", "json", stub_mode="fail")
    assert run.returncode == 1
    refused = run_cli("bless", "--skill", SKILL, "--report", str(out / "report.json"),
                      "--baseline", str(baseline), "--accept", "--blessed-by", "reviewer")
    assert refused.returncode == 2
    assert "cannot bless" in refused.stderr
    assert not baseline.exists()


def test_compare_reports_a_regression_against_a_blessed_floor(tmp_path):
    out = tmp_path / "run"
    baseline = tmp_path / "baseline.json"
    baseline.write_text(json.dumps({
        "schema_version": SCHEMA_VERSION,
        "skill_name": SKILL,
        "blessed_at": "2026-01-01T00:00:00Z",
        "blessed_by": "reviewer",
        "skill_digest": "sha256:older-revision",
        "fixture_digest": "no-fixtures",
        "case_ids": [1],
        "observed": {"with_skill": {"case_pass_rate": 1.0, "assertion_pass_rate": 1.0}},
        "floors": {"with_skill": {"case_pass_rate": 1.0, "assertion_pass_rate": 1.0}},
    }), encoding="utf-8")
    run = run_cli("run", "--skill", SKILL, "--cases", "1", "--output-dir", str(out),
                  "--baseline", str(baseline), "--format", "json", stub_mode="degraded")
    assert run.returncode == 1, run.stdout + run.stderr
    report = report_from(run)
    assert report["baseline"]["status"] == "regression"
    assert report["baseline"]["skill_revision_changed"] is True
    assert (out / "candidate-baseline.json").is_file()

    compare = run_cli("compare", "--skill", SKILL, "--report", str(out / "report.json"),
                      "--baseline", str(baseline), "--format", "json")
    assert compare.returncode == 1
    assert json.loads(compare.stdout)["status"] == "regression"


@pytest.mark.parametrize("command", ["compare", "bless"])
def test_compare_and_bless_require_an_existing_report(tmp_path, command):
    args = [command, "--skill", SKILL, "--report", str(tmp_path / "missing.json")]
    if command == "bless":
        args += ["--accept", "--blessed-by", "reviewer"]
    result = run_cli(*args)
    assert result.returncode == 2
    assert "report not found" in result.stderr
