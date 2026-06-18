#!/usr/bin/env python3
"""Package a skill directory into a distributable .skill archive."""
from __future__ import annotations

import argparse
import json
import sys
import tarfile
import tempfile
from pathlib import Path


def validate_skill(skill_path: Path) -> list[str]:
    """Validate skill directory structure.

    Returns a list of issues (empty if valid).
    """
    issues: list[str] = []

    if not skill_path.is_dir():
        issues.append(f"Not a directory: {skill_path}")
        return issues

    skill_md = skill_path / "SKILL.md"
    if not skill_md.is_file():
        issues.append("Missing SKILL.md (required)")

    evals_json = skill_path / "evals" / "evals.json"
    if evals_json.is_file():
        try:
            data = json.loads(evals_json.read_text(encoding="utf-8"))
            if not isinstance(data.get("evals"), list):
                issues.append("evals/evals.json missing 'evals' array")
            elif len(data["evals"]) < 2:
                issues.append(f"evals/evals.json has only {len(data['evals'])} test cases (min 2)")
        except (json.JSONDecodeError, IOError) as exc:
            issues.append(f"Invalid evals/evals.json: {exc}")

    # Additional optional directory checks
    for subdir_name in ("scripts", "references", "assets", "agents", "eval-viewer"):
        subdir = skill_path / subdir_name
        if subdir.is_dir() and not any(subdir.iterdir()):
            issues.append(f"Empty directory: {subdir_name}/")

    return issues


def package_skill(skill_path: Path, output_path: Path | None = None) -> Path:
    """Package skill directory into a .skill tar.gz archive."""
    if output_path is None:
        output_path = skill_path.parent / f"{skill_path.name}.skill"

    with tarfile.open(output_path, "w:gz") as tar:
        tar.add(skill_path, arcname=skill_path.name)

    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Package a skill into a .skill file")
    parser.add_argument("skill_path", type=str, help="Path to the skill directory")
    parser.add_argument("--output", "-o", type=str, default=None,
                        help="Output .skill file path (default: <parent>/<name>.skill)")
    parser.add_argument("--force", "-f", action="store_true",
                        help="Force packaging even with validation warnings")
    args = parser.parse_args()

    skill_path = Path(args.skill_path)
    if not skill_path.is_dir():
        print(f"Error: skill directory not found: {skill_path}", file=sys.stderr)
        sys.exit(1)

    issues = validate_skill(skill_path)
    if issues:
        print("Validation issues:", file=sys.stderr)
        for issue in issues:
            print(f"  - {issue}", file=sys.stderr)
        if not args.force:
            print("Use --force to package anyway.", file=sys.stderr)
            sys.exit(1)
        print("Forcing packaging despite warnings.\n")

    output_path_arg = Path(args.output) if args.output else None
    result = package_skill(skill_path, output_path_arg)
    size = result.stat().st_size
    print(f"Packaged skill: {result} ({size} bytes)")


if __name__ == "__main__":
    main()
