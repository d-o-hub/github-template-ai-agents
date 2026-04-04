#!/usr/bin/env python3
"""Automated evaluation runner framework for skills.

This script discovers all skills with evals/evals.json files, runs the defined
test scenarios, and generates comprehensive reports with pass/fail statistics.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any


class EvalType(Enum):
    """Types of evaluations that can be performed."""
    STRUCTURE = "structure"
    COMMAND = "command"
    FILE_VALIDATION = "file_validation"


class EvalStatus(Enum):
    """Status of an individual eval scenario."""
    PASS = "PASS"
    FAIL = "FAIL"
    SKIP = "SKIP"
    ERROR = "ERROR"


@dataclass
class EvalResult:
    """Result of a single eval scenario."""
    eval_id: int
    status: EvalStatus
    message: str = ""
    details: list[str] = field(default_factory=list)
    duration_ms: float = 0.0


@dataclass
class SkillEvalResult:
    """Result of evaluating a single skill."""
    skill_name: str
    skill_path: Path
    status: EvalStatus
    evals_run: int = 0
    evals_passed: int = 0
    evals_failed: int = 0
    evals_skipped: int = 0
    eval_results: list[EvalResult] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


@dataclass
class EvalReport:
    """Overall evaluation report."""
    total_skills: int = 0
    skills_passed: int = 0
    skills_failed: int = 0
    total_evals: int = 0
    evals_passed: int = 0
    evals_failed: int = 0
    evals_skipped: int = 0
    skill_results: list[SkillEvalResult] = field(default_factory=list)


def load_evals_file(evals_path: Path) -> tuple[dict | None, str | None]:
    """Load and parse an evals.json file.
    
    Args:
        evals_path: Path to the evals.json file.
        
    Returns:
        Tuple of (data, error_message). If successful, data is the parsed JSON
        and error_message is None. If failed, data is None and error_message
        contains the error description.
    """
    try:
        data = json.loads(evals_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return None, f"File not found: {evals_path}"
    except json.JSONDecodeError as exc:
        return None, f"Invalid JSON: {exc.msg} at line {exc.lineno}"
    except Exception as exc:
        return None, f"Error reading file: {exc}"
    
    return data, None


def validate_evals_format(data: dict, skill_name: str) -> list[str]:
    """Validate the evals.json format.
    
    Args:
        data: Parsed evals.json data.
        skill_name: Name of the skill being validated.
        
    Returns:
        List of validation issues (empty if valid).
    """
    issues: list[str] = []
    
    # Check required top-level fields
    if "skill_name" not in data:
        issues.append("Missing required field: 'skill_name'")
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
    
    # Validate each eval case
    required_fields = {"id", "prompt", "expected_output"}
    for idx, eval_case in enumerate(evals, start=1):
        if not isinstance(eval_case, dict):
            issues.append(f"Eval #{idx} is not an object")
            continue
        
        missing = required_fields - set(eval_case.keys())
        if missing:
            issues.append(f"Eval #{idx} missing fields: {', '.join(sorted(missing))}")
        
        # Validate assertions if present
        if "assertions" in eval_case:
            assertions = eval_case["assertions"]
            if not isinstance(assertions, list):
                issues.append(f"Eval #{idx}: 'assertions' must be an array")
            elif len(assertions) == 0:
                issues.append(f"Eval #{idx}: 'assertions' array is empty")
        
        # Validate files if present
        if "files" in eval_case:
            files = eval_case["files"]
            if not isinstance(files, list):
                issues.append(f"Eval #{idx}: 'files' must be an array")
            elif not all(isinstance(f, str) for f in files):
                issues.append(f"Eval #{idx}: all 'files' must be strings")
    
    return issues


def run_structure_check(skill_path: Path) -> EvalResult:
    """Run structure check validation for a skill.
    
    Args:
        skill_path: Path to the skill directory.
        
    Returns:
        EvalResult with structure check results.
    """
    issues: list[str] = []
    
    # Check required files
    if not (skill_path / "SKILL.md").is_file():
        issues.append("Missing required file: SKILL.md")
    
    # Check for nested duplicate directory
    if (skill_path / skill_path.name).is_dir():
        issues.append(f"Nested duplicate directory: {skill_path.name}/{skill_path.name}/")
    
    # Check evals.json validity
    evals_path = skill_path / "evals" / "evals.json"
    if evals_path.exists():
        data, error = load_evals_file(evals_path)
        if error:
            issues.append(f"evals.json error: {error}")
        else:
            format_issues = validate_evals_format(data or {}, skill_path.name)
            issues.extend(format_issues)
    
    if issues:
        return EvalResult(
            eval_id=0,
            status=EvalStatus.FAIL,
            message="Structure check failed",
            details=issues
        )
    
    return EvalResult(
        eval_id=0,
        status=EvalStatus.PASS,
        message="Structure check passed",
        details=["SKILL.md exists", "evals.json is valid"]
    )


def run_command_check(
    eval_case: dict,
    skill_path: Path,
    verbose: bool
) -> EvalResult:
    """Run a command-based evaluation.
    
    Args:
        eval_case: The eval case dictionary.
        skill_path: Path to the skill directory.
        verbose: Whether to print verbose output.
        
    Returns:
        EvalResult with command execution results.
    """
    import time
    
    # Look for executable scripts in the skill's scripts directory
    scripts_dir = skill_path / "scripts"
    if not scripts_dir.is_dir():
        return EvalResult(
            eval_id=eval_case.get("id", 0),
            status=EvalStatus.SKIP,
            message="No scripts directory found"
        )
    
    start_time = time.time()
    
    # Find the first Python or shell script (fallback behavior)
    scripts = list(scripts_dir.glob("*.py")) + list(scripts_dir.glob("*.sh"))
    
    if not scripts:
        return EvalResult(
            eval_id=eval_case.get("id", 0),
            status=EvalStatus.SKIP,
            message="No executable scripts found"
        )
    
    # Run check_structure.py if it exists (special case for structure validation)
    check_structure = scripts_dir / "check_structure.py"
    if check_structure.exists():
        try:
            result = subprocess.run(
                [sys.executable, str(check_structure), "--path", str(skill_path.parent)],
                capture_output=True,
                text=True,
                timeout=30,
                cwd=str(skill_path.parent.parent.parent)
            )
            duration = (time.time() - start_time) * 1000
            
            if result.returncode == 0:
                return EvalResult(
                    eval_id=eval_case.get("id", 0),
                    status=EvalStatus.PASS,
                    message="Command executed successfully",
                    duration_ms=duration
                )
            else:
                return EvalResult(
                    eval_id=eval_case.get("id", 0),
                    status=EvalStatus.FAIL,
                    message="Command failed",
                    details=[result.stdout, result.stderr] if result.stderr else [result.stdout],
                    duration_ms=duration
                )
        except subprocess.TimeoutExpired:
            return EvalResult(
                eval_id=eval_case.get("id", 0),
                status=EvalStatus.ERROR,
                message="Command timed out after 30 seconds"
            )
        except Exception as exc:
            return EvalResult(
                eval_id=eval_case.get("id", 0),
                status=EvalStatus.ERROR,
                message=f"Command execution error: {exc}"
            )
    
    return EvalResult(
        eval_id=eval_case.get("id", 0),
        status=EvalStatus.SKIP,
        message="No recognized command found to execute"
    )


def run_file_validation(
    eval_case: dict,
    skill_path: Path,
    verbose: bool
) -> EvalResult:
    """Run file validation for referenced files.
    
    Args:
        eval_case: The eval case dictionary.
        skill_path: Path to the skill directory.
        verbose: Whether to print verbose output.
        
    Returns:
        EvalResult with file validation results.
    """
    files = eval_case.get("files", [])
    if not files:
        return EvalResult(
            eval_id=eval_case.get("id", 0),
            status=EvalStatus.SKIP,
            message="No files to validate"
        )
    
    missing: list[str] = []
    found: list[str] = []
    
    for file_path in files:
        full_path = skill_path / file_path
        if not full_path.exists():
            missing.append(file_path)
        else:
            found.append(file_path)
    
    if missing:
        return EvalResult(
            eval_id=eval_case.get("id", 0),
            status=EvalStatus.FAIL,
            message=f"Missing {len(missing)} file(s)",
            details=[f"Missing: {f}" for f in missing] + [f"Found: {f}" for f in found]
        )
    
    return EvalResult(
        eval_id=eval_case.get("id", 0),
        status=EvalStatus.PASS,
        message=f"All {len(files)} file(s) validated",
        details=[f"Found: {f}" for f in found]
    )


def run_eval_case(
    eval_case: dict,
    skill_path: Path,
    eval_types: list[EvalType],
    verbose: bool
) -> EvalResult:
    """Run a single eval case.
    
    Args:
        eval_case: The eval case dictionary.
        skill_path: Path to the skill directory.
        eval_types: List of evaluation types to run.
        verbose: Whether to print verbose output.
        
    Returns:
        EvalResult with the eval case results.
    """
    eval_id = eval_case.get("id", 0)
    
    # Determine eval type based on case content
    files = eval_case.get("files", [])
    
    if EvalType.STRUCTURE in eval_types and eval_id == 0:
        return run_structure_check(skill_path)
    
    if EvalType.FILE_VALIDATION in eval_types and files:
        return run_file_validation(eval_case, skill_path, verbose)
    
    if EvalType.COMMAND in eval_types:
        return run_command_check(eval_case, skill_path, verbose)
    
    # Default: validate that the eval case is well-formed
    return EvalResult(
        eval_id=eval_id,
        status=EvalStatus.PASS,
        message="Eval case format is valid",
        details=[
            f"Prompt length: {len(eval_case.get('prompt', ''))} chars",
            f"Expected output length: {len(eval_case.get('expected_output', ''))} chars",
            f"Assertions: {len(eval_case.get('assertions', []))}"
        ]
    )


def evaluate_skill(
    skill_path: Path,
    eval_types: list[EvalType],
    verbose: bool
) -> SkillEvalResult:
    """Evaluate a single skill.
    
    Args:
        skill_path: Path to the skill directory.
        eval_types: List of evaluation types to run.
        verbose: Whether to print verbose output.
        
    Returns:
        SkillEvalResult with all eval results for the skill.
    """
    skill_name = skill_path.name
    result = SkillEvalResult(
        skill_name=skill_name,
        skill_path=skill_path,
        status=EvalStatus.PASS
    )
    
    # Load evals.json
    evals_path = skill_path / "evals" / "evals.json"
    data, error = load_evals_file(evals_path)
    
    if error:
        result.errors.append(error)
        result.status = EvalStatus.FAIL
        return result
    
    if data is None:
        result.errors.append("Failed to load evals.json")
        result.status = EvalStatus.FAIL
        return result
    
    # Validate format
    format_issues = validate_evals_format(data, skill_name)
    if format_issues:
        result.errors.extend(format_issues)
        result.status = EvalStatus.FAIL
        return result
    
    # Run structure check first
    if EvalType.STRUCTURE in eval_types:
        structure_result = run_structure_check(skill_path)
        result.eval_results.append(structure_result)
        result.evals_run += 1
        
        if structure_result.status == EvalStatus.PASS:
            result.evals_passed += 1
        else:
            result.evals_failed += 1
            result.status = EvalStatus.FAIL
    
    # Run each eval case
    evals = data.get("evals", [])
    for eval_case in evals:
        eval_result = run_eval_case(eval_case, skill_path, eval_types, verbose)
        result.eval_results.append(eval_result)
        result.evals_run += 1
        
        if eval_result.status == EvalStatus.PASS:
            result.evals_passed += 1
        elif eval_result.status == EvalStatus.SKIP:
            result.evals_skipped += 1
        else:
            result.evals_failed += 1
            result.status = EvalStatus.FAIL
    
    return result


def discover_skills(skills_dir: Path, specific_skill: str | None = None) -> list[Path]:
    """Discover all skills with evals/evals.json files.
    
    Args:
        skills_dir: Path to the skills directory.
        specific_skill: If provided, only check this specific skill.
        
    Returns:
        List of paths to skill directories with evals.
    """
    if specific_skill:
        skill_path = skills_dir / specific_skill
        evals_path = skill_path / "evals" / "evals.json"
        if skill_path.is_dir() and evals_path.exists():
            return [skill_path]
        return []
    
    skills: list[Path] = []
    if not skills_dir.is_dir():
        return skills
    
    for path in sorted(skills_dir.iterdir()):
        if path.is_dir():
            evals_path = path / "evals" / "evals.json"
            if evals_path.exists():
                skills.append(path)
    
    return skills


def generate_text_report(report: EvalReport) -> str:
    """Generate a human-readable text report.
    
    Args:
        report: The evaluation report.
        
    Returns:
        Formatted text report string.
    """
    lines: list[str] = []
    
    lines.append("=" * 70)
    lines.append("SKILL EVALUATION REPORT")
    lines.append("=" * 70)
    lines.append("")
    
    # Summary
    lines.append("SUMMARY")
    lines.append("-" * 40)
    lines.append(f"Total skills evaluated: {report.total_skills}")
    lines.append(f"  - Passed: {report.skills_passed}")
    lines.append(f"  - Failed: {report.skills_failed}")
    lines.append("")
    lines.append(f"Total eval scenarios: {report.total_evals}")
    lines.append(f"  - Passed: {report.evals_passed}")
    lines.append(f"  - Failed: {report.evals_failed}")
    lines.append(f"  - Skipped: {report.evals_skipped}")
    lines.append("")
    
    # Overall status
    if report.skills_failed == 0:
        lines.append("OVERALL STATUS: PASS")
    else:
        lines.append("OVERALL STATUS: FAIL")
    lines.append("")
    
    # Per-skill results
    lines.append("DETAILED RESULTS")
    lines.append("-" * 40)
    
    for skill_result in report.skill_results:
        status_icon = "PASS" if skill_result.status == EvalStatus.PASS else "FAIL"
        lines.append(f"\n[{status_icon}] {skill_result.skill_name}")
        lines.append(f"  Path: {skill_result.skill_path}")
        lines.append(f"  Evals: {skill_result.evals_run} run, "
                    f"{skill_result.evals_passed} passed, "
                    f"{skill_result.evals_failed} failed, "
                    f"{skill_result.evals_skipped} skipped")
        
        if skill_result.errors:
            lines.append("  Errors:")
            for error in skill_result.errors:
                lines.append(f"    - {error}")
        
        # Individual eval results
        for eval_result in skill_result.eval_results:
            if eval_result.status == EvalStatus.PASS:
                icon = "  [PASS]"
            elif eval_result.status == EvalStatus.SKIP:
                icon = "  [SKIP]"
            else:
                icon = "  [FAIL]"
            
            lines.append(f"    {icon} Eval #{eval_result.eval_id}: {eval_result.message}")
            
            if eval_result.details:
                for detail in eval_result.details:
                    lines.append(f"            - {detail}")
    
    lines.append("")
    lines.append("=" * 70)
    
    return "\n".join(lines)


def generate_json_report(report: EvalReport) -> str:
    """Generate a JSON report.
    
    Args:
        report: The evaluation report.
        
    Returns:
        JSON-formatted report string.
    """
    data = {
        "summary": {
            "total_skills": report.total_skills,
            "skills_passed": report.skills_passed,
            "skills_failed": report.skills_failed,
            "total_evals": report.total_evals,
            "evals_passed": report.evals_passed,
            "evals_failed": report.evals_failed,
            "evals_skipped": report.evals_skipped,
            "overall_status": "PASS" if report.skills_failed == 0 else "FAIL"
        },
        "skills": [
            {
                "name": sr.skill_name,
                "path": str(sr.skill_path),
                "status": sr.status.value,
                "evals_run": sr.evals_run,
                "evals_passed": sr.evals_passed,
                "evals_failed": sr.evals_failed,
                "evals_skipped": sr.evals_skipped,
                "errors": sr.errors,
                "evals": [
                    {
                        "id": er.eval_id,
                        "status": er.status.value,
                        "message": er.message,
                        "details": er.details,
                        "duration_ms": er.duration_ms
                    }
                    for er in sr.eval_results
                ]
            }
            for sr in report.skill_results
        ]
    }
    
    return json.dumps(data, indent=2)


def main() -> int:
    """Main entry point.
    
    Returns:
        Exit code (0 for success, 1 for failure).
    """
    parser = argparse.ArgumentParser(
        description="Automated evaluation runner framework for skills",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run all evaluations
  %(prog)s

  # Run evaluations for a specific skill
  %(prog)s --skill skill-evaluator

  # Run with verbose output
  %(prog)s --verbose

  # Output JSON format
  %(prog)s --format json

  # Only run structure checks
  %(prog)s --type structure
        """
    )
    
    parser.add_argument(
        "--skill",
        help="Run evaluations for a specific skill only"
    )
    
    parser.add_argument(
        "--path",
        default=".agents/skills",
        help="Path to skills directory (default: .agents/skills)"
    )
    
    parser.add_argument(
        "--type",
        choices=[t.value for t in EvalType],
        action="append",
        help="Type of evaluation to run (can be specified multiple times)"
    )
    
    parser.add_argument(
        "--format",
        choices=["text", "json"],
        default="text",
        help="Output format (default: text)"
    )
    
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose output"
    )
    
    parser.add_argument(
        "--output", "-o",
        help="Write report to file instead of stdout (suggest: reports/eval-report.json)"
    )
    
    args = parser.parse_args()
    
    # Resolve paths
    skills_dir = Path(args.path)
    if not skills_dir.is_absolute():
        skills_dir = Path.cwd() / skills_dir
    
    if not skills_dir.is_dir():
        print(f"Error: Skills directory not found: {skills_dir}", file=sys.stderr)
        return 1
    
    # Determine eval types
    if args.type:
        eval_types = [EvalType(t) for t in args.type]
    else:
        eval_types = list(EvalType)
    
    if args.verbose:
        print(f"Discovering skills in: {skills_dir}", file=sys.stderr)
    
    # Discover skills
    skill_paths = discover_skills(skills_dir, args.skill)
    
    if not skill_paths:
        if args.skill:
            print(f"Error: Skill '{args.skill}' not found or has no evals.json",
                  file=sys.stderr)
        else:
            print(f"Error: No skills with evals.json found in {skills_dir}",
                  file=sys.stderr)
        return 1
    
    if args.verbose:
        print(f"Found {len(skill_paths)} skill(s) with evals", file=sys.stderr)
    
    # Run evaluations
    report = EvalReport()
    report.total_skills = len(skill_paths)
    
    for i, skill_path in enumerate(skill_paths, start=1):
        if args.verbose:
            print(f"[{i}/{len(skill_paths)}] Evaluating: {skill_path.name}",
                  file=sys.stderr)
        
        skill_result = evaluate_skill(skill_path, eval_types, args.verbose)
        report.skill_results.append(skill_result)
        
        report.total_evals += skill_result.evals_run
        report.evals_passed += skill_result.evals_passed
        report.evals_failed += skill_result.evals_failed
        report.evals_skipped += skill_result.evals_skipped
        
        if skill_result.status == EvalStatus.PASS:
            report.skills_passed += 1
        else:
            report.skills_failed += 1
    
    # Generate report
    if args.format == "json":
        output = generate_json_report(report)
    else:
        output = generate_text_report(report)
    
    # Output
    if args.output:
        output_path = Path(args.output)
        output_path.write_text(output, encoding="utf-8")
        print(f"Report written to: {output_path}", file=sys.stderr)
    else:
        print(output)
    
    # Exit with appropriate code
    return 0 if report.skills_failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
