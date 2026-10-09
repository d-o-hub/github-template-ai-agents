"""Contract tests for the standalone, static-only skill structure checker."""
import importlib.util
import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SKILLS_ROOT = REPO_ROOT / ".agents" / "skills"
CHECKER_PATH = SKILLS_ROOT / "skill-evaluator" / "scripts" / "check_structure.py"
SPEC = importlib.util.spec_from_file_location("standalone_skill_structure", CHECKER_PATH)
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def eval_data(count=3):
    return {
        "skill_name": "test-skill",
        "evals": [
            {
                "id": idx,
                "prompt": "Check a local example",
                "expected_output": "A concrete local result",
                "assertions": ["The result names the checked file"],
                "files": [],
            }
            for idx in range(1, count + 1)
        ],
    }


def make_skill(tmp_path, data=None):
    skill = tmp_path / "test-skill"
    skill.mkdir()
    (skill / "SKILL.md").write_text("# Test skill\n", encoding="utf-8")
    (skill / "evals").mkdir()
    (skill / "evals" / "evals.json").write_text(
        json.dumps(eval_data() if data is None else data), encoding="utf-8"
    )
    return skill


def run_cli(path, script=CHECKER_PATH):
    return subprocess.run(
        [sys.executable, "-I", str(script), "--path", str(path)],
        capture_output=True, text=True, check=False,
    )


@pytest.mark.parametrize("count,passes", [(0, False), (1, False), (2, False), (3, True)])
def test_minimum_case_contract(tmp_path, count, passes):
    assert checker.MIN_EVAL_CASES == 3
    skill = make_skill(tmp_path, eval_data(count))
    result = checker.check_skill(skill)
    assert (result["status"] == "PASS") is passes
    assert (run_cli(skill).returncode == 0) is passes
    if not passes:
        assert any("require at least 3" in issue for issue in result["issues"])


@pytest.mark.parametrize("remove_dir", [False, True])
def test_missing_evals_fails(tmp_path, remove_dir):
    skill = make_skill(tmp_path)
    if remove_dir:
        shutil.rmtree(skill / "evals")
    else:
        (skill / "evals" / "evals.json").unlink()
    result = checker.check_skill(skill)
    assert result["status"] != "PASS"
    assert "missing evals/evals.json" in result["issues"]
    assert run_cli(skill).returncode == 1


@pytest.mark.parametrize("payload", [b"{", b"", b"[]", b"null", b'"text"', b"\xff"])
def test_malformed_json_fails_without_traceback(tmp_path, payload):
    skill = make_skill(tmp_path)
    (skill / "evals" / "evals.json").write_bytes(payload)
    result = checker.check_skill(skill)
    assert result["status"] != "PASS"
    completed = run_cli(skill)
    assert completed.returncode == 1
    assert "Traceback" not in completed.stdout + completed.stderr


@pytest.mark.parametrize("field,value", [
    ("skill_name", None), ("skill_name", []), ("skill_name", "wrong-name"),
    ("evals", None), ("evals", {}), ("evals", [None, [], "case"]),
])
def test_malformed_top_level_fields(tmp_path, field, value):
    data = eval_data()
    data[field] = value
    skill = make_skill(tmp_path, data)
    assert checker.check_skill(skill)["status"] != "PASS"
    completed = run_cli(skill)
    assert completed.returncode == 1
    assert "Traceback" not in completed.stderr


@pytest.mark.parametrize("field,value", [
    ("id", True), ("id", "1"), ("id", 1.0), ("id", []),
    ("prompt", " "), ("prompt", {}), ("expected_output", None),
    ("assertions", []), ("assertions", "text"), ("assertions", [""]),
    ("assertions", [42]), ("assertions", [{"text": "claim"}]),
    ("files", None), ("files", "input.txt"), ("files", [""]),
    ("files", [42]), ("files", [{"path": "input.txt"}]),
    ("bucket", {}), ("bucket", []), ("bucket", None), ("bucket", "unknown"),
])
def test_malformed_case_fields(tmp_path, field, value):
    data = eval_data()
    data["evals"][0][field] = value
    skill = make_skill(tmp_path, data)
    result = checker.check_skill(skill)
    assert result["status"] != "PASS"
    assert any(field in issue for issue in result["issues"])
    completed = run_cli(skill)
    assert completed.returncode == 1
    assert "Traceback" not in completed.stdout + completed.stderr


@pytest.mark.parametrize("field", ["id", "prompt", "expected_output", "assertions"])
def test_missing_case_fields(tmp_path, field):
    data = eval_data()
    del data["evals"][0][field]
    skill = make_skill(tmp_path, data)
    issues = checker.check_skill(skill)["issues"]
    assert any("missing fields" in issue and field in issue for issue in issues)


def test_duplicate_ids_fail(tmp_path):
    data = eval_data()
    data["evals"][1]["id"] = data["evals"][0]["id"]
    skill = make_skill(tmp_path, data)
    assert any("duplicate id" in issue for issue in checker.check_skill(skill)["issues"])


@pytest.mark.parametrize("field", ["skill_name", "evals"])
def test_missing_top_level_fields_fail(tmp_path, field):
    data = eval_data()
    del data[field]
    skill = make_skill(tmp_path, data)
    assert checker.check_skill(skill)["status"] != "PASS"
    assert run_cli(skill).returncode == 1


@pytest.mark.parametrize("fixture", ["missing.txt", "../outside.txt", "/input.txt", "evals"])
def test_missing_or_escaping_fixtures_fail(tmp_path, fixture):
    data = eval_data()
    data["evals"][0]["files"] = [fixture]
    skill = make_skill(tmp_path, data)
    (tmp_path / "outside.txt").write_text("Outside skill\n", encoding="utf-8")
    assert any("files entry" in issue for issue in checker.check_skill(skill)["issues"])


@pytest.mark.parametrize("fixture", [
    "C:/input.txt", "C:input.txt", "C:", r"C:\input.txt", r"\input.txt",
    r"\\server\share\input.txt", "//server/share/input.txt",
    r"evals\input.txt", r"..\outside.txt", "input\x00.txt",
])
def test_nonportable_fixtures_fail_without_filesystem_resolution(fixture):
    issues = checker.check_files([fixture], 1, None)
    assert any("must stay under the skill root" in issue for issue in issues)


@pytest.mark.skipif(sys.platform != "linux", reason="Proves rejection of Linux-valid literal filenames")
@pytest.mark.parametrize("fixture", ["C:input.txt", r"evals\input.txt"])
def test_windows_style_fixtures_fail_even_when_present_on_linux(tmp_path, fixture):
    data = eval_data()
    data["evals"][0]["files"] = [fixture]
    skill = make_skill(tmp_path, data)
    native_path = skill / fixture
    native_path.write_text("Valid Linux filename, nonportable fixture path\n", encoding="utf-8")
    assert native_path.is_file()
    result = checker.check_skill(skill)
    assert result["status"] != "PASS"
    assert any("must stay under the skill root" in issue for issue in result["issues"])
    completed = run_cli(skill)
    assert completed.returncode == 1
    assert "Traceback" not in completed.stdout + completed.stderr


def test_valid_fixture_and_optional_files_pass(tmp_path):
    data = eval_data()
    data["evals"][0]["files"] = ["input.txt"]
    del data["evals"][1]["files"]
    skill = make_skill(tmp_path, data)
    (skill / "input.txt").write_text("Local fixture\n", encoding="utf-8")
    assert checker.check_skill(skill)["status"] == "PASS"


def test_symlink_fixture_escape_fails(tmp_path):
    data = eval_data()
    data["evals"][0]["files"] = ["input.txt"]
    skill = make_skill(tmp_path, data)
    outside = tmp_path / "outside.txt"
    outside.write_text("Outside\n", encoding="utf-8")
    (skill / "input.txt").symlink_to(outside)
    assert any("skill root" in issue for issue in checker.check_skill(skill)["issues"])


def test_bucket_set_needs_negative_case(tmp_path):
    data = eval_data()
    data["evals"][0]["bucket"] = "contextual"
    skill = make_skill(tmp_path, data)
    assert any("none tagged 'negative'" in issue for issue in checker.check_skill(skill)["issues"])
    data["evals"][1]["bucket"] = "negative"
    (skill / "evals" / "evals.json").write_text(json.dumps(data), encoding="utf-8")
    assert checker.check_skill(skill)["status"] == "PASS"


def test_missing_skill_md_and_nested_duplicate_fail(tmp_path):
    skill = make_skill(tmp_path)
    (skill / "SKILL.md").unlink()
    (skill / skill.name).mkdir()
    issues = checker.check_skill(skill)["issues"]
    assert "missing SKILL.md" in issues
    assert any("nested duplicate" in issue for issue in issues)


def test_read_error_is_reported(tmp_path, monkeypatch):
    def deny_read(*args, **kwargs):
        raise PermissionError("access denied")
    monkeypatch.setattr(Path, "read_text", deny_read)
    data, error = checker.load_evals(tmp_path / "evals.json")
    assert data is None
    assert "access denied" in error


def test_inventory_skips_non_skills_and_workspace_folders(tmp_path):
    skill = make_skill(tmp_path)
    for name in ("notes", "test-workspace", "_support"):
        folder = tmp_path / name
        folder.mkdir()
        if name != "notes":
            (folder / "SKILL.md").write_text("Not an active skill\n", encoding="utf-8")
    assert checker.skill_inventory(tmp_path) == [skill]
    completed = run_cli(tmp_path)
    assert completed.returncode == 0
    assert "Checked 1 skills" in completed.stdout


def test_empty_inventory_fails(tmp_path):
    (tmp_path / "_support").mkdir()
    completed = run_cli(tmp_path)
    assert completed.returncode == 1
    assert "No skills found" in completed.stdout


def test_missing_inventory_fails(tmp_path):
    assert run_cli(tmp_path / "absent").returncode == 1


def test_checker_ships_standalone_and_reports_static_scope(tmp_path):
    standalone = tmp_path / "check_structure.py"
    shutil.copyfile(CHECKER_PATH, standalone)
    skill = make_skill(tmp_path)
    completed = run_cli(skill, standalone)
    assert completed.returncode == 0, completed.stdout + completed.stderr
    assert "(static)" in completed.stdout
    assert "behavioral evaluation: not run" in completed.stdout
    assert checker.check_skill(skill)["scope"] == "static"


def test_real_canonical_corpus_passes_static_contract():
    inventory = checker.skill_inventory(SKILLS_ROOT)
    assert inventory, "Real canonical inventory must not be empty"
    failures = {
        skill.name: result["issues"] for skill in inventory
        if (result := checker.check_skill(skill))["status"] != "PASS"
    }
    assert not failures, failures


@pytest.mark.parametrize("name", ["skill-creator", "jules-delegator", "voice-profiles"])
def test_reviewed_eval_sets_have_minimum_assertion_counts_and_buckets(name):
    data = json.loads((SKILLS_ROOT / name / "evals" / "evals.json").read_text(encoding="utf-8"))
    assert all(len(case["assertions"]) >= 3 for case in data["evals"])
    if name != "skill-creator":
        buckets = {case.get("bucket") for case in data["evals"]}
        assert {"contextual", "negative"} <= buckets
        negative = next(case for case in data["evals"] if case.get("bucket") == "negative")
        assert any("unloaded" in assertion for assertion in negative["assertions"])
