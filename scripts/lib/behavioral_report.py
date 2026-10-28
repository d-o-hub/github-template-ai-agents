"""Text rendering for `behavioral-eval/v1` reports."""

from __future__ import annotations

from typing import Any

from lib.behavioral_contract import (
    SCHEMA_VERSION,
    SEPARATOR_DOUBLE,
    SEPARATOR_SINGLE,
    UNAVAILABLE,
)


def render_report_text(report: dict[str, Any], comparison: dict[str, Any] | None) -> str:
    """Render a human-readable behavioral report."""
    lines = [
        SEPARATOR_DOUBLE,
        "BEHAVIORAL SKILL EVALUATION REPORT",
        SEPARATOR_DOUBLE,
        f"Scope: opt-in paired behavioral run ({SCHEMA_VERSION}); not a static check",
        f"Skill: {report['skill']['name']} ({report['skill']['digest']})",
        f"Fixtures: {report['fixtures']['digest']}",
        f"Provider: {report['provider']['name']} / {report['provider']['model']}"
        f" (observed: {str(report['provider']['observed']).lower()})",
        "",
        "SUMMARY",
        SEPARATOR_SINGLE,
    ]
    for configuration, summary in report["configurations"].items():
        lines.extend(_configuration_lines(configuration, summary))
    lines.extend(["", "CASE RESULTS", SEPARATOR_SINGLE])
    for case in report["cases"]:
        lines.extend(_case_lines(case))
    lines.extend(["", "BASELINE COMPARISON", SEPARATOR_SINGLE])
    lines.extend(_baseline_lines(comparison))
    return "\n".join(lines)


def _configuration_lines(configuration: str, summary: dict[str, Any]) -> list[str]:
    """Render one configuration's summary block."""
    lines = [
        f"[{configuration}]",
        f"  cases: {summary['cases_passed']} passed, {summary['cases_failed']} failed, "
        f"{summary['cases_blocked']} blocked, {summary['cases_not_run']} not run "
        f"(pass rate: {_format_rate(summary['case_pass_rate'])})",
        f"  assertions: {summary['assertions_passed']} passed, "
        f"{summary['assertions_failed']} failed, {summary['assertions_blocked']} blocked "
        f"(pass rate: {_format_rate(summary['assertion_pass_rate'])})",
    ]
    for name, measurement in summary["measurements"].items():
        if measurement["available"]:
            lines.append(
                f"  {name}: {measurement['value']} "
                f"(sources: {', '.join(measurement['sources'])})"
            )
        else:
            lines.append(f"  {name}: unavailable - {measurement['reason']}")
    return lines


def _case_lines(case: dict[str, Any]) -> list[str]:
    """Render one case verdict with its reasons and evidence."""
    lines = [
        f"  [{case['verdict'].upper()}] case {case['case_id']} (bucket: {case['bucket']})"
    ]
    lines.extend(f"      - {reason}" for reason in case["reasons"])
    lines.extend(f"      - {evidence}" for evidence in case["evidence"])
    return lines


def _baseline_lines(comparison: dict[str, Any] | None) -> list[str]:
    """Render the baseline comparison, or say why there is none."""
    if comparison is None:
        return ["  no blessed baseline supplied; delta is unavailable"]
    lines = [
        f"  status: {comparison['status']}",
        f"  blessed by {comparison['baseline_blessed_by']} "
        f"at {comparison['baseline_blessed_at']}",
        f"  skill revision changed since blessing: {comparison['skill_revision_changed']}",
    ]
    for name, delta in comparison["deltas"].items():
        lines.append(f"  delta {name}: {'unavailable' if delta is None else delta}")
    for regression in comparison["regressions"]:
        lines.append(
            f"  REGRESSION {regression['metric']}: measured {regression['measured']} "
            f"below blessed floor {regression['floor']}"
        )
    lines.extend(f"  coverage gap: {gap}" for gap in comparison["coverage_gaps"])
    lines.extend(f"  {reason}" for reason in comparison["reasons"])
    return lines


def _format_rate(rate: float | None) -> str:
    """Format a pass rate without inventing a value."""
    return UNAVAILABLE if rate is None else f"{rate:.3f}"
