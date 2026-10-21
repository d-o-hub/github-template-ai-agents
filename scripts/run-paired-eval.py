#!/usr/bin/env python3
"""Opt-in paired behavioral evaluation CLI runner.

Runs matched evaluation cases for a skill (with_skill vs without_skill),
records skill/fixture content digests, provider/model metadata (or explicit
'unavailable' markers), evaluates assertions and negative out-of-scope routing,
and compares results against human-controlled blessed baselines.

Usage:
    python3 scripts/run-paired-eval.py --skill skill-evaluator
    python3 scripts/run-paired-eval.py --skill skill-evaluator --bless
    python3 scripts/run-paired-eval.py --skill skill-evaluator --format json
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Add scripts directory to path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.paired_eval_adapter import PairedEvalAdapter
from lib.paths import PathValidationError, validate_safe_path

SEPARATOR_DOUBLE = "=" * 70
SEPARATOR_SINGLE = "-" * 40


def generate_text_report(report: dict) -> str:
    """Generate human-readable text report from paired eval report."""
    lines: list[str] = []
    lines.append(SEPARATOR_DOUBLE)
    lines.append("PAIRED BEHAVIORAL EVALUATION REPORT")
    lines.append(SEPARATOR_DOUBLE)

    skill_info = report.get("skill", {})
    env_info = report.get("environment", {})
    summary = report.get("summary", {})
    baseline_comp = summary.get("baseline_comparison", {})
    metrics = report.get("metrics", {})

    lines.append(f"Skill: {skill_info.get('name', 'unknown')}")
    lines.append(f"Content Digest: {skill_info.get('content_digest', 'unavailable')}")
    lines.append(f"Fixture Digest: {skill_info.get('fixture_digest', 'unavailable')}")
    lines.append(f"Provider: {env_info.get('provider', 'unavailable')}")
    lines.append(f"Model ID: {env_info.get('model_id', 'unavailable')}")
    lines.append("")
    lines.append("SUMMARY")
    lines.append(SEPARATOR_SINGLE)
    lines.append(f"Overall Status: {summary.get('status', 'UNKNOWN')}")
    lines.append(f"Total Cases: {summary.get('total_cases', 0)}")
    lines.append(f"  - Passed: {summary.get('passed_cases', 0)}")
    lines.append(f"  - Failed: {summary.get('failed_cases', 0)}")
    lines.append(f"  - Blocked: {summary.get('blocked_cases', 0)}")
    lines.append(f"Pass Rate (with skill): {summary.get('pass_rate_with_skill', 0.0):.2f}")
    lines.append(f"Pass Rate (without skill): {summary.get('pass_rate_without_skill', 0.0):.2f}")
    lines.append(f"Skill Lift: {summary.get('skill_lift', 0.0):.2f}")
    lines.append("")
    lines.append("BASELINE COMPARISON")
    lines.append(SEPARATOR_SINGLE)
    if baseline_comp.get("blessed_baseline_found"):
        lines.append(f"Blessed Baseline Pass Rate: {baseline_comp.get('blessed_pass_rate', 0.0):.2f}")
        lines.append(f"Delta from Baseline: {baseline_comp.get('delta_from_baseline', 0.0):.2f}")
        lines.append(f"Regression Detected: {baseline_comp.get('regression_detected', False)}")
        lines.append(f"Details: {baseline_comp.get('details', '')}")
    else:
        lines.append("No blessed baseline found for comparison.")
    lines.append("")
    lines.append("METRICS")
    lines.append(SEPARATOR_SINGLE)
    lines.append(f"Duration (ms): {metrics.get('duration_ms', 'unavailable')}")
    lines.append(f"Total Tokens: {metrics.get('total_tokens', 'unavailable')}")
    lines.append(f"Total Cost USD: {metrics.get('total_cost_usd', 'unavailable')}")
    lines.append("")
    lines.append("CASE RESULTS")
    lines.append(SEPARATOR_SINGLE)
    for c in report.get("cases", []):
        cid = c.get("id")
        bucket = c.get("bucket", "explicit")
        passed = c.get("passed", False)
        status_str = "PASS" if passed else "FAIL"
        with_st = c.get("with_skill", {}).get("status", "NOT_RUN")

        lines.append(f"\n[Case #{cid}] ({bucket}) - Status: {status_str} [with_skill: {with_st}]")
        lines.append(f"  Prompt: {c.get('prompt', '')}")
        lines.append("  Assertions (with_skill):")
        for a in c.get("with_skill", {}).get("assertions", []):
            a_icon = "✓" if a.get("passed") else "✗"
            lines.append(f"    [{a_icon}] {a.get('text', '')}: {a.get('evidence', '')}")

    lines.append("")
    lines.append(SEPARATOR_DOUBLE)
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Opt-in paired behavioral evaluation CLI runner",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--skill", default="skill-evaluator", help="Name of the skill to evaluate")
    parser.add_argument("--path", default=".agents/skills", help="Path to skills directory")
    parser.add_argument("--baselines-dir", default=".agents/baselines", help="Path to baselines directory")
    parser.add_argument("--agent-cmd", help="Command template to execute paired runs")
    parser.add_argument("--provider", help="Provider name (e.g. anthropic, bedrock, do-harness)")
    parser.add_argument("--model-id", help="Model identifier")
    parser.add_argument("--bless", action="store_true", help="Bless current run as the baseline floor")
    parser.add_argument("--format", choices=["text", "json"], default="text", help="Output format")
    parser.add_argument("--output", help="Write report output to file")

    args = parser.parse_args()

    try:
        skills_dir = validate_safe_path(args.path, Path.cwd(), "path")
        baselines_dir = validate_safe_path(args.baselines_dir, Path.cwd(), "baselines-dir")
    except PathValidationError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    adapter = PairedEvalAdapter(
        skills_dir=skills_dir,
        baselines_dir=baselines_dir,
        agent_cmd=args.agent_cmd,
        provider=args.provider,
        model_id=args.model_id,
    )

    report = adapter.evaluate_skill_paired(args.skill)

    if args.bless:
        blessed_file = adapter.bless_baseline(args.skill, report)
        print(f"Blessed baseline floor saved to: {blessed_file}", file=sys.stderr)

    if args.format == "json":
        output_str = json.dumps(report, indent=2)
    else:
        output_str = generate_text_report(report)

    if args.output:
        try:
            output_path = validate_safe_path(args.output, Path.cwd(), "output", check_forbidden=True)
            output_path.write_text(output_str, encoding="utf-8")
            print(f"Report written to: {output_path}", file=sys.stderr)
        except PathValidationError as e:
            print(f"Error: {e}", file=sys.stderr)
            return 1
    else:
        print(output_str)

    status = report.get("summary", {}).get("status")
    if status in ("PASS", "BLOCKED"):
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
