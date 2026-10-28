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
        lines.append(f"[{configuration}]")
        lines.append(
            f"  cases: {summary['cases_passed']} passed, {summary['cases_failed']} failed, "
            f"{summary['cases_blocked']} blocked, {summary['cases_not_run']} not run "
            f"(pass rate: {_format_rate(summary['case_pass_rate'])})"
        )
        lines.append(
            f"  assertions: {summary['assertions_passed']} passed, "
            f"{summary['assertions_failed']} failed, {summary['assertions_blocked']} blocked "
            f"(pass rate: {_format_rate(summary['assertion_pass_rate'])})"
        )
        for name, measurement in summary["measurements"].items():
            if measurement["available"]:
                lines.append(f"  {name}: {measurement['value']} (sources: {', '.join(measurement['sources'])})")
            else:
                lines.append(f"  {name}: unavailable - {measurement['reason']}")
    lines.extend(["", "CASE RESULTS", SEPARATOR_SINGLE])
    for case in report["cases"]:
        lines.append(f"  [{case['verdict'].upper()}] case {case['case_id']} (bucket: {case['bucket']})")
        for reason in case["reasons"]:
            lines.append(f"      - {reason}")
        for evidence in case["evidence"]:
            lines.append(f"      - {evidence}")
    lines.extend(["", "BASELINE COMPARISON", SEPARATOR_SINGLE])
    if comparison is None:
        lines.append("  no blessed baseline supplied; delta is unavailable")
    else:
        lines.append(f"  status: {comparison['status']}")
        lines.append(f"  blessed by {comparison['baseline_blessed_by']} at {comparison['baseline_blessed_at']}")
        lines.append(f"  skill revision changed since blessing: {comparison['skill_revision_changed']}")
        for name, delta in comparison["deltas"].items():
            lines.append(f"  delta {name}: {'unavailable' if delta is None else delta}")
        for regression in comparison["regressions"]:
            lines.append(
                f"  REGRESSION {regression['metric']}: measured {regression['measured']} "
                f"below blessed floor {regression['floor']}"
            )
        for gap in comparison["coverage_gaps"]:
            lines.append(f"  coverage gap: {gap}")
        for reason in comparison["reasons"]:
            lines.append(f"  {reason}")
    return "\n".join(lines)


def _format_rate(rate: float | None) -> str:
    """Format a pass rate without inventing a value."""
    return UNAVAILABLE if rate is None else f"{rate:.3f}"
