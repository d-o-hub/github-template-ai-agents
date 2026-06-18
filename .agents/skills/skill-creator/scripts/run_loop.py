#!/usr/bin/env python3
"""Description optimization loop for skill frontmatter."""
from __future__ import annotations

import argparse
import json
import random
import subprocess  # nosec  # nosemgrep
import sys
from pathlib import Path


def load_eval_set(path: str) -> list[dict]:
    """Load eval queries from a JSON file.

    Expected format: [{"query": "...", "should_trigger": true}, ...]
    """
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    if isinstance(data, dict) and "queries" in data:
        return data["queries"]
    if isinstance(data, list):
        return data
    raise ValueError("eval-set must be a list of queries or {queries: [...]}")


def split_train_validation(queries: list[dict], train_ratio: float = 0.6) -> tuple[list[dict], list[dict]]:
    """Split queries into train and validation sets."""
    shuffled = list(queries)
    random.shuffle(shuffled)
    split = int(len(shuffled) * train_ratio)
    return shuffled[:split], shuffled[split:]


def evaluate_description(
    description: str,
    queries: list[dict],
    skill_path: str,
    model: str,
) -> dict:
    """Evaluate a description against a set of queries.

    Runs each query 3x (configurable via future arg) and returns pass rates.
    Uses the `claude` CLI via subprocess.
    """
    results = {"true_positives": 0, "true_negatives": 0, "total": len(queries), "details": []}

    for q in queries:
        prompt = q["query"]
        should_trigger = q.get("should_trigger", True)

        for run_num in range(3):
            cmd = [
                "claude",
                "-p", prompt,
                "--skill", skill_path,
                "--model", model,
                "--json",
            ]
            try:
                # nosemgrep
                proc = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                output = proc.stdout
            except (subprocess.TimeoutExpired, FileNotFoundError) as exc:
                output = f"<error: {exc}>"

            triggered = "invoked" in output.lower() or skill_path.split("/")[-1] in output

            is_correct = triggered == should_trigger
            if is_correct:
                if should_trigger:
                    results["true_positives"] += 1
                else:
                    results["true_negatives"] += 1

            results["details"].append({
                "query": prompt,
                "should_trigger": should_trigger,
                "triggered": triggered,
                "run": run_num,
                "correct": is_correct,
            })

    total_checks = len(queries) * 3
    results["pass_rate"] = (results["true_positives"] + results["true_negatives"]) / total_checks
    return results


def propose_improvements(
    description: str,
    eval_results: dict,
    iterations_completed: int,
) -> str:
    """Use Claude to propose description improvements based on failures.

    Falls back to heuristic rules if Claude CLI is unavailable.
    """
    failures = [d for d in eval_results["details"] if not d["correct"]]
    if not failures:
        return description

    false_positives = [f for f in failures if f["triggered"] and not f["should_trigger"]]
    false_negatives = [f for f in failures if not f["triggered"] and f["should_trigger"]]

    improvement_hints = []
    if false_positives:
        improvement_hints.append(
            f"False triggers ({len(false_positives)}): "
            f"{', '.join(f['query'][:60] for f in false_positives[:3])}"
        )
    if false_negatives:
        improvement_hints.append(
            f"Missed triggers ({len(false_negatives)}): "
            f"{', '.join(f['query'][:60] for f in false_negatives[:3])}"
        )

    prompt = (
        "I am optimizing the frontmatter description for an AI agent skill.\n\n"
        f"Current description: \"{description}\"\n\n"
        f"Iteration {iterations_completed + 1} results:\n"
        f"Pass rate: {eval_results['pass_rate']:.1%}\n"
        f"Total checks: {eval_results['total'] * 3}\n"
        + "\n".join(improvement_hints) +
        "\n\n"
        "Suggest an improved description (max 1024 characters) that:\n"
        "1. Uses imperative phrasing ('Use this skill when...')\n"
        "2. Lists specific trigger scenarios\n"
        '3. Includes near-miss keywords to avoid false triggers\n'
        "4. Keeps the overall structure: [action verb] [what it does]. Use when [scenarios].\n"
        "Output ONLY the new description text, nothing else."
    )

    try:
        # nosemgrep
        proc = subprocess.run(
            ["claude", "-p", prompt, "--model", "sonnet", "--json"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        result = proc.stdout.strip()
        # Strip JSON wrapper if present
        if result.startswith("{"):
            try:
                parsed = json.loads(result)
                result = parsed.get("text", parsed.get("content", result))
            except json.JSONDecodeError:
                pass
        if len(result) > 1024:
            result = result[:1024]
        return result if result else description
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return _heuristic_improve(description, false_positives, false_negatives)


def _heuristic_improve(description: str, false_positives: list, false_negatives: list) -> str:
    """Fallback improvement when Claude CLI is unavailable."""
    improved = description
    if false_negatives:
        missing_context = false_negatives[0]["query"][:60]
        if "Use when" in improved:
            improved = improved.replace("Use when", f"Use when dealing with {missing_context} or when")
        else:
            improved += f" Use when {missing_context}."
    if false_positives:
        fp_context = false_positives[0]["query"][:60]
        improved += f" Do not use for {fp_context}."
    return improved[:1024]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Optimize skill description via iterative eval loop"
    )
    parser.add_argument("--eval-set", type=str, required=True,
                        help="Path to eval queries JSON file")
    parser.add_argument("--skill-path", type=str, required=True,
                        help="Path to skill directory")
    parser.add_argument("--model", type=str, default="sonnet",
                        help="Model name for evaluation (default: sonnet)")
    parser.add_argument("--max-iterations", type=int, default=5,
                        help="Maximum optimization iterations (default: 5)")
    parser.add_argument("--verbose", action="store_true",
                        help="Print detailed progress")
    args = parser.parse_args()

    skill_path_obj = Path(args.skill_path)
    skill_md = skill_path_obj / "SKILL.md"
    if not skill_md.is_file():
        print(f"Error: SKILL.md not found at {skill_md}", file=sys.stderr)
        sys.exit(1)

    queries = load_eval_set(args.eval_set)
    if len(queries) < 4:
        print("Error: eval-set must contain at least 4 queries", file=sys.stderr)
        sys.exit(1)

    train_set, validation_set = split_train_validation(queries)

    # Extract current description
    frontmatter = skill_md.read_text(encoding="utf-8")
    current_desc = ""
    for line in frontmatter.splitlines():
        if line.startswith("description:"):
            current_desc = line.split(":", 1)[1].strip().strip('"').strip("'")
            break

    if not current_desc:
        print("Error: Could not find description in SKILL.md frontmatter", file=sys.stderr)
        sys.exit(1)

    if args.verbose:
        print(f"Starting optimization with {len(train_set)} train / {len(validation_set)} validation queries")
        print(f"Current description: {current_desc[:80]}...")

    candidates: list[tuple[str, float]] = [(current_desc, 0.0)]

    for iteration in range(args.max_iterations):
        best_desc = candidates[-1][0]

        if args.verbose:
            print(f"\nIteration {iteration + 1}/{args.max_iterations}")

        train_results = evaluate_description(best_desc, train_set, args.skill_path, args.model)
        train_pass_rate = train_results["pass_rate"]

        if args.verbose:
            print(f"  Train pass rate: {train_pass_rate:.1%}")

        if train_pass_rate >= 0.95:
            if args.verbose:
                print("  Early stop: train pass rate >= 95%")
            break

        improved = propose_improvements(best_desc, train_results, iteration)

        if improved == best_desc or len(improved) < 10:
            if args.verbose:
                print("  No improvement proposed, stopping")
            break

        candidates.append((improved, 0.0))

    # Select best by validation score
    if args.verbose:
        print("\nSelecting best description by validation score...")

    best_score = -1.0
    best_description = candidates[0][0]

    for desc, _ in candidates:
        val_results = evaluate_description(desc, validation_set, args.skill_path, args.model)
        score = val_results["pass_rate"]
        if args.verbose:
            print(f"  Validation score: {score:.1%} for '{desc[:60]}...'")
        if score > best_score:
            best_score = score
            best_description = desc

    if args.verbose:
        validation_results = evaluate_description(best_description, validation_set, args.skill_path, args.model)
        print("\nFinal selection:")
        print(f"  Description: {best_description}")
        print(f"  Validation pass rate: {validation_results['pass_rate']:.1%}")
        print(f"  True positives: {validation_results['true_positives']}")
        print(f"  True negatives: {validation_results['true_negatives']}")

    print(best_description)


if __name__ == "__main__":
    main()
