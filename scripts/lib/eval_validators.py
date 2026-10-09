"""Validation logic for eval structure and format."""

from __future__ import annotations

import json
from pathlib import Path, PureWindowsPath

from lib.eval_types import EVAL_BUCKETS, EvalResult, EvalStatus

# Contract mirrored by the independently distributed skill-evaluator checker.
# A regression test pins both constants without coupling the standalone skill.
MIN_EVAL_CASES = 3


def load_evals_file(evals_path: Path) -> tuple[dict | None, str | None]:
    """Load and parse an evals.json file."""
    try:
        data = json.loads(evals_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None, f"File not found: {evals_path}"
    except json.JSONDecodeError as exc:
        return None, f"Invalid JSON: {exc.msg} at line {exc.lineno}"
    except Exception as exc:
        return None, f"Error reading file: {exc}"
    return data, None


def _validate_eval_case(
    eval_case: dict, idx: int, required_fields: set[str], skill_path: Path | None = None
) -> list[str]:
    """Validate a single eval case entry."""
    issues: list[str] = []
    if not isinstance(eval_case, dict):
        issues.append(f"Eval #{idx} is not an object")
        return issues
    missing = required_fields - set(eval_case.keys())
    if missing:
        issues.append(f"Eval #{idx} missing fields: {', '.join(sorted(missing))}")
    if "id" in eval_case and type(eval_case["id"]) is not int:
        issues.append(f"Eval #{idx}: 'id' must be an integer (not a boolean)")
    for field in ("prompt", "expected_output"):
        if field in eval_case and (
            not isinstance(eval_case[field], str) or not eval_case[field].strip()
        ):
            issues.append(f"Eval #{idx}: '{field}' must be a non-empty string")
    _validate_assertions(eval_case, idx, issues)
    _validate_bucket(eval_case, idx, issues)
    _validate_files(eval_case, idx, issues, skill_path)
    return issues


def _validate_assertions(eval_case: dict, idx: int, issues: list[str]) -> None:
    """Validate assertions field in an eval case."""
    if "assertions" not in eval_case:
        return
    assertions = eval_case["assertions"]
    if not isinstance(assertions, list):
        issues.append(f"Eval #{idx}: 'assertions' must be an array")
    elif len(assertions) == 0:
        issues.append(f"Eval #{idx}: 'assertions' array is empty")
    elif not all(isinstance(assertion, str) and assertion.strip() for assertion in assertions):
        issues.append(f"Eval #{idx}: 'assertions' must contain only non-empty strings")


def _validate_bucket(eval_case: dict, idx: int, issues: list[str]) -> None:
    """Validate the optional bucket field.

    Absent buckets are valid, so existing evals are not retrofitted. Present
    values must be known buckets; validate_evals_format additionally requires a
    negative case whenever any case declares a bucket.
    """
    if "bucket" not in eval_case:
        return
    bucket = eval_case["bucket"]
    if not isinstance(bucket, str) or bucket not in EVAL_BUCKETS:
        issues.append(
            f"Eval #{idx}: 'bucket' must be one of {sorted(EVAL_BUCKETS)}"
        )


def _validate_files(
    eval_case: dict, idx: int, issues: list[str], skill_path: Path | None = None
) -> None:
    """Validate files field in an eval case."""
    if "files" not in eval_case:
        return
    files = eval_case["files"]
    if not isinstance(files, list):
        issues.append(f"Eval #{idx}: 'files' must be an array")
    elif not all(isinstance(f, str) for f in files):
        issues.append(f"Eval #{idx}: all 'files' must be strings")
    else:
        for name in files:
            path = Path(name)
            windows_path = PureWindowsPath(name)
            if (not name.strip() or path.is_absolute() or windows_path.drive
                    or windows_path.root or ".." in path.parts or "\\" in name or "\x00" in name):
                issues.append(f"Eval #{idx}: files[] entry {name!r} must stay under the skill root")
                continue
            if skill_path is not None:
                try:
                    root = skill_path.resolve()
                    target = (root / path).resolve()
                    target.relative_to(root)
                except (ValueError, OSError, RuntimeError):
                    issues.append(f"Eval #{idx}: files[] entry {name!r} escapes the skill root")
                    continue
                if not target.is_file():
                    issues.append(f"Eval #{idx}: files[] entry {name!r} does not exist under the skill root")


def validate_evals_format(
    data: dict, skill_name: str, skill_path: Path | None = None
) -> list[str]:
    """Validate the evals.json format."""
    issues: list[str] = []
    if not isinstance(data, dict):
        return ["evals.json must be an object"]
    if "skill_name" not in data:
        issues.append("Missing required field: 'skill_name'")
    elif not isinstance(data["skill_name"], str) or not data["skill_name"].strip():
        issues.append("'skill_name' must be a non-empty string")
    elif data.get("skill_name") != skill_name:
        issues.append(
            f"Skill name mismatch: expected '{skill_name}', "
            f"got '{data.get('skill_name')}'"
        )
    if "evals" not in data:
        issues.append("Missing required field: 'evals'")
        return issues
    evals = data.get("evals")
    if not isinstance(evals, list):
        issues.append("'evals' must be an array")
        return issues
    if len(evals) == 0:
        issues.append("'evals' array is empty")
    if len(evals) < MIN_EVAL_CASES:
        issues.append(f"'evals' must contain at least {MIN_EVAL_CASES} cases (found {len(evals)})")
    required_fields = {"id", "prompt", "expected_output", "assertions"}
    seen_ids: set[int] = set()
    for idx, eval_case in enumerate(evals, start=1):
        issues.extend(_validate_eval_case(eval_case, idx, required_fields, skill_path))
        if not isinstance(eval_case, dict):
            continue
        case_id = eval_case.get("id")
        if type(case_id) is int:
            if case_id in seen_ids:
                issues.append(f"Eval #{idx}: duplicate id {case_id}")
            seen_ids.add(case_id)
    buckets = [case["bucket"] for case in evals if isinstance(case, dict) and "bucket" in case]
    if buckets and "negative" not in buckets:
        issues.append(
            "buckets declared but none tagged 'negative'; add an "
            "out-of-scope case that must leave the skill unloaded"
        )
    return issues


def run_structure_check(skill_path: Path) -> EvalResult:
    """Run structure check validation for a skill."""
    issues: list[str] = []
    if not (skill_path / "SKILL.md").is_file():
        issues.append("Missing required file: SKILL.md")
    if (skill_path / skill_path.name).is_dir():
        issues.append(f"Nested duplicate directory: {skill_path.name}/{skill_path.name}/")
    evals_path = skill_path / "evals" / "evals.json"
    if evals_path.exists():
        data, error = load_evals_file(evals_path)
        if error:
            issues.append(f"evals.json error: {error}")
        else:
            format_issues = validate_evals_format(data, skill_path.name, skill_path)
            issues.extend(format_issues)
    else:
        issues.append("Missing required file: evals/evals.json")
    if issues:
        return EvalResult(
            eval_id=0, status=EvalStatus.FAIL,
            message="Structure check failed", details=issues
        )
    return EvalResult(
        eval_id=0, status=EvalStatus.PASS,
        message="Structure check passed",
        details=["SKILL.md exists", "evals.json is valid"]
    )
