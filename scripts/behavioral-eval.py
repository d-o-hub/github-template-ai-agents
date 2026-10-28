#!/usr/bin/env python3
"""Opt-in paired behavioral evaluation for agent skills (`behavioral-eval/v1`).

This is NOT part of the default quality gate. It executes a real agent adapter
only when one is supplied, so it needs no model credentials in CI and cannot
turn a static check into a behavioral claim.

Usage:
    python3 scripts/behavioral-eval.py plan --skill skill-evaluator
    python3 scripts/behavioral-eval.py run --skill skill-evaluator \\
        --adapter-command "my-agent-adapter --json"
    python3 scripts/behavioral-eval.py compare --skill skill-evaluator
    python3 scripts/behavioral-eval.py bless --skill skill-evaluator \\
        --report <run>/report.json --accept --blessed-by <reviewer>

Exit codes:
    0  every graded case passed and no blessed floor regressed
    1  a case failed or a blessed floor regressed
    2  contract/configuration error (malformed adapter output, bad case set)
    3  blocked or not run (no adapter, missing metadata, incomplete pair)

The adapter receives one task JSON on stdin and must print one result JSON
object. This template ships no adapter that calls a model; `do-harness eval` is
a possible backend but its fixture format is not verified as compatible, so it
needs an adapter and its own tests first.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from lib.behavioral_commands import (  # noqa: E402
    ADAPTER_ENV_VAR,
    DEFAULT_SKILLS_DIR,
    PROVIDER_MODEL_ENV_VAR,
    PROVIDER_NAME_ENV_VAR,
    command_bless,
    command_compare,
    command_plan,
    command_run,
)
from lib.behavioral_contract import (  # noqa: E402
    BASELINE_FILENAME,
    REPORT_FILENAME,
    ContractError,
)
from lib.behavioral_runner import DEFAULT_TIMEOUT_SECONDS  # noqa: E402


def build_parser() -> argparse.ArgumentParser:
    """Build the CLI parser with shared and command-specific options."""
    parser = argparse.ArgumentParser(
        description="Opt-in paired behavioral skill evaluation (not part of the default gate)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan = subparsers.add_parser("plan", help="build the paired plan without executing")
    _add_common_args(plan)
    _add_common_run_args(plan)
    plan.set_defaults(func=command_plan)

    run = subparsers.add_parser("run", help="execute paired tasks through an adapter")
    _add_common_args(run)
    _add_common_run_args(run)
    run.add_argument("--adapter-command", help=f"adapter command (or ${ADAPTER_ENV_VAR})")
    run.add_argument("--adapter-timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    run.add_argument("--provider-name", help=f"agent/provider name (or ${PROVIDER_NAME_ENV_VAR})")
    run.add_argument("--provider-model", help=f"model id (or ${PROVIDER_MODEL_ENV_VAR})")
    run.add_argument("--baseline", help=f"blessed baseline path (default: <skill>/evals/{BASELINE_FILENAME})")
    run.set_defaults(func=command_run)

    compare = subparsers.add_parser("compare", help="compare a stored report with a baseline")
    _add_common_args(compare)
    compare.add_argument("--report", help=f"run report path (default: ./{REPORT_FILENAME})")
    compare.add_argument("--baseline", help=f"baseline path (default: <skill>/evals/{BASELINE_FILENAME})")
    compare.set_defaults(func=command_compare)

    bless = subparsers.add_parser("bless", help="write a blessed baseline after human review")
    _add_common_args(bless)
    bless.add_argument("--report", help=f"run report path (default: ./{REPORT_FILENAME})")
    bless.add_argument("--baseline", help=f"baseline path (default: <skill>/evals/{BASELINE_FILENAME})")
    bless.add_argument("--accept", action="store_true", help="explicitly accept the new floor")
    bless.add_argument("--blessed-by", help="reviewer handle recorded in the baseline")
    bless.add_argument("--note", default="", help="why this floor was accepted")
    bless.set_defaults(func=command_bless)
    return parser


def _add_common_args(parser: argparse.ArgumentParser) -> None:
    """Add options shared by every subcommand."""
    parser.add_argument("--skill", required=True, help="skill directory name under --path")
    parser.add_argument("--path", default=DEFAULT_SKILLS_DIR,
                        help=f"skills root (default: {DEFAULT_SKILLS_DIR})")
    parser.add_argument("--format", choices=("text", "json"), default="text")


def _add_common_run_args(parser: argparse.ArgumentParser) -> None:
    """Add plan/run options shared by both commands."""
    parser.add_argument("--cases", help="comma-separated case ids (default: all)")
    parser.add_argument("--output-dir", help="artifact directory (default: gitignored workspace)")
    parser.add_argument("--include-prompts", action="store_true",
                        help="store redacted prompts in artifacts (default: withheld)")


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except ContractError as exc:
        print(f"Contract error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
