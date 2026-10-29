"""Contract tests for `behavioral-eval/v1` (no model, no network)."""

import importlib.util
import json
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"
sys.path.append(str(SCRIPTS_DIR))

spec = importlib.util.spec_from_file_location(
    "behavioral_contract", SCRIPTS_DIR / "lib" / "behavioral_contract.py"
)
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)

scoring_spec = importlib.util.spec_from_file_location(
    "behavioral_scoring", SCRIPTS_DIR / "lib" / "behavioral_scoring.py"
)
scoring = importlib.util.module_from_spec(scoring_spec)
sys.path.append(str(SCRIPTS_DIR / "lib"))
scoring_spec.loader.exec_module(scoring)

SKILL = REPO_ROOT / ".agents" / "skills" / "skill-evaluator"


def graded(case_id=1, configuration="with_skill", results=None, loaded=True, usage=True):
    return {
        "schema_version": contract.SCHEMA_VERSION,
        "skill_name": "skill-evaluator",
        "case_id": case_id,
        "configuration": configuration,
        "status": "graded",
        "assertion_results": results or [
            {"text": "An assertion", "result": "pass", "evidence": "quoted output"},
        ],
        "activation": {"skill_loaded": loaded, "evidence": "routing evidence"},
        "duration_ms": 10,
        "usage": {"total_tokens": 5, "cost_usd": 0.01, "source": "test"} if usage else None,
    }


def test_load_cases_reads_real_skill_fixtures():
    cases = contract.load_cases(SKILL)
    assert len(cases) >= 3
    assert all(case["assertions"] for case in cases)
    ids = [case["id"] for case in cases]
    assert len(ids) == len(set(ids)), "case ids must be unique"


def test_select_cases_rejects_unknown_ids():
    cases = contract.load_cases(SKILL)
    with pytest.raises(contract.ContractError):
        contract.select_cases(cases, [9999])


def test_skill_digest_tracks_content_changes(tmp_path):
    skill = tmp_path / "demo"
    (skill / "evals").mkdir(parents=True)
    (skill / "SKILL.md").write_text("one\n", encoding="utf-8")
    (skill / "evals" / "evals.json").write_text("{}", encoding="utf-8")
    first = contract.skill_digest(skill)
    (skill / "SKILL.md").write_text("two\n", encoding="utf-8")
    assert contract.skill_digest(skill) != first
    baseline = skill / "evals" / contract.BASELINE_FILENAME
    before_baseline = contract.skill_digest(skill)
    baseline.write_text("{}", encoding="utf-8")
    # Blessing a baseline must not silently change the skill revision digest.
    assert contract.skill_digest(skill) == before_baseline


def test_fixture_digest_reports_missing_fixture(tmp_path):
    skill = tmp_path / "demo"
    skill.mkdir()
    cases = [{"id": 1, "files": ["evals/files/nope.txt"]}]
    with pytest.raises(contract.ContractError):
        contract.fixture_digest(skill, cases)
    assert contract.fixture_digest(skill, [{"id": 1, "files": []}]) == contract.NO_FIXTURES


def test_redact_removes_credentials_and_email():
    text = "token=abcdef123456 and sk-abcdefghijklmnopqrstuvwx user@example.com"
    redacted = contract.redact(text)
    assert "abcdef123456" not in redacted
    assert "sk-abcdefghijklmnopqrstuvwx" not in redacted
    assert "user@example.com" not in redacted


@pytest.mark.parametrize(
    "mutate,expected",
    [
        (lambda doc: doc.update(schema_version="v0"), "schema_version"),
        (lambda doc: doc.update(skill_name="other"), "skill_name"),
        (lambda doc: doc.update(case_id=99), "case_id"),
        (lambda doc: doc.update(status="maybe"), "status"),
        (lambda doc: doc.pop("activation"), "activation"),
        (lambda doc: doc.update(assertion_results=[]), "assertion_results"),
        (lambda doc: doc.update(assertion_results=[{"text": "x", "result": "skip", "evidence": "y"}]),
         "result must be one of"),
    ],
)
def test_validate_result_rejects_malformed_documents(mutate, expected):
    doc = graded()
    mutate(doc)
    issues = contract.validate_result(doc, "skill-evaluator", {1})
    assert any(expected in issue for issue in issues), issues


def test_validate_result_requires_reason_for_blocked():
    doc = {"schema_version": contract.SCHEMA_VERSION, "skill_name": "skill-evaluator",
           "case_id": 1, "configuration": "with_skill", "status": "blocked"}
    assert any("reason" in issue for issue in contract.validate_result(doc, "skill-evaluator", {1}))


def test_validate_usage_rejects_fabricated_shapes():
    assert contract.validate_usage({"total_tokens": "lots"})
    assert contract.validate_usage({"cost_usd": -1})
    assert contract.validate_usage(None) == []


def test_negative_case_false_activation_fails():
    case = {"id": 4, "bucket": "negative", "assertions": ["Unrelated"], "files": []}
    scored = scoring.score_case(
        case,
        {"with_skill": graded(case_id=4, loaded=True), "without_skill": graded(case_id=4, loaded=False)},
    )
    assert scored["verdict"] == "fail"
    assert any("false activation" in reason for reason in scored["reasons"])


def test_negative_case_unobserved_activation_is_blocked():
    case = {"id": 4, "bucket": "negative", "assertions": ["Unrelated"], "files": []}
    scored = scoring.score_case(
        case,
        {"with_skill": graded(case_id=4, loaded=None), "without_skill": graded(case_id=4, loaded=False)},
    )
    assert scored["verdict"] == "blocked"


def test_missing_baseline_side_makes_pair_not_run():
    case = {"id": 1, "bucket": "explicit", "assertions": ["A"], "files": []}
    scored = scoring.score_case(case, {"with_skill": graded()})
    assert scored["verdict"] == "not_run"
    assert any("without_skill" in reason for reason in scored["reasons"])


def test_missing_with_skill_side_makes_pair_not_run():
    case = {"id": 1, "bucket": "explicit", "assertions": ["A"], "files": []}
    scored = scoring.score_case(
        case, {"without_skill": graded(configuration="without_skill", loaded=False)}
    )
    assert scored["verdict"] == "not_run"


def test_with_skill_configuration_must_observe_activation():
    case = {"id": 1, "bucket": "explicit", "assertions": ["A"], "files": []}
    scored = scoring.score_case(
        case,
        {"with_skill": graded(loaded=False), "without_skill": graded(configuration="without_skill", loaded=False)},
    )
    assert scored["verdict"] == "blocked"


def test_aggregate_excludes_blocked_and_marks_unavailable_measurements():
    case = {"id": 1, "bucket": "explicit", "assertions": ["A"], "files": []}
    results = [
        graded(usage=False),
        graded(configuration="without_skill", usage=False),
    ]
    scored = scoring.score_case(
        case,
        {"with_skill": results[0], "without_skill": results[1]},
    )
    report = scoring.aggregate([scored], results)
    summary = report["configurations"]["with_skill"]
    assert summary["cases_graded"] == 1
    assert summary["measurements"]["total_tokens"]["available"] is False
    assert summary["measurements"]["total_tokens"]["value"] is None
    assert summary["measurements"]["duration_ms"]["available"] is True


def test_compare_to_baseline_detects_regression():
    case = {"id": 1, "bucket": "explicit", "assertions": ["A"], "files": []}
    failing = graded(results=[{"text": "A", "result": "fail", "evidence": "no"}])
    scored = scoring.score_case(
        case,
        {"with_skill": failing, "without_skill": graded(configuration="without_skill")},
    )
    report = scoring.aggregate([scored], [failing])
    report["skill"] = {"digest": "sha256:new"}
    report["fixtures"] = {"digest": "sha256:fix"}
    baseline = {
        "skill_digest": "sha256:old",
        "fixture_digest": "sha256:fix",
        "blessed_at": "2026-01-01T00:00:00Z",
        "blessed_by": "reviewer",
        "case_ids": [1],
        "observed": {"with_skill": {"case_pass_rate": 1.0, "assertion_pass_rate": 1.0}},
        "floors": {"with_skill": {"case_pass_rate": 1.0, "assertion_pass_rate": 1.0}},
    }
    comparison = scoring.compare_to_baseline(report, baseline)
    assert comparison["status"] == "regression"
    assert comparison["skill_revision_changed"] is True
    assert comparison["regressions"][0]["metric"] == "case_pass_rate"


def test_compare_to_baseline_insufficient_evidence_when_nothing_graded():
    case = {"id": 1, "bucket": "explicit", "assertions": ["A"], "files": []}
    scored = scoring.score_case(case, {})
    report = scoring.aggregate([scored], [])
    comparison = scoring.compare_to_baseline(report, {"case_ids": [1], "floors": {}, "observed": {}})
    assert comparison["status"] == "insufficient_evidence"


def test_validate_baseline_rejects_incomplete_documents():
    issues = scoring.validate_baseline({"schema_version": contract.SCHEMA_VERSION}, "skill-evaluator")
    assert len(issues) >= 3


def test_build_baseline_candidate_records_floors_and_provenance():
    case = {"id": 1, "bucket": "explicit", "assertions": ["A"], "files": []}
    results = [graded(), graded(configuration="without_skill")]
    scored = scoring.score_case(
        case, {"with_skill": results[0], "without_skill": results[1]}
    )
    report = scoring.aggregate([scored], results)
    candidate = scoring.build_baseline_candidate(
        report, {"name": "skill-evaluator", "digest": "sha256:s", "fixture_digest": "sha256:f"},
        blessed_by="reviewer", blessed_at="2026-01-01T00:00:00Z",
    )
    assert candidate["floors"]["with_skill"]["case_pass_rate"] == 1.0
    assert candidate["case_ids"] == [1]
    assert json.loads(json.dumps(candidate))["blessed_by"] == "reviewer"
