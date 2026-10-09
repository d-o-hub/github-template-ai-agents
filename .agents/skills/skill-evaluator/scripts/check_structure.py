#!/usr/bin/env python3
"""Standalone static audit of skill layout, eval schema, and local fixtures.

No model is invoked and no assertion is scored. PASS means static structure
only, never behavioral quality. Frontmatter belongs to the repository validator.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path, PureWindowsPath

# Local constants: this skill must work when copied outside the repository.
MIN_EVAL_CASES = 3
EVAL_BUCKETS = frozenset({"explicit", "implicit", "contextual", "negative"})
REQUIRED_CASE_FIELDS = ("id", "prompt", "expected_output", "assertions")


def load_evals(evals_path: Path) -> tuple[dict | None, str | None]:
    try:
        data = json.loads(evals_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None, "missing evals/evals.json"
    except (OSError, ValueError, RecursionError) as exc:
        return None, f"cannot read valid evals/evals.json: {exc}"
    if not isinstance(data, dict):
        return None, "evals.json must be a JSON object"
    return data, None


def nonempty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def check_eval_fields(data: object, skill_dir: Path | None = None) -> list[str]:
    if not isinstance(data, dict):
        return ["evals.json must be a JSON object"]
    issues: list[str] = []
    if not nonempty_string(data.get("skill_name")):
        issues.append("skill_name must be a non-empty string")
    elif skill_dir is not None and data["skill_name"] != skill_dir.name:
        issues.append(f"skill_name must match directory name '{skill_dir.name}'")
    evals = data.get("evals")
    if not isinstance(evals, list):
        return issues + ["evals.json missing top-level 'evals' array"]
    if len(evals) < MIN_EVAL_CASES:
        issues.append(
            f"only {len(evals)} eval case(s); require at least {MIN_EVAL_CASES}"
        )
    seen_ids: set[int] = set()
    for idx, case in enumerate(evals, start=1):
        if not isinstance(case, dict):
            issues.append(f"eval #{idx} must be an object")
            continue
        missing = [field for field in REQUIRED_CASE_FIELDS if field not in case]
        if missing:
            issues.append(f"eval #{idx} missing fields: {', '.join(missing)}")
        case_id = case.get("id")
        if type(case_id) is not int:  # bool is not a valid integer identifier.
            issues.append(f"eval #{idx}: id must be an integer")
        elif case_id in seen_ids:
            issues.append(f"eval #{idx}: duplicate id {case_id}")
        else:
            seen_ids.add(case_id)
        for field in ("prompt", "expected_output"):
            if not nonempty_string(case.get(field)):
                issues.append(f"eval #{idx}: {field} must be a non-empty string")
        assertions = case.get("assertions")
        if (not isinstance(assertions, list) or not assertions
                or not all(nonempty_string(item) for item in assertions)):
            issues.append(
                f"eval #{idx}: assertions must be a non-empty array of non-empty strings"
            )
        issues.extend(check_files(case.get("files", []), idx, skill_dir))
    issues.extend(check_eval_buckets(evals))
    return issues


def check_files(files: object, idx: int, skill_dir: Path | None) -> list[str]:
    if not isinstance(files, list) or not all(nonempty_string(f) for f in files):
        return [f"eval #{idx}: files must be an array of non-empty path strings"]
    issues: list[str] = []
    for rel in files:
        path = Path(rel)
        windows_path = PureWindowsPath(rel)
        # Reject nonportable syntax lexically, even when valid as a Linux filename.
        if (path.is_absolute() or windows_path.drive or windows_path.root
                or ".." in path.parts or "\\" in rel or "\x00" in rel):
            issues.append(f"eval #{idx}: files entry {rel!r} must stay under the skill root")
            continue
        if skill_dir is None:
            continue
        try:
            root = skill_dir.resolve()
            fixture = (root / path).resolve()
            if not fixture.is_relative_to(root) or not fixture.is_file():
                issues.append(
                    f"eval #{idx}: files entry '{rel}' must be an existing file under the skill root"
                )
        except (OSError, ValueError, RuntimeError) as exc:
            issues.append(f"eval #{idx}: cannot resolve files entry '{rel}': {exc}")
    return issues


def check_eval_buckets(evals: list) -> list[str]:
    """Buckets are optional; a tagged set must include a negative case."""
    issues: list[str] = []
    declared = []
    for idx, case in enumerate(evals, start=1):
        if not isinstance(case, dict) or "bucket" not in case:
            continue
        bucket = case["bucket"]
        declared.append(bucket)
        if not isinstance(bucket, str) or bucket not in EVAL_BUCKETS:
            issues.append(
                f"eval #{idx}: bucket must be one of {sorted(EVAL_BUCKETS)}"
            )
    if declared and "negative" not in declared:
        issues.append(
            "buckets declared but none tagged 'negative'; add an "
            "out-of-scope case that must leave the skill unloaded"
        )
    return issues


def check_skill(skill_dir: Path) -> dict:
    issues: list[str] = []
    has_skill_md = (skill_dir / "SKILL.md").is_file()
    has_references = (skill_dir / "references").is_dir()
    has_scripts = (skill_dir / "scripts").is_dir()
    has_evals = (skill_dir / "evals").is_dir()
    if (skill_dir / skill_dir.name).is_dir():
        issues.append(
            f"nested duplicate directory present: `{skill_dir.name}/{skill_dir.name}/`"
        )
    if not has_skill_md:
        issues.append("missing SKILL.md")

    # Always load: absence of the entire evals/ directory is a failure too.
    eval_count = 0
    evals_data, evals_error = load_evals(skill_dir / "evals" / "evals.json")
    if evals_error:
        issues.append(evals_error)
    elif evals_data is not None:
        cases = evals_data.get("evals")
        eval_count = len(cases) if isinstance(cases, list) else 0
        issues.extend(check_eval_fields(evals_data, skill_dir))

    return {
        "skill": skill_dir.name,
        "scope": "static",
        "has_skill_md": has_skill_md,
        "has_references": has_references,
        "has_scripts": has_scripts,
        "has_evals": has_evals,
        "eval_count": eval_count,
        "issues": issues,
        "status": "PASS" if not issues else "NEEDS_WORK",
    }


def skill_inventory(skills_dir: Path) -> list[Path]:
    """Ignore workspace/support folders; only SKILL.md directories are skills."""
    return [
        path for path in sorted(skills_dir.iterdir())
        if path.is_dir() and not path.name.startswith("_")
        and not path.name.endswith("-workspace") and (path / "SKILL.md").is_file()
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Static skill structure audit (no model runs)")
    parser.add_argument("--path", default=".agents/skills", help="Skill or skills inventory directory")
    args = parser.parse_args()
    skills_dir = Path(args.path)
    if not skills_dir.is_dir():
        print(f"Skills directory not found: {skills_dir}")
        return 1
    try:
        paths = ([skills_dir] if (skills_dir / "SKILL.md").is_file()
                 else skill_inventory(skills_dir))
        results = [check_skill(path) for path in paths]
    except (OSError, ValueError, RuntimeError) as exc:
        print(f"Cannot audit skills directory {skills_dir}: {exc}")
        return 1
    if not results:
        print(f"No skills found in {skills_dir}; static audit failed")
        return 1

    print("# Static Skill Structure Report\n")
    print("PASS covers layout/schema/fixtures only; behavioral evaluation: not run.\n")
    print(f"Checked {len(results)} skills in `{skills_dir}`\n")
    for result in results:
        print(f"## {result['skill']} -- {result['status']} (static)")
        print(f"- SKILL.md: {'yes' if result['has_skill_md'] else 'no'}")
        print(f"- references/: {'yes' if result['has_references'] else 'no'}")
        print(f"- scripts/: {'yes' if result['has_scripts'] else 'no'}")
        print(f"- evals/: {'yes' if result['has_evals'] else 'no'}")
        print(f"- eval count: {result['eval_count']}")
        if result["issues"]:
            print("- issues:")
            for issue in result["issues"]:
                print(f"  - {issue}")
        print()
    needs_work = [result for result in results if result["status"] != "PASS"]
    print(f"Static summary: {len(results) - len(needs_work)} PASS, {len(needs_work)} NEEDS_WORK")
    return 0 if not needs_work else 1


if __name__ == "__main__":
    sys.exit(main())
