"""Command implementations for `scripts/behavioral-eval.py`."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent))

from lib.behavioral_contract import (  # noqa: E402
    BASELINE_FILENAME,
    CONFIGURATIONS,
    PRIMARY_CONFIGURATION,
    REPORT_FILENAME,
    SCHEMA_VERSION,
    UNAVAILABLE,
    ContractError,
    load_cases,
    redact,
    select_cases,
)
from lib.behavioral_report import render_report_text  # noqa: E402
from lib.behavioral_runner import (  # noqa: E402
    DEFAULT_TIMEOUT_SECONDS,
    build_plan,
    build_tasks,
    run_tasks,
    store_plan_artifact,
    write_candidate_baseline,
    write_text,
)
from lib.behavioral_scoring import (  # noqa: E402
    aggregate,
    build_baseline_candidate,
    compare_to_baseline,
    score_case,
    validate_baseline,
)
from lib.paths import PathValidationError, validate_canonical_name  # noqa: E402

EXIT_OK = 0
EXIT_FINDINGS = 1
EXIT_CONTRACT = 2
EXIT_BLOCKED = 3

DEFAULT_SKILLS_DIR = ".agents/skills"
ADAPTER_ENV_VAR = "BEHAVIORAL_EVAL_ADAPTER"
PROVIDER_NAME_ENV_VAR = "BEHAVIORAL_EVAL_PROVIDER_NAME"
PROVIDER_MODEL_ENV_VAR = "BEHAVIORAL_EVAL_PROVIDER_MODEL"
WORKSPACE_SUFFIX = "-workspace"


def parse_case_ids(raw: str | None) -> list[int] | None:
    """Parse a comma-separated case id list."""
    if not raw:
        return None
    ids: list[int] = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            ids.append(int(part))
        except ValueError:
            raise ContractError(f"case id is not an integer: {part!r}") from None
    return ids or None


def resolve_skill(args: argparse.Namespace) -> Path:
    """Resolve a skill directory under the skills root, refusing traversal."""
    root = Path(args.path)
    if not root.is_dir():
        raise ContractError(f"skills directory not found: {root}")
    try:
        skill_path = validate_canonical_name(args.skill, root, "skill")
    except PathValidationError as exc:
        raise ContractError(str(exc)) from None
    if not skill_path.is_dir():
        raise ContractError(f"skill not found: {skill_path}")
    return skill_path


def resolve_output_dir(args: argparse.Namespace, skill_path: Path) -> Path:
    """Resolve the artifact directory; the default stays in gitignored space."""
    if args.output_dir:
        return Path(args.output_dir)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return skill_path.parent / f"{skill_path.name}{WORKSPACE_SUFFIX}" / f"behavioral-{stamp}"


def provider_metadata(args: argparse.Namespace) -> dict[str, Any]:
    """Collect provider metadata; unobserved values stay unavailable."""
    name = getattr(args, "provider_name", None) or os.environ.get(PROVIDER_NAME_ENV_VAR) or UNAVAILABLE
    model = getattr(args, "provider_model", None) or os.environ.get(PROVIDER_MODEL_ENV_VAR) or UNAVAILABLE
    return {"name": name, "model": model, "observed": name != UNAVAILABLE or model != UNAVAILABLE}


def adapter_command(args: argparse.Namespace) -> str | None:
    """Return the configured adapter command, if any."""
    return getattr(args, "adapter_command", None) or os.environ.get(ADAPTER_ENV_VAR) or None


def load_baseline(skill_path: Path, explicit: str | None) -> dict[str, Any] | None:
    """Load and validate a blessed baseline; absent baseline is not an error."""
    path = Path(explicit) if explicit else skill_path / "evals" / BASELINE_FILENAME
    if not path.exists():
        return None
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ContractError(f"baseline is not valid JSON: {path}: {exc.msg}") from None
    issues = validate_baseline(doc, skill_path.name)
    if issues:
        raise ContractError(f"baseline {path} is invalid: {'; '.join(issues)}")
    return doc


def build_report(
    skill_path: Path,
    plan: dict[str, Any],
    cases: list[dict[str, Any]],
    scored: list[dict[str, Any]],
    results: list[dict[str, Any]],
    *,
    baseline: dict[str, Any] | None,
    output_dir: Path,
    contract_errors: list[str],
) -> dict[str, Any]:
    """Assemble the run report consumed by compare/bless and CI artifacts."""
    report = aggregate(scored, results)
    report["skill"] = plan["skill"]
    report["fixtures"] = plan["fixtures"]
    report["provider"] = plan["provider"]
    report["adapter"] = {"configured": bool(plan.get("adapter_command")), "output_dir": output_dir.as_posix()}
    report["contract_errors"] = contract_errors
    report["baseline"] = (
        compare_to_baseline(report, baseline) if baseline is not None
        else {"status": "not_blessed", "reasons": ["no blessed baseline for this skill"]}
    )
    report["cases_total"] = len(cases)
    return report


def exit_code_for(report: dict[str, Any]) -> int:
    """Map a run report to the documented exit code."""
    if report["contract_errors"]:
        return EXIT_CONTRACT
    configurations = report["configurations"]
    if any(summary["cases_failed"] for summary in configurations.values()):
        return EXIT_FINDINGS
    comparison = report["baseline"]
    if comparison.get("status") == "regression":
        return EXIT_FINDINGS
    graded = sum(summary["cases_graded"] for summary in configurations.values())
    if graded == 0 or report["baseline"].get("status") == "insufficient_evidence":
        return EXIT_BLOCKED
    if any(summary["cases_blocked"] or summary["cases_not_run"] for summary in configurations.values()):
        return EXIT_BLOCKED
    return EXIT_OK


def emit(text: str, path: Path | None = None) -> None:
    """Print to stdout or write to a file."""
    if path is None:
        print(text)
    else:
        write_text(path, text)


def command_plan(args: argparse.Namespace) -> int:
    """Build and store a paired plan without executing an adapter."""
    skill_path = resolve_skill(args)
    cases = select_cases(load_cases(skill_path), parse_case_ids(args.cases))
    plan = build_plan(
        skill_path,
        cases,
        provider=provider_metadata(args),
        include_prompts=args.include_prompts,
    )
    plan["adapter_command"] = adapter_command(args)
    output_dir = resolve_output_dir(args, skill_path)
    store_plan_artifact(plan, output_dir, include_prompts=args.include_prompts)
    summary = {
        "scope": "behavioral_paired_plan",
        "skill": plan["skill"],
        "fixtures": plan["fixtures"],
        "provider": plan["provider"],
        "cases": [case["id"] for case in cases],
        "configurations": list(CONFIGURATIONS),
        "tasks": len(plan["tasks"]),
        "prompt_capture": plan["prompt_capture"],
        "output_dir": output_dir.as_posix(),
        "adapter_configured": bool(plan["adapter_command"]),
    }
    emit(json.dumps(summary, indent=2) if args.format == "json" else _plan_text(summary))
    return EXIT_OK


def _plan_text(summary: dict[str, Any]) -> str:
    return "\n".join([
        f"Behavioral plan for {summary['skill']['name']} ({summary['skill']['digest']})",
        f"Cases: {', '.join(str(case) for case in summary['cases'])}",
        f"Configurations: {', '.join(summary['configurations'])}",
        f"Tasks: {summary['tasks']}",
        f"Provider: {summary['provider']['name']} / {summary['provider']['model']}",
        f"Prompts: {summary['prompt_capture']}",
        f"Adapter configured: {str(summary['adapter_configured']).lower()}",
        f"Artifacts: {summary['output_dir']}",
    ])


def command_run(args: argparse.Namespace) -> int:
    """Execute the paired run when an adapter is configured."""
    skill_path = resolve_skill(args)
    cases = select_cases(load_cases(skill_path), parse_case_ids(args.cases))
    plan = build_plan(
        skill_path,
        cases,
        provider=provider_metadata(args),
        include_prompts=args.include_prompts,
    )
    command = adapter_command(args)
    plan["adapter_command"] = command
    output_dir = resolve_output_dir(args, skill_path)
    store_plan_artifact(plan, output_dir, include_prompts=args.include_prompts)
    scored: list[dict[str, Any]] = []
    results: list[dict[str, Any]] = []
    contract_errors: list[str] = []
    if not command:
        scored = [score_case(case, {}) for case in cases]
        contract_errors = []
        _report_blocked_plan(output_dir, skill_path, args)
        report = build_report(
            skill_path, plan, cases, scored, results,
            baseline=None, output_dir=output_dir, contract_errors=contract_errors,
        )
        return _finish(report, args, output_dir, blocked_reason="no adapter configured")
    tasks = build_tasks(plan, cases, output_dir)
    outcomes = run_tasks(
        tasks, plan, skill_path, command,
        cwd=Path.cwd(), timeout=args.adapter_timeout, include_prompts=args.include_prompts,
    )
    by_case: dict[int, dict[str, dict[str, Any] | None]] = {
        case["id"]: {} for case in cases
    }
    for outcome in outcomes:
        if outcome.error:
            contract_errors.append(f"{outcome.task.label}: {outcome.error}")
            continue
        if outcome.result is not None:
            results.append(outcome.result)
            by_case[outcome.task.case["id"]][outcome.task.configuration] = outcome.result
    scored = [
        score_case(case, {config: by_case[case["id"]].get(config) for config in CONFIGURATIONS})
        for case in cases
    ]
    baseline = load_baseline(skill_path, args.baseline)
    report = build_report(
        skill_path, plan, cases, scored, results,
        baseline=baseline, output_dir=output_dir, contract_errors=contract_errors,
    )
    if baseline is not None and report["baseline"].get("status") != "insufficient_evidence":
        candidate = build_baseline_candidate(
            report, report["skill"],
            blessed_by=UNAVAILABLE,
            blessed_at=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            note="candidate only; bless explicitly after human review",
        )
        write_candidate_baseline(output_dir, candidate)
    return _finish(report, args, output_dir)


def _report_blocked_plan(output_dir: Path, skill_path: Path, args: argparse.Namespace) -> None:
    """Record that a run could not start because no adapter was configured."""
    write_text(
        output_dir / "blocked.json",
        json.dumps({
            "schema_version": SCHEMA_VERSION,
            "skill": skill_path.name,
            "status": "blocked",
            "reason": "no adapter configured",
            "how_to_configure": f"pass --adapter-command or set {ADAPTER_ENV_VAR}",
            "format": args.format,
        }, indent=2),
    )


def _finish(
    report: dict[str, Any],
    args: argparse.Namespace,
    output_dir: Path,
    blocked_reason: str | None = None,
) -> int:
    """Persist the report, print it, and return the documented exit code."""
    write_text(output_dir / REPORT_FILENAME, json.dumps(_redact_tree(report), indent=2))
    text = render_report_text(report, report["baseline"] if report["baseline"].get("status") != "not_blessed" else None)
    if blocked_reason:
        text = f"BLOCKED: {blocked_reason}\n" + text
    if report["contract_errors"]:
        text = "CONTRACT ERROR(S):\n" + "\n".join(f"  - {error}" for error in report["contract_errors"]) + "\n" + text
    emit(json.dumps(report, indent=2) if args.format == "json" else text)
    if args.format != "json":
        print(f"\nArtifacts: {output_dir}")
    return exit_code_for(report)


def _redact_tree(value: Any) -> Any:
    """Redact string values in the stored report."""
    if isinstance(value, str):
        return redact(value)
    if isinstance(value, dict):
        return {key: _redact_tree(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_redact_tree(item) for item in value]
    return value


def load_report(skill_path: Path, explicit: str | None) -> dict[str, Any]:
    """Load a previously written run report."""
    path = Path(explicit) if explicit else Path(".") / REPORT_FILENAME
    if not path.is_file():
        raise ContractError(f"report not found: {path}")
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ContractError(f"report is not valid JSON: {path}: {exc.msg}") from None
    if report.get("schema_version") != SCHEMA_VERSION:
        raise ContractError(f"report schema_version must be {SCHEMA_VERSION!r}")
    if report.get("skill", {}).get("name") != skill_path.name:
        raise ContractError(f"report is for a different skill: {report.get('skill', {}).get('name')}")
    return report


def command_compare(args: argparse.Namespace) -> int:
    """Compare an existing report with a blessed baseline."""
    skill_path = resolve_skill(args)
    report = load_report(skill_path, args.report)
    baseline = load_baseline(skill_path, args.baseline)
    if baseline is None:
        print("No blessed baseline; comparison unavailable (NOT_RUN).", file=sys.stderr)
        return EXIT_BLOCKED
    comparison = compare_to_baseline(report, baseline)
    emit(json.dumps(comparison, indent=2) if args.format == "json" else _comparison_text(comparison))
    if comparison["status"] == "regression":
        return EXIT_FINDINGS
    return EXIT_OK if comparison["status"] == "pass" else EXIT_BLOCKED


def _comparison_text(comparison: dict[str, Any]) -> str:
    lines = [f"Baseline status: {comparison['status']}"]
    for name, delta in comparison["deltas"].items():
        lines.append(f"  delta {name}: {'unavailable' if delta is None else delta}")
    for regression in comparison["regressions"]:
        lines.append(f"  REGRESSION {regression['metric']}: {regression['measured']} < {regression['floor']}")
    for gap in comparison["coverage_gaps"]:
        lines.append(f"  coverage gap: {gap}")
    for reason in comparison["reasons"]:
        lines.append(f"  {reason}")
    return "\n".join(lines)


def command_bless(args: argparse.Namespace) -> int:
    """Write a blessed baseline only with explicit acceptance."""
    skill_path = resolve_skill(args)
    report = load_report(skill_path, args.report)
    baseline_path = Path(args.baseline) if args.baseline else skill_path / "evals" / BASELINE_FILENAME
    _require_blessable(report)
    candidate = build_baseline_candidate(
        report,
        report["skill"],
        blessed_by=args.blessed_by or UNAVAILABLE,
        blessed_at=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        note=args.note or "",
    )
    if not args.accept:
        existing = load_baseline(skill_path, str(baseline_path)) if baseline_path.exists() else None
        same = existing is not None and _floors(existing) == _floors(candidate)
        write_text(baseline_path.with_suffix(".candidate.json"), json.dumps(candidate, indent=2))
        print(
            "Refusing to bless without --accept. Wrote "
            f"{baseline_path.with_suffix('.candidate.json')} for review."
        )
        return EXIT_OK if same else EXIT_FINDINGS
    if not args.blessed_by:
        print("Blessing requires --blessed-by so approval is attributable.", file=sys.stderr)
        return EXIT_CONTRACT
    write_text(baseline_path, json.dumps(candidate, indent=2))
    print(f"Blessed baseline written: {baseline_path} (by {args.blessed_by})")
    return EXIT_OK


def _floors(baseline: dict[str, Any]) -> dict[str, Any]:
    """Extract comparable floor values from a baseline."""
    return (baseline.get("floors") or {}).get(PRIMARY_CONFIGURATION, {})


def _require_blessable(report: dict[str, Any]) -> None:
    """Refuse to bless failures, blocked cases, or contract errors."""
    if report.get("contract_errors"):
        raise ContractError("cannot bless a run with contract errors")
    for configuration, summary in report["configurations"].items():
        if summary["cases_failed"] or summary["cases_blocked"] or summary["cases_not_run"]:
            raise ContractError(
                f"cannot bless {configuration}: "
                f"{summary['cases_failed']} failed, {summary['cases_blocked']} blocked, "
                f"{summary['cases_not_run']} not run"
            )
        if summary["cases_graded"] == 0:
            raise ContractError(f"cannot bless {configuration}: no graded cases")
    if any(rate is None for rate in (
        report["configurations"][PRIMARY_CONFIGURATION]["case_pass_rate"],
        report["configurations"][PRIMARY_CONFIGURATION]["assertion_pass_rate"],
    )):
        raise ContractError("cannot bless a run without measured pass rates")
