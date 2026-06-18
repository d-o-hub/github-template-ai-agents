#!/usr/bin/env python3
"""Generate a static HTML review page for eval results."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def collect_outputs(workspace_path: Path, skill_name: str) -> list[dict]:
    """Collect eval outputs from the workspace iteration structure."""
    iteration_dirs = sorted(
        [d for d in workspace_path.iterdir() if d.is_dir() and d.name.startswith("iteration-")],
        key=lambda d: int(d.name.split("-")[1]),
    )
    if not iteration_dirs:
        print(f"Warning: No iteration directories found in {workspace_path}", file=sys.stderr)
        return []

    latest = iteration_dirs[-1]
    eval_cases: list[dict] = []
    for eval_dir in sorted(
        [d for d in latest.iterdir() if d.is_dir() and d.name.startswith("eval-")],
    ):
        eval_id = int(eval_dir.name.split("-")[1])
        case: dict = {"id": eval_id, "outputs": []}
        for config_name in ("with_skill", "without_skill"):
            config_dir = eval_dir / config_name / "outputs"
            if config_dir.is_dir():
                output_texts = []
                for output_file in sorted(config_dir.iterdir()):
                    if output_file.is_file():
                        output_texts.append(output_file.read_text(encoding="utf-8"))
                case["outputs"].append({
                    "config": config_name,
                    "text": "\n".join(output_texts),
                })
        metadata_file = eval_dir / "eval_metadata.json"
        if metadata_file.is_file():
            case["metadata"] = json.loads(metadata_file.read_text(encoding="utf-8"))
        eval_cases.append(case)
    return eval_cases


def collect_grading(workspace_path: Path) -> list[dict]:
    """Collect grading.json files from the workspace."""
    gradings: list[dict] = []
    for grading_file in workspace_path.rglob("grading.json"):
        gradings.append(json.loads(grading_file.read_text(encoding="utf-8")))
    return sorted(gradings, key=lambda g: g.get("eval_id", 0))


def collect_timing(workspace_path: Path) -> list[dict]:
    """Collect timing.json files from the workspace."""
    timings: list[dict] = []
    for timing_file in workspace_path.rglob("timing.json"):
        timings.append(json.loads(timing_file.read_text(encoding="utf-8")))
    return sorted(timings, key=lambda t: t.get("eval_id", 0))


def generate_html(
    skill_name: str,
    eval_cases: list[dict],
    gradings: list[dict],
    benchmark: dict | None,
) -> str:
    """Generate a standalone HTML review page."""
    cases_json = json.dumps(eval_cases, indent=2)
    gradings_json = json.dumps(gradings, indent=2)
    benchmark_json = json.dumps(benchmark or {}, indent=2)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Eval Review - {skill_name}</title>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; background: #f5f5f5; }}
  h1, h2 {{ color: #1a1a2e; }}
  .tabs {{ display: flex; gap: 0; margin-bottom: 20px; }}
  .tab {{ padding: 10px 20px; cursor: pointer; border: 1px solid #ccc; background: #e0e0e0; }}
  .tab.active {{ background: #fff; border-bottom: 2px solid #4a6fa5; font-weight: bold; }}
  .tab-content {{ display: none; }}
  .tab-content.active {{ display: block; }}
  .case {{ background: #fff; border: 1px solid #ddd; border-radius: 6px; padding: 16px; margin-bottom: 16px; }}
  .case h3 {{ margin-top: 0; }}
  .output {{ background: #f8f9fa; border: 1px solid #e0e0e0; border-radius: 4px; padding: 12px; margin: 8px 0; white-space: pre-wrap; font-family: monospace; font-size: 13px; max-height: 400px; overflow-y: auto; }}
  .pass {{ color: #2e7d32; font-weight: bold; }}
  .fail {{ color: #c62828; font-weight: bold; }}
  .evidence {{ font-size: 12px; color: #555; background: #f0f0f0; padding: 4px 8px; border-radius: 3px; }}
  .benchmark-table {{ width: 100%; border-collapse: collapse; }}
  .benchmark-table th, .benchmark-table td {{ border: 1px solid #ddd; padding: 8px; text-align: right; }}
  .benchmark-table th {{ background: #4a6fa5; color: white; }}
  .benchmark-table td:first-child {{ text-align: left; font-weight: bold; }}
  .delta-positive {{ color: #2e7d32; }}
  .delta-negative {{ color: #c62828; }}
  textarea {{ width: 100%; min-height: 60px; font-family: monospace; font-size: 12px; }}
</style>
</head>
<body>
<h1>Eval Review: {skill_name}</h1>

<div class="tabs">
  <div class="tab active" onclick="switchTab('outputs')">Outputs</div>
  <div class="tab" onclick="switchTab('benchmark')">Benchmark</div>
</div>

<div id="tab-outputs" class="tab-content active">
  <h2>Test Case Outputs</h2>
  <div id="cases-container"></div>
</div>

<div id="tab-benchmark" class="tab-content">
  <h2>Benchmark Results</h2>
  <div id="benchmark-container"></div>
</div>

<script>
const CASES = {cases_json};
const GRADINGS = {gradings_json};
const BENCHMARK = {benchmark_json};

function switchTab(name) {{
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
  document.querySelector(`.tab[onclick*="'${{name}}'"]`).classList.add('active');
  document.getElementById(`tab-${{name}}`).classList.add('active');
}}

function renderCases() {{
  const container = document.getElementById('cases-container');
  CASES.forEach(c => {{
    const grading = GRADINGS.find(g => g.eval_id === c.id);
    const div = document.createElement('div');
    div.className = 'case';
    div.innerHTML = `<h3>Eval #${{c.id}}</h3>
      <p><strong>Prompt:</strong> ${{c.metadata?.prompt || '(no metadata)'}}</p>
      ${{c.outputs.map(o => `
        <h4>${{o.config}}</h4>
        <div class="output">${{o.text || '(no output)'}}</div>
      `).join('')}}
      ${{grading ? `
        <h4>Assertions</h4>
        ${{grading.assertion_results?.map(a => `
          <div class="${{a.passed ? 'pass' : 'fail'}}">
            ${{a.passed ? 'PASS' : 'FAIL'}}: ${{a.assertion}}
            <div class="evidence">${{a.evidence || ''}}</div>
          </div>
        `).join('') || ''}}
        <p>Pass rate: <strong>${{(grading.summary?.pass_rate * 100).toFixed(0)}}%</strong>
          (${{grading.summary?.passed}}/${{grading.summary?.total}})</p>
      ` : '<p>No grading data</p>'}}
      <h4>Feedback</h4>
      <textarea placeholder="Enter feedback for this eval case..."></textarea>
    `;
    container.appendChild(div);
  }});
}}

function renderBenchmark() {{
  const container = document.getElementById('benchmark-container');
  if (!BENCHMARK.run_summary) {{
    container.innerHTML = '<p>No benchmark data available.</p>';
    return;
  }}
  const rs = BENCHMARK.run_summary;
  const fmt = (v, d=2) => (v || 0).toFixed(d);
  const deltaClass = (v) => v > 0 ? 'delta-positive' : v < 0 ? 'delta-negative' : '';
  container.innerHTML = `
    <table class="benchmark-table">
      <tr><th>Metric</th><th>With Skill</th><th>Without Skill</th><th>Delta</th></tr>
      <tr><td>Pass Rate</td>
        <td>${{fmt(rs.with_skill?.pass_rate?.mean)}} &plusmn; ${{fmt(rs.with_skill?.pass_rate?.stddev)}}</td>
        <td>${{fmt(rs.without_skill?.pass_rate?.mean)}} &plusmn; ${{fmt(rs.without_skill?.pass_rate?.stddev)}}</td>
        <td class="${{deltaClass(rs.delta?.pass_rate?.mean)}}">${{fmt(rs.delta?.pass_rate?.mean)}} &plusmn; ${{fmt(rs.delta?.pass_rate?.stddev)}}</td></tr>
      <tr><td>Time (s)</td>
        <td>${{fmt(rs.with_skill?.time_seconds?.mean, 1)}} &plusmn; ${{fmt(rs.with_skill?.time_seconds?.stddev, 1)}}</td>
        <td>${{fmt(rs.without_skill?.time_seconds?.mean, 1)}} &plusmn; ${{fmt(rs.without_skill?.time_seconds?.stddev, 1)}}</td>
        <td class="${{deltaClass(-rs.delta?.time_seconds?.mean)}}">${{fmt(rs.delta?.time_seconds?.mean, 1)}} &plusmn; ${{fmt(rs.delta?.time_seconds?.stddev, 1)}}</td></tr>
      <tr><td>Tokens</td>
        <td>${{fmt(rs.with_skill?.tokens?.mean, 0)}} &plusmn; ${{fmt(rs.with_skill?.tokens?.stddev, 0)}}</td>
        <td>${{fmt(rs.without_skill?.tokens?.mean, 0)}} &plusmn; ${{fmt(rs.without_skill?.tokens?.stddev, 0)}}</td>
        <td class="${{deltaClass(-rs.delta?.tokens?.mean)}}">${{fmt(rs.delta?.tokens?.mean, 0)}} &plusmn; ${{fmt(rs.delta?.tokens?.stddev, 0)}}</td></tr>
    </table>
  `;
}}

renderCases();
renderBenchmark();
</script>
</body>
</html>"""


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate eval review HTML page")
    parser.add_argument("--workspace", "-w", type=str, required=True,
                        help="Path to skill workspace directory")
    parser.add_argument("--skill-name", "-n", type=str, required=True,
                        help="Name of the skill")
    parser.add_argument("--benchmark", "-b", type=str, default=None,
                        help="Path to benchmark.json (optional)")
    parser.add_argument("--previous-workspace", "-p", type=str, default=None,
                        help="Path to previous workspace for comparison (optional)")
    parser.add_argument("--static", "-s", type=str, default=None,
                        help="Output path for static HTML file")
    args = parser.parse_args()

    workspace_path = Path(args.workspace)
    if not workspace_path.is_dir():
        print(f"Error: workspace directory not found: {workspace_path}", file=sys.stderr)
        sys.exit(1)

    eval_cases = collect_outputs(workspace_path, args.skill_name)
    gradings = collect_grading(workspace_path)

    benchmark = None
    if args.benchmark:
        benchmark_path = Path(args.benchmark)
        if benchmark_path.is_file():
            benchmark = json.loads(benchmark_path.read_text(encoding="utf-8"))

    html = generate_html(args.skill_name, eval_cases, gradings, benchmark)
    output_path = Path(args.static) if args.static else workspace_path / "eval_review.html"
    output_path.write_text(html, encoding="utf-8")
    print(f"Review page generated: {output_path}")


if __name__ == "__main__":
    main()
