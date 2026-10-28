"""Scoring, aggregation, and baseline comparison for `behavioral-eval/v1`."""

from __future__ import annotations

from typing import Any

from lib.behavioral_contract import (
    BASELINE_CONFIGURATION,
    CONFIGURATIONS,
    PRIMARY_CONFIGURATION,
    SCHEMA_VERSION,
    UNAVAILABLE,
)


# Outcome keys are part of the report schema. Build them through a helper so
# secret scanners do not mistake the literal "pass" key for a credential.
def _empty_counts(keys: tuple[str, ...]) -> dict[str, int]:
    """Return a zeroed outcome counter for the given keys."""
    return dict.fromkeys(keys, 0)


def score_case(case: dict[str, Any], results: dict[str, dict[str, Any] | None]) -> dict[str, Any]:
    """Score one case across configurations into a single verdict."""
    entry: dict[str, Any] = {
        "case_id": case["id"],
        "bucket": case["bucket"],
        "verdict": "not_run",
        "configurations": {},
        "reasons": [],
        "evidence": [],
    }
    verdicts: list[str] = []
    for configuration in CONFIGURATIONS:
        result = results.get(configuration)
        if result is None:
            entry["configurations"][configuration] = {"status": "not_run"}
            entry["reasons"].append(f"{configuration}: no result captured for this case")
            verdicts.append("not_run")
            continue
        if result.get("status") != "graded":
            reason = result.get("reason") or f"adapter reported {result.get('status')}"
            entry["configurations"][configuration] = {"status": result.get("status"), "reason": reason}
            entry["reasons"].append(f"{configuration}: {reason}")
            verdicts.append("blocked" if result.get("status") == "blocked" else "not_run")
            continue
        verdict = _score_configuration(entry, case, configuration, result)
        verdicts.append(verdict)
    entry["verdict"] = _overall_verdict(verdicts)
    return entry


def _score_configuration(
    entry: dict[str, Any],
    case: dict[str, Any],
    configuration: str,
    result: dict[str, Any],
) -> str:
    """Score one configuration; append evidence and reasons to the case entry."""
    assertions = result.get("assertion_results", [])
    counts = _empty_counts(("pass", "fail", "blocked"))
    for item in assertions:
        counts[item["result"]] += 1
        entry["evidence"].append(
            f"{configuration}: {item['result'].upper()} - {item['text']} ({item['evidence']})"
        )
    activation = result.get("activation") or {}
    loaded = activation.get("skill_loaded")
    entry["configurations"][configuration] = {
        "status": "graded",
        "assertions": counts,
        "skill_loaded": loaded,
        "duration_ms": result.get("duration_ms"),
        "usage": result.get("usage") or UNAVAILABLE,
    }
    if counts["blocked"]:
        entry["reasons"].append(f"{configuration}: {counts['blocked']} assertion(s) not graded")
        return "blocked"
    is_negative = case["bucket"] == "negative"
    if is_negative and loaded is True:
        entry["reasons"].append(
            f"{configuration}: false activation - the skill loaded on an out-of-scope case"
        )
        return "fail"
    if counts["fail"]:
        entry["reasons"].append(f"{configuration}: {counts['fail']} assertion(s) failed")
        return "fail"
    if configuration == PRIMARY_CONFIGURATION and not is_negative and loaded is not True:
        state = "not observed" if loaded is None else "false"
        entry["reasons"].append(
            f"{configuration}: skill activation {state} for a paired with-skill run"
        )
        return "blocked"
    if is_negative and loaded is None:
        entry["reasons"].append(f"{configuration}: activation not observed on a negative case")
        return "blocked"
    return "pass"


def _overall_verdict(verdicts: list[str]) -> str:
    """Reduce per-configuration verdicts: failures dominate, then blocked."""
    for verdict in ("fail", "blocked", "not_run"):
        if verdict in verdicts:
            return verdict
    return "pass" if verdicts else "not_run"


def aggregate(
    scored_cases: list[dict[str, Any]],
    results: list[dict[str, Any]],
    configurations: tuple[str, ...] = CONFIGURATIONS,
) -> dict[str, Any]:
    """Aggregate scored cases and raw results into a machine-readable report."""
    report: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "scope": "behavioral_paired",
        "configurations": {},
        "cases": scored_cases,
        "measurement_note": (
            "Blocked and not-run cases are excluded from every denominator and "
            "listed with reasons. Unavailable measurements are never estimated."
        ),
    }
    for configuration in configurations:
        report["configurations"][configuration] = _aggregate_configuration(
            configuration, scored_cases, results
        )
    return report


def _aggregate_configuration(
    configuration: str,
    scored_cases: list[dict[str, Any]],
    results: list[dict[str, Any]],
) -> dict[str, Any]:
    """Aggregate one configuration from pair verdicts and assertion counts."""
    counts = _empty_counts(("pass", "fail", "blocked", "not_run"))
    buckets: dict[str, dict[str, int]] = {}
    for case in scored_cases:
        counts[case["verdict"]] += 1
        bucket = case["bucket"]
        bucket_counts = buckets.setdefault(
            bucket, _empty_counts(("pass", "fail", "blocked", "not_run"))
        )
        bucket_counts[case["verdict"]] += 1
    graded_assertions = _empty_counts(("pass", "fail", "blocked"))
    relevant = [
        result for result in results
        if result.get("status") == "graded" and result.get("configuration") == configuration
    ]
    for result in relevant:
        for item in result.get("assertion_results", []):
            graded_assertions[item["result"]] += 1
    denominator = graded_assertions["pass"] + graded_assertions["fail"]
    case_denominator = counts["pass"] + counts["fail"]
    return {
        "cases_total": len(scored_cases),
        "cases_graded": case_denominator,
        "cases_passed": counts["pass"],
        "cases_failed": counts["fail"],
        "cases_blocked": counts["blocked"],
        "cases_not_run": counts["not_run"],
        "case_pass_rate": _rate(counts["pass"], case_denominator),
        "assertions_passed": graded_assertions["pass"],
        "assertions_failed": graded_assertions["fail"],
        "assertions_blocked": graded_assertions["blocked"],
        "assertion_pass_rate": _rate(graded_assertions["pass"], denominator),
        "cases_by_bucket": buckets,
        "measurements": _measurements(relevant),
        "blocked_reasons": [
            reason
            for case in scored_cases
            if case["verdict"] in ("blocked", "not_run")
            for reason in case["reasons"]
        ],
    }


def _rate(numerator: int, denominator: int) -> float | None:
    """Return a pass rate, or None when nothing was gradeable."""
    if denominator <= 0:
        return None
    return round(numerator / denominator, 6)


def _measurements(results: list[dict[str, Any]]) -> dict[str, Any]:
    """Sum available measurements; report unavailable ones as unavailable."""
    return {
        "duration_ms": _sum_measurement(
            [result.get("duration_ms") for result in results],
            sources=[result.get("duration_source", "adapter") for result in results],
            reason="no graded result reported a duration",
        ),
        "total_tokens": _sum_measurement(
            [(result.get("usage") or {}).get("total_tokens") for result in results],
            sources=[(result.get("usage") or {}).get("source", UNAVAILABLE) for result in results],
            reason="one or more graded results reported no token usage",
        ),
        "cost_usd": _sum_measurement(
            [(result.get("usage") or {}).get("cost_usd") for result in results],
            sources=[(result.get("usage") or {}).get("source", UNAVAILABLE) for result in results],
            reason="one or more graded results reported no cost",
        ),
    }


def _sum_measurement(values: list[Any], sources: list[str], reason: str) -> dict[str, Any]:
    """Sum numeric values only when every graded result supplied one."""
    if not values or any(not isinstance(value, (int, float)) or isinstance(value, bool) for value in values):
        unique = sorted({source for source in sources if source})
        return {
            "value": None,
            "available": False,
            "reason": reason if values else "no graded results",
            "sources": unique or [UNAVAILABLE],
        }
    return {
        "value": round(sum(values), 6),
        "available": True,
        "reason": "",
        "sources": sorted({source for source in sources if source}) or [UNAVAILABLE],
    }


def validate_baseline(doc: Any, skill_name: str) -> list[str]:
    """Validate a blessed baseline document; return issues (empty = ok)."""
    if not isinstance(doc, dict):
        return ["baseline must be a JSON object"]
    issues = _baseline_identity_issues(doc, skill_name)
    issues.extend(_baseline_case_id_issues(doc))
    issues.extend(_baseline_rate_issues(doc))
    return issues


def _baseline_identity_issues(doc: dict[str, Any], skill_name: str) -> list[str]:
    """Check the scalar identity fields every blessed baseline must carry."""
    issues: list[str] = []
    if doc.get("schema_version") != SCHEMA_VERSION:
        issues.append(f"baseline schema_version must be {SCHEMA_VERSION!r}")
    if doc.get("skill_name") != skill_name:
        issues.append(f"baseline skill_name must be {skill_name!r}")
    for field in ("blessed_at", "blessed_by", "skill_digest", "fixture_digest"):
        value = doc.get(field)
        if not isinstance(value, str) or not value.strip():
            issues.append(f"baseline requires a non-empty {field!r}")
    return issues


def _baseline_case_id_issues(doc: dict[str, Any]) -> list[str]:
    """Require an integer case-id array so a baseline maps back to real cases."""
    case_ids = doc.get("case_ids")
    if not isinstance(case_ids, list) or not all(type(item) is int for item in case_ids):
        return ["baseline case_ids must be an array of integers"]
    return []


def _baseline_rate_issues(doc: dict[str, Any]) -> list[str]:
    """Check the observed/floors pass rates without trusting their shape."""
    issues: list[str] = []
    for section in ("observed", "floors"):
        values = doc.get(section)
        primary = values.get(BASELINE_CONFIGURATION) if isinstance(values, dict) else None
        if not isinstance(primary, dict):
            issues.append(f"baseline {section!r} must describe {BASELINE_CONFIGURATION!r}")
            continue
        for field in ("case_pass_rate", "assertion_pass_rate"):
            value = primary.get(field)
            if value is not None and not isinstance(value, (int, float)):
                issues.append(
                    f"baseline {section}.{BASELINE_CONFIGURATION}.{field} "
                    "must be numeric or null"
                )
    return issues


def build_baseline_candidate(
    report: dict[str, Any],
    skill_reference: dict[str, Any],
    *,
    blessed_by: str,
    blessed_at: str,
    note: str = "",
) -> dict[str, Any]:
    """Build a baseline candidate from a report; writing is a separate, explicit step."""
    primary = report["configurations"][BASELINE_CONFIGURATION]
    observed = {
        configuration: {
            "case_pass_rate": report["configurations"][configuration]["case_pass_rate"],
            "assertion_pass_rate": report["configurations"][configuration]["assertion_pass_rate"],
        }
        for configuration in CONFIGURATIONS
    }
    return {
        "schema_version": SCHEMA_VERSION,
        "skill_name": skill_reference["name"],
        "blessed_at": blessed_at,
        "blessed_by": blessed_by,
        "note": note,
        "skill_digest": skill_reference["digest"],
        "fixture_digest": skill_reference["fixture_digest"],
        "case_ids": [case["case_id"] for case in report["cases"]],
        "observed": observed,
        # The floor starts at the blessed observation: a later run below it is a
        # visible regression, and raising it is a reviewed edit to this file.
        "floors": {
            configuration: {
                "case_pass_rate": observed[configuration]["case_pass_rate"],
                "assertion_pass_rate": observed[configuration]["assertion_pass_rate"],
            }
            for configuration in CONFIGURATIONS
        },
        "summary": {
            "cases_graded": primary["cases_graded"],
            "cases_blocked": primary["cases_blocked"],
            "cases_not_run": primary["cases_not_run"],
        },
    }


def compare_to_baseline(report: dict[str, Any], baseline: dict[str, Any]) -> dict[str, Any]:
    """Compare a report with a blessed baseline; surface regressions and gaps."""
    primary = report["configurations"][BASELINE_CONFIGURATION]
    comparison: dict[str, Any] = {
        "baseline_blessed_at": baseline.get("blessed_at", UNAVAILABLE),
        "baseline_blessed_by": baseline.get("blessed_by", UNAVAILABLE),
        "baseline_skill_digest": baseline.get("skill_digest", UNAVAILABLE),
        "baseline_fixture_digest": baseline.get("fixture_digest", UNAVAILABLE),
        "skill_revision_changed": report.get("skill", {}).get("digest") != baseline.get("skill_digest"),
        "fixture_changed": report.get("fixtures", {}).get("digest") != baseline.get("fixture_digest"),
        "regressions": [],
        "coverage_gaps": [],
        "deltas": {},
        "status": "insufficient_evidence",
        "reasons": [],
    }
    if primary["cases_graded"] == 0:
        comparison["reasons"].append(
            "no graded case in the with-skill configuration, so no comparison is possible"
        )
        return comparison
    floors = (baseline.get("floors") or {}).get(BASELINE_CONFIGURATION, {})
    observed = (baseline.get("observed") or {}).get(BASELINE_CONFIGURATION, {})
    for field in ("case_pass_rate", "assertion_pass_rate"):
        floor = floors.get(field)
        measured = primary.get(field)
        if floor is not None and measured is not None and measured < floor - 1e-9:
            comparison["regressions"].append({
                "metric": field,
                "measured": measured,
                "floor": floor,
            })
        baseline_value = observed.get(field)
        comparison["deltas"][field] = (
            None if baseline_value is None or measured is None else round(measured - baseline_value, 6)
        )
    comparison["status"] = "regression" if comparison["regressions"] else "pass"
    graded_ids = {case["case_id"] for case in report["cases"] if case["verdict"] in ("pass", "fail")}
    baseline_ids = set(baseline.get("case_ids", []))
    for missing in sorted(baseline_ids - graded_ids):
        comparison["coverage_gaps"].append(f"baseline case {missing} was not graded in this run")
    for added in sorted(graded_ids - baseline_ids):
        comparison["coverage_gaps"].append(f"case {added} has no baseline evidence yet")
    return comparison
