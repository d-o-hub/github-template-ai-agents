"""Adapter library for paired behavioral evaluation of agent skills.

Provides data structures, digest calculation, paired execution orchestration,
baseline comparison, and blessing logic.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from lib.eval_types import EVAL_BUCKETS, EvalBucket, EvalStatus
from lib.eval_validators import load_evals_file, validate_evals_format
from lib.paths import PathValidationError, validate_canonical_name, validate_safe_path

UNAVAILABLE = "unavailable"


def calculate_file_sha256(filepath: Path) -> str:
    """Calculate SHA256 digest of a single file."""
    if not filepath.exists() or not filepath.is_file():
        return UNAVAILABLE
    hasher = hashlib.sha256()
    hasher.update(filepath.read_bytes())
    return f"sha256:{hasher.hexdigest()}"


def calculate_skill_content_digest(skill_path: Path) -> str:
    """Calculate aggregate SHA256 digest of skill definition files."""
    if not skill_path.exists() or not skill_path.is_dir():
        return UNAVAILABLE
    hasher = hashlib.sha256()
    files_to_hash: List[Path] = []
    for root, _, files in os.walk(skill_path):
        for fname in sorted(files):
            p = Path(root) / fname
            if fname in ("SKILL.md", "evals.json") or p.suffix in (".py", ".sh", ".md", ".json"):
                files_to_hash.append(p)
    files_to_hash.sort()
    for fp in files_to_hash:
        rel = fp.relative_to(skill_path)
        hasher.update(str(rel).encode("utf-8"))
        hasher.update(fp.read_bytes())
    return f"sha256:{hasher.hexdigest()}"


@dataclass
class AssertionResult:
    text: str
    passed: bool
    evidence: str = ""


@dataclass
class ArmExecutionResult:
    status: str  # PASS, FAIL, BLOCKED, NOT_RUN
    assertions: List[Dict[str, Any]] = field(default_factory=list)
    output: str = ""
    skill_loaded: bool = False
    error: Optional[str] = None


@dataclass
class CaseExecutionResult:
    case_id: int
    bucket: str
    prompt: str
    expected_output: str
    with_skill: Dict[str, Any]
    without_skill: Dict[str, Any]
    passed: bool
    message: str = ""


class PairedEvalAdapter:
    """Adapter for running paired behavioral evaluations and checking baselines."""

    def __init__(
        self,
        skills_dir: Path,
        baselines_dir: Path,
        agent_cmd: Optional[str] = None,
        provider: Optional[str] = None,
        model_id: Optional[str] = None,
    ):
        self.skills_dir = skills_dir
        self.baselines_dir = baselines_dir
        self.agent_cmd = agent_cmd
        self.provider = provider or os.environ.get("AGENT_PROVIDER", UNAVAILABLE)
        self.model_id = model_id or os.environ.get("AGENT_MODEL_ID", UNAVAILABLE)

    def load_skill_evals(self, skill_name: str) -> Tuple[Optional[dict], Optional[Path], List[str]]:
        """Validate and load evals.json for a skill."""
        try:
            skill_path = validate_canonical_name(skill_name, self.skills_dir, "skill")
        except PathValidationError as e:
            return None, None, [str(e)]
        evals_path = skill_path / "evals" / "evals.json"
        data, err = load_evals_file(evals_path)
        if err:
            return None, skill_path, [err]
        if data is None:
            return None, skill_path, ["Failed to load evals.json"]
        issues = validate_evals_format(data, skill_name, skill_path)
        if issues:
            return None, skill_path, issues
        return data, skill_path, []

    def run_case_arm(
        self,
        case: dict,
        skill_path: Path,
        with_skill: bool,
        mock_outcomes: Optional[dict] = None,
    ) -> ArmExecutionResult:
        """Execute a single arm (with_skill or without_skill) for an eval case."""
        case_id = case.get("id", 0)
        bucket = case.get("bucket", EvalBucket.EXPLICIT.value)
        assertions_text = case.get("assertions", [])

        if mock_outcomes:
            arm_key = "with_skill" if with_skill else "without_skill"
            outcome = mock_outcomes.get(case_id, {}).get(arm_key, {})
            if outcome:
                return ArmExecutionResult(
                    status=outcome.get("status", "PASS"),
                    assertions=outcome.get("assertions", []),
                    output=outcome.get("output", "Mock output"),
                    skill_loaded=outcome.get("skill_loaded", with_skill and bucket != EvalBucket.NEGATIVE.value),
                    error=outcome.get("error"),
                )

        if not self.agent_cmd:
            return ArmExecutionResult(
                status="BLOCKED",
                assertions=[
                    {"text": a, "passed": False, "evidence": "Execution blocked: no model/agent_cmd configured"}
                    for a in assertions_text
                ],
                output="",
                skill_loaded=False,
                error="Model execution unconfigured; returning BLOCKED status without fabricating output.",
            )

        cmd = self.agent_cmd.format(
            prompt=case.get("prompt", ""),
            skill_path=str(skill_path),
            with_skill="1" if with_skill else "0",
            case_id=case_id,
        )
        try:
            res = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=120)
            if res.returncode != 0:
                return ArmExecutionResult(
                    status="FAIL",
                    assertions=[
                        {"text": a, "passed": False, "evidence": f"Agent process failed: {res.stderr.strip()}"}
                        for a in assertions_text
                    ],
                    output=res.stdout,
                    skill_loaded=False,
                    error=res.stderr,
                )
            raw_output = res.stdout
            graded_assertions = []
            all_pass = True
            for a in assertions_text:
                p = a.lower() in raw_output.lower()
                graded_assertions.append(
                    {"text": a, "passed": p, "evidence": f"Output checked against assertion '{a}'"}
                )
                if not p:
                    all_pass = False
            return ArmExecutionResult(
                status="PASS" if all_pass else "FAIL",
                assertions=graded_assertions,
                output=raw_output,
                skill_loaded=with_skill,
            )
        except Exception as e:
            return ArmExecutionResult(
                status="BLOCKED",
                assertions=[
                    {"text": a, "passed": False, "evidence": f"Execution error: {e}"}
                    for a in assertions_text
                ],
                error=str(e),
            )

    def evaluate_skill_paired(
        self,
        skill_name: str,
        mock_outcomes: Optional[dict] = None,
    ) -> Dict[str, Any]:
        """Run paired behavioral evaluation for a skill."""
        evals_data, skill_path, errors = self.load_skill_evals(skill_name)
        timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        if errors or evals_data is None or skill_path is None:
            return {
                "version": "1.0.0",
                "evaluation_type": "paired_behavioral",
                "timestamp": timestamp,
                "skill": {
                    "name": skill_name,
                    "content_digest": UNAVAILABLE,
                    "fixture_digest": UNAVAILABLE,
                },
                "environment": {
                    "provider": self.provider,
                    "model_id": self.model_id,
                    "agent_cmd": self.agent_cmd or UNAVAILABLE,
                },
                "summary": {
                    "status": "FAIL",
                    "errors": errors,
                    "total_cases": 0,
                    "passed_cases": 0,
                    "failed_cases": 0,
                    "blocked_cases": 0,
                    "pass_rate_with_skill": 0.0,
                    "pass_rate_without_skill": 0.0,
                    "skill_lift": 0.0,
                },
                "metrics": {
                    "duration_ms": UNAVAILABLE,
                    "total_tokens": UNAVAILABLE,
                    "total_cost_usd": UNAVAILABLE,
                },
                "cases": [],
            }

        evals = evals_data.get("evals", [])
        skill_digest = calculate_skill_content_digest(skill_path)
        fixture_digest = calculate_file_sha256(skill_path / "evals" / "evals.json")

        case_results = []
        passed_count = 0
        failed_count = 0
        blocked_count = 0
        with_skill_passes = 0
        without_skill_passes = 0

        for case in evals:
            cid = case.get("id", 0)
            bucket = case.get("bucket", EvalBucket.EXPLICIT.value)
            prompt = case.get("prompt", "")
            exp_out = case.get("expected_output", "")

            with_res = self.run_case_arm(case, skill_path, with_skill=True, mock_outcomes=mock_outcomes)
            without_res = self.run_case_arm(case, skill_path, with_skill=False, mock_outcomes=mock_outcomes)

            if bucket == EvalBucket.NEGATIVE.value and with_res.skill_loaded:
                with_res.status = "FAIL"
                with_res.assertions.append({
                    "text": "Target skill must stay unloaded for out-of-scope negative case",
                    "passed": False,
                    "evidence": "False positive: target skill was activated on out-of-scope prompt"
                })

            case_passed = (with_res.status == "PASS")
            if with_res.status == "BLOCKED":
                blocked_count += 1
            elif case_passed:
                passed_count += 1
                with_skill_passes += 1
            else:
                failed_count += 1

            if without_res.status == "PASS":
                without_skill_passes += 1

            case_results.append({
                "id": cid,
                "bucket": bucket,
                "prompt": prompt,
                "expected_output": exp_out,
                "with_skill": asdict(with_res),
                "without_skill": asdict(without_res),
                "passed": case_passed,
                "message": f"With-skill: {with_res.status}, Without-skill: {without_res.status}",
            })

        total = len(evals)
        pass_rate_with = (with_skill_passes / total) if total > 0 else 0.0
        pass_rate_without = (without_skill_passes / total) if total > 0 else 0.0
        skill_lift = pass_rate_with - pass_rate_without

        if blocked_count == total and total > 0:
            agg_status = "BLOCKED"
        elif failed_count > 0:
            agg_status = "FAIL"
        else:
            agg_status = "PASS"

        blessed_baseline = self.get_blessed_baseline(skill_name)
        baseline_comp = self.compare_baseline(blessed_baseline, pass_rate_with, case_results)
        if baseline_comp.get("regression_detected") and agg_status == "PASS":
            agg_status = "REGRESSION"

        return {
            "version": "1.0.0",
            "evaluation_type": "paired_behavioral",
            "timestamp": timestamp,
            "skill": {
                "name": skill_name,
                "content_digest": skill_digest,
                "fixture_digest": fixture_digest,
            },
            "environment": {
                "provider": self.provider,
                "model_id": self.model_id,
                "agent_cmd": self.agent_cmd or UNAVAILABLE,
            },
            "summary": {
                "status": agg_status,
                "total_cases": total,
                "passed_cases": passed_count,
                "failed_cases": failed_count,
                "blocked_cases": blocked_count,
                "pass_rate_with_skill": pass_rate_with,
                "pass_rate_without_skill": pass_rate_without,
                "skill_lift": skill_lift,
                "baseline_comparison": baseline_comp,
            },
            "metrics": {
                "duration_ms": UNAVAILABLE,
                "total_tokens": UNAVAILABLE,
                "total_cost_usd": UNAVAILABLE,
            },
            "cases": case_results,
        }

    def get_blessed_baseline(self, skill_name: str) -> Optional[dict]:
        """Load blessed baseline if it exists."""
        blessed_file = self.baselines_dir / f"{skill_name}.json"
        if not blessed_file.exists():
            return None
        try:
            return json.loads(blessed_file.read_text(encoding="utf-8"))
        except Exception:
            return None

    def compare_baseline(
        self, blessed_baseline: Optional[dict], current_pass_rate: float, case_results: List[dict]
    ) -> dict:
        """Compare current results against blessed baseline."""
        if blessed_baseline is None:
            return {
                "blessed_baseline_found": False,
                "blessed_pass_rate": None,
                "delta_from_baseline": None,
                "regression_detected": False,
                "details": "No blessed baseline found for comparison.",
            }

        blessed_summary = blessed_baseline.get("summary", {})
        blessed_pass_rate = blessed_summary.get("pass_rate_with_skill", 1.0)
        delta = current_pass_rate - blessed_pass_rate

        regression = False
        reasons = []

        if current_pass_rate < blessed_pass_rate:
            regression = True
            reasons.append(
                f"Pass rate dropped from {blessed_pass_rate:.2f} (blessed) to {current_pass_rate:.2f}"
            )

        blessed_cases = {c.get("id"): c for c in blessed_baseline.get("cases", [])}
        for cur_c in case_results:
            cid = cur_c.get("id")
            if cid in blessed_cases:
                blessed_c = blessed_cases[cid]
                b_passed = blessed_c.get("passed", False)
                c_passed = cur_c.get("passed", False)
                if b_passed and not c_passed:
                    regression = True
                    reasons.append(f"Case #{cid} passed in blessed baseline but failed in current run")

        return {
            "blessed_baseline_found": True,
            "blessed_pass_rate": blessed_pass_rate,
            "delta_from_baseline": round(delta, 4),
            "regression_detected": regression,
            "details": "; ".join(reasons) if reasons else "No regression detected against blessed baseline.",
        }

    def bless_baseline(self, skill_name: str, report: dict) -> Path:
        """Bless the given evaluation report as the authoritative baseline floor."""
        self.baselines_dir.mkdir(parents=True, exist_ok=True)
        blessed_file = self.baselines_dir / f"{skill_name}.json"

        blessed_data = dict(report)
        blessed_data["blessed_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

        blessed_file.write_text(json.dumps(blessed_data, indent=2), encoding="utf-8")
        return blessed_file
