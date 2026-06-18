#!/usr/bin/env python3
"""Aggregate eval grading and timing data into a benchmark.json and benchmark.md."""
from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path


def load_json_files(root: Path, pattern: str) -> list[dict]:
    """Recursively load all JSON files matching a pattern."""
    results: list[dict] = []
    for path in root.rglob(pattern):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            results.append(data)
        except (json.JSONDecodeError, IOError) as exc:
            print(f"Warning: Could not load {path}: {exc}", file=sys.stderr)
    return results


def compute_stats(values: list[float]) -> dict:
    """Compute mean and stddev for a list of values."""
    if not values:
        return {"mean": 0.0, "stddev": 0.0}
    n = len(values)
    mean = sum(values) / n
    if n < 2:
        return {"mean": mean, "stddev": 0.0}
    variance = sum((v - mean) ** 2 for v in values) / (n - 1)
    return {"mean": round(mean, 4), "stddev": round(math.sqrt(variance), 4)}


def extract_config(data: dict) -> str:
    """Extract config name from a data dict."""
    return data.get("config", "unknown")


def aggregate_results(workspace_path: Path) -> dict:
    """Aggregate all gradings and timings into a benchmark summary."""
    gradings = load_json_files(workspace_path, "grading.json")
    timings = load_json_files(workspace_path, "timing.json")

    configs: dict[str, dict[str, list[float]]] = {}

    for g in gradings:
        config = extract_config(g)
        if config not in configs:
            configs[config] = {"pass_rates": [], "times": [], "tokens": []}
        summary = g.get("summary", {})
        rate = summary.get("pass_rate", 0.0)
        configs[config]["pass_rates"].append(rate)

    for t in timings:
        config = extract_config(t)
        if config not in configs:
            configs[config] = {"pass_rates": [], "times": [], "tokens": []}
        configs[config]["times"].append(t.get("duration_ms", 0) / 1000.0)
        configs[config]["tokens"].append(float(t.get("total_tokens", 0)))

    # Build run_summary
    run_summary: dict[str, dict] = {}
    config_keys = list(configs.keys())

    for config in config_keys:
        c = configs[config]
        run_summary[config] = {
            "pass_rate": compute_stats(c["pass_rates"]),
            "time_seconds": compute_stats(c["times"]),
            "tokens": compute_stats(c["tokens"]),
        }

    # Ensure standard configs exist (with_skill, without_skill)
    if "with_skill" in run_summary and "without_skill" in run_summary:
        run_summary["delta"] = {}
        for metric in ("pass_rate", "time_seconds", "tokens"):
            ws = run_summary["with_skill"][metric]
            wo = run_summary["without_skill"][metric]
            # Delta = with_skill - without_skill
            delta_values = []
            if metric == "pass_rate":
                # Use the raw list deltas if we still have them
                delta_values = [
                    a - b
                    for a, b in zip(configs["with_skill"]["pass_rates"], configs["without_skill"]["pass_rates"])
                ]
            elif metric == "time_seconds":
                delta_values = [
                    a - b
                    for a, b in zip(configs["with_skill"]["times"], configs["without_skill"]["times"])
                ]
            elif metric == "tokens":
                delta_values = [
                    a - b
                    for a, b in zip(configs["with_skill"]["tokens"], configs["without_skill"]["tokens"])
                ]
            run_summary["delta"][metric] = compute_stats(delta_values)

    # Count unique eval cases
    eval_ids = set()
    for g in gradings:
        eval_id = g.get("eval_id")
        if eval_id is not None:
            eval_ids.add(eval_id)

    return {
        "workspace": str(workspace_path),
        "total_cases": len(eval_ids),
        "runs_per_case": max(
            (len(configs[c].get("pass_rates", [])) // max(len(eval_ids), 1))
            if configs.get(c, {}).get("pass_rates") else 0
            for c in config_keys
        ) if eval_ids else 0,
        "run_summary": run_summary,
    }


def generate_markdown(benchmark: dict) -> str:
    """Generate a human-readable markdown report from benchmark data."""
    rs = benchmark.get("run_summary", {})
    lines = [
        f"# Benchmark Results",
        f"",
        f"- **Workspace**: {benchmark.get('workspace', 'N/A')}",
        f"- **Total cases**: {benchmark.get('total_cases', 0)}",
        f"- **Runs per case**: {benchmark.get('runs_per_case', 0)}",
        f"",
        f"## Summary",
        f"",
        f"| Metric | With Skill | Without Skill | Delta |",
        f"|--------|------------|---------------|-------|",
    ]

    def fmt_val(val: dict) -> str:
        return f"{val.get('mean', 0):.3f} ± {val.get('stddev', 0):.3f}"

    for metric, label in [("pass_rate", "Pass Rate"), ("time_seconds", "Time (s)"), ("tokens", "Tokens")]:
        with_skill = rs.get("with_skill", {}).get(metric, {})
        without_skill = rs.get("without_skill", {}).get(metric, {})
        delta = rs.get("delta", {}).get(metric, {})
        lines.append(
            f"| {label} | {fmt_val(with_skill)} | {fmt_val(without_skill)} | {fmt_val(delta)} |"
        )

    lines.extend([
        "",
        "## Configuration Details",
        "",
        f"### With Skill",
        f"- Pass rate: {fmt_val(rs.get('with_skill', {}).get('pass_rate', {}))}",
        f"- Avg time: {fmt_val(rs.get('with_skill', {}).get('time_seconds', {}))}",
        f"- Avg tokens: {fmt_val(rs.get('with_skill', {}).get('tokens', {}))}",
        "",
        f"### Without Skill",
        f"- Pass rate: {fmt_val(rs.get('without_skill', {}).get('pass_rate', {}))}",
        f"- Avg time: {fmt_val(rs.get('without_skill', {}).get('time_seconds', {}))}",
        f"- Avg tokens: {fmt_val(rs.get('without_skill', {}).get('tokens', {}))}",
        "",
        f"### Delta (With - Without)",
        f"- Pass rate: {fmt_val(rs.get('delta', {}).get('pass_rate', {}))}",
        f"- Time: {fmt_val(rs.get('delta', {}).get('time_seconds', {}))}",
        f"- Tokens: {fmt_val(rs.get('delta', {}).get('tokens', {}))}",
    ])

    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description="Aggregate benchmark results")
    parser.add_argument("workspace", type=str, help="Path to workspace directory")
    parser.add_argument("--iteration", "-i", type=int, default=None,
                        help="Specific iteration number (default: latest)")
    args = parser.parse_args()

    workspace_path = Path(args.workspace)
    if not workspace_path.is_dir():
        print(f"Error: workspace not found: {workspace_path}", file=sys.stderr)
        sys.exit(1)

    if args.iteration is not None:
        target_dir = workspace_path / f"iteration-{args.iteration}"
        if not target_dir.is_dir():
            print(f"Error: iteration directory not found: {target_dir}", file=sys.stderr)
            sys.exit(1)
        benchmark = aggregate_results(target_dir)
    else:
        benchmark = aggregate_results(workspace_path)

    # Write benchmark.json
    benchmark_json_path = workspace_path / "benchmark.json"
    benchmark_json_path.write_text(
        json.dumps(benchmark, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(f"Wrote {benchmark_json_path}")

    # Write benchmark.md
    benchmark_md_path = workspace_path / "benchmark.md"
    benchmark_md_path.write_text(generate_markdown(benchmark), encoding="utf-8")
    print(f"Wrote {benchmark_md_path}")


if __name__ == "__main__":
    main()
