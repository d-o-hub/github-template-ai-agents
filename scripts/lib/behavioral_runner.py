"""Paired-run execution for `scripts/behavioral-eval.py`.

The runner is provider-agnostic: it never calls a model itself. It hands one
task at a time to an operator-supplied adapter command, whose stdout must be a
single `behavioral-eval/v1` result document. A missing adapter, a crashed
adapter, or malformed output is reported as blocked/not-run or a contract error;
it is never converted into a passing case.

Artifacts: prompts and raw adapter output may contain secrets or personal data.
Prompts are withheld from stored artifacts unless `--include-prompts` is given,
credentials are redacted, stdout/stderr are truncated, and token/cost numbers
are recorded only when the adapter reported them.
"""

from __future__ import annotations

import json
import shlex
import shutil
import subprocess
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from lib.behavioral_contract import (
    CONFIGURATIONS,
    CANDIDATE_BASELINE_FILENAME,
    UNAVAILABLE,
    ContractError,
    fixture_digest,
    redact,
    sha256_text,
    skill_digest,
    validate_result,
    validate_usage,
)

MAX_ARTIFACT_CHARS = 20000
DEFAULT_TIMEOUT_SECONDS = 900
TASKS_DIRNAME = "tasks"
WORKSPACE_DIRNAME = "workspace"
FIXTURES_DIRNAME = "fixtures"


@dataclass
class Task:
    """One case executed in one configuration."""

    case: dict[str, Any]
    configuration: str
    task_dir: Path = field(default_factory=Path)

    @property
    def label(self) -> str:
        return f"case-{self.case['id']}/{self.configuration}"


@dataclass
class Outcome:
    """Execution outcome for one task."""

    task: Task
    result: dict[str, Any] | None
    error: str | None
    duration_ms: float


def build_plan(
    skill_path: Path,
    cases: list[dict[str, Any]],
    *,
    provider: dict[str, Any],
    include_prompts: bool = False,
    configurations: tuple[str, ...] = CONFIGURATIONS,
) -> dict[str, Any]:
    """Build the paired run plan without executing anything."""
    if not cases:
        raise ContractError("no cases selected for the behavioral run")
    skill_reference = {
        "name": skill_path.name,
        "path": skill_path.as_posix(),
        "digest": skill_digest(skill_path),
        "fixture_digest": fixture_digest(skill_path, cases),
    }
    plan_cases = []
    for case in cases:
        entry: dict[str, Any] = {
            "id": case["id"],
            "bucket": case["bucket"],
            "prompt_digest": sha256_text(case["prompt"]),
            "prompt_chars": len(case["prompt"]),
            "assertions": case["assertions"],
            "files": case["files"],
            "configurations": list(configurations),
        }
        if include_prompts:
            entry["prompt"] = redact(case["prompt"])
            entry["expected_output"] = redact(case["expected_output"])
        plan_cases.append(entry)
    return {
        "schema_version": "behavioral-eval/v1",
        "scope": "behavioral_paired_plan",
        "skill": skill_reference,
        "fixtures": {"digest": skill_reference["fixture_digest"]},
        "provider": provider,
        "configurations": list(configurations),
        "cases": plan_cases,
        "tasks": [
            {"case_id": case["id"], "configuration": configuration}
            for case in cases
            for configuration in configurations
        ],
        "prompt_capture": "included" if include_prompts else "withheld",
    }


def build_tasks(plan: dict[str, Any], cases: list[dict[str, Any]], output_dir: Path) -> list[Task]:
    """Pair plan tasks with their case payloads and artifact directories."""
    by_id = {case["id"]: case for case in cases}
    tasks: list[Task] = []
    for entry in plan["tasks"]:
        case = by_id[entry["case_id"]]
        task_dir = output_dir / TASKS_DIRNAME / f"case-{case['id']}" / entry["configuration"]
        tasks.append(Task(case=case, configuration=entry["configuration"], task_dir=task_dir))
    return tasks


def build_task_payload(
    plan: dict[str, Any],
    task: Task,
    skill_path: Path,
    *,
    include_prompts: bool,
) -> dict[str, Any]:
    """Build the adapter payload for one task, staging its fixtures locally."""
    fixtures: list[dict[str, str]] = []
    for name in task.case["files"]:
        source = skill_path / name
        if not source.is_file():
            raise ContractError(f"case {task.case['id']} references a missing fixture: {name}")
        target = task.task_dir / FIXTURES_DIRNAME / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        fixtures.append({"name": name, "path": target.as_posix()})
    case_payload: dict[str, Any] = {
        "id": task.case["id"],
        "bucket": task.case["bucket"],
        "prompt": task.case["prompt"],
        "expected_output": task.case["expected_output"],
        "assertions": task.case["assertions"],
        "fixtures": fixtures,
    }
    return {
        "schema_version": plan["schema_version"],
        "skill_name": plan["skill"]["name"],
        "skill_path": skill_path.as_posix(),
        "skill_digest": plan["skill"]["digest"],
        "configuration": task.configuration,
        "workspace": (task.task_dir / WORKSPACE_DIRNAME).as_posix(),
        "provider": plan["provider"],
        "case": case_payload,
        "prompt_capture": "included" if include_prompts else "withheld",
    }


def store_plan_artifact(plan: dict[str, Any], output_dir: Path, *, include_prompts: bool) -> None:
    """Write the plan artifact, withholding prompts unless explicitly enabled."""
    stored = json.loads(json.dumps(plan))
    if not include_prompts:
        for entry in stored["cases"]:
            entry.pop("prompt", None)
            entry.pop("expected_output", None)
    write_text(output_dir / "plan.json", json.dumps(_redact_tree(stored), indent=2))


def execute_task(
    task: Task,
    payload: dict[str, Any],
    adapter_command: str,
    *,
    cwd: Path,
    timeout: int,
    include_prompts: bool,
) -> Outcome:
    """Run one adapter invocation and validate its result document."""
    task.task_dir.mkdir(parents=True, exist_ok=True)
    (task.task_dir / WORKSPACE_DIRNAME).mkdir(exist_ok=True)
    stored_payload = json.loads(json.dumps(payload))
    if not include_prompts:
        stored_payload["case"]["prompt"] = (
            f"<withheld; sha256 of the prompt: {sha256_text(task.case['prompt'])}>"
        )
        stored_payload["case"]["expected_output"] = "<withheld>"
    write_text(task.task_dir / "task.json", json.dumps(_redact_tree(stored_payload), indent=2))
    try:
        argv = shlex.split(adapter_command)
    except ValueError as exc:
        raise ContractError(f"adapter command is not parseable: {exc}") from None
    if not argv:
        raise ContractError("adapter command is empty")
    start = time.time()
    try:
        completed = subprocess.run(
            argv,
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(cwd),
        )
    except subprocess.TimeoutExpired:
        write_text(task.task_dir / "adapter.stderr", f"adapter timed out after {timeout}s\n")
        return Outcome(task, None, f"adapter timed out after {timeout}s", (time.time() - start) * 1000)
    except OSError as exc:
        write_text(task.task_dir / "adapter.stderr", f"adapter could not start: {redact(str(exc))}\n")
        return Outcome(task, None, f"adapter could not start: {exc}", (time.time() - start) * 1000)
    duration_ms = (time.time() - start) * 1000
    if completed.stderr.strip():
        write_text(
            task.task_dir / "adapter.stderr",
            redact(completed.stderr)[:MAX_ARTIFACT_CHARS],
        )
    raw = completed.stdout.strip()
    error = _parse_adapter_stdout(task, raw, completed.returncode)
    if error is not None:
        write_text(task.task_dir / "adapter.stdout", redact(raw)[:MAX_ARTIFACT_CHARS])
        return Outcome(task, None, error, duration_ms)
    result = json.loads(raw)
    issues = validate_result(result, payload["skill_name"], {task.case["id"]}) + validate_usage(
        result.get("usage")
    )
    if issues:
        write_text(task.task_dir / "adapter.stdout", redact(raw)[:MAX_ARTIFACT_CHARS])
        return Outcome(
            task, None, f"adapter result violated the contract: {'; '.join(issues)}", duration_ms
        )
    if result.get("duration_ms") is None:
        result["duration_ms"] = round(duration_ms, 3)
        result["duration_source"] = "runner_wall_clock"
    else:
        result["duration_source"] = "adapter"
    write_text(task.task_dir / "result.json", json.dumps(_redact_tree(result), indent=2))
    return Outcome(task, result, None, duration_ms)


def _parse_adapter_stdout(task: Task, raw: str, returncode: int) -> str | None:
    """Reject empty, non-JSON, or multiple-document adapter output."""
    if not raw:
        return f"adapter produced no output (exit code {returncode})"
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        return f"adapter stdout is not a single JSON object: {exc.msg} at line {exc.lineno}"
    if not isinstance(parsed, dict):
        return "adapter stdout must be a single JSON object"
    return None


def run_tasks(
    tasks: list[Task],
    plan: dict[str, Any],
    skill_path: Path,
    adapter_command: str,
    *,
    cwd: Path,
    timeout: int = DEFAULT_TIMEOUT_SECONDS,
    include_prompts: bool = False,
) -> list[Outcome]:
    """Execute every planned task sequentially, one adapter process per task."""
    outcomes: list[Outcome] = []
    for task in tasks:
        payload = build_task_payload(plan, task, skill_path, include_prompts=include_prompts)
        outcomes.append(
            execute_task(
                task,
                payload,
                adapter_command,
                cwd=cwd,
                timeout=timeout,
                include_prompts=include_prompts,
            )
        )
    return outcomes


def write_text(path: Path, text: str) -> None:
    """Write artifact text, creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_candidate_baseline(output_dir: Path, candidate: dict[str, Any]) -> Path:
    """Write a candidate baseline for review; never the accepted baseline."""
    path = output_dir / CANDIDATE_BASELINE_FILENAME
    write_text(path, json.dumps(candidate, indent=2))
    return path


def _redact_tree(value: Any) -> Any:
    """Redact every string in a JSON-like structure before it is stored."""
    if isinstance(value, str):
        return redact(value)
    if isinstance(value, dict):
        return {key: _redact_tree(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_redact_tree(item) for item in value]
    return value


def unavailable_provider() -> dict[str, Any]:
    """Provider metadata that was not supplied stays explicitly unavailable."""
    return {"name": UNAVAILABLE, "model": UNAVAILABLE, "observed": False}
