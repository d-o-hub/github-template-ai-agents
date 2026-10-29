"""Contract for opt-in paired behavioral skill evaluation (`behavioral-eval/v1`).

`scripts/eval-skills.sh` and `scripts/run-evals.py` validate skill *definitions*:
they invoke no model and score no behavior. This module defines the separate
behavioral contract used by `scripts/behavioral-eval.py`:

* cases are derived from the same `evals/evals.json` the static checks read;
* each case runs in two configurations (`with_skill`, `without_skill`);
* an operator-supplied adapter returns one result document per task;
* results aggregate into a report that is compared with an explicitly blessed
  baseline (never written automatically).

Nothing in this module calls a model. Tokens, cost, and trigger accuracy are
only ever reported when an adapter supplied a measurement; otherwise they are
`unavailable`, never estimated.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path
from typing import Any, Iterable

SCHEMA_VERSION = "behavioral-eval/v1"
CASE_SOURCE = "evals/evals.json"
CONFIGURATIONS: tuple[str, ...] = ("with_skill", "without_skill")
PRIMARY_CONFIGURATION = "with_skill"
BASELINE_CONFIGURATION = "with_skill"
UNAVAILABLE = "unavailable"
NO_FIXTURES = "no-fixtures"
DIGEST_PREFIX = "sha256:"
BASELINE_FILENAME = "behavioral-baseline.json"
CANDIDATE_BASELINE_FILENAME = "candidate-baseline.json"
REPORT_FILENAME = "report.json"
CASE_VERDICTS: tuple[str, ...] = ("pass", "fail", "blocked", "not_run")
RESULT_STATUSES: tuple[str, ...] = ("graded", "blocked", "not_run")
ASSERTION_RESULTS: tuple[str, ...] = ("pass", "fail", "blocked")
BUCKETS: frozenset[str] = frozenset({"explicit", "implicit", "contextual", "negative"})
UNTAGGED = "untagged"
SEPARATOR_DOUBLE = "=" * 70
SEPARATOR_SINGLE = "-" * 40

# Artifact text is redacted before it is written to disk: paired outputs may
# contain credentials or personal data that must not land in CI artifacts.
_REDACTIONS: tuple[tuple[re.Pattern[str], str], ...] = (
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----", re.S),
     "[REDACTED_PRIVATE_KEY]"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"), "[REDACTED_GITHUB_TOKEN]"),
    (re.compile(r"\bsk-[A-Za-z0-9_-]{16,}\b"), "[REDACTED_API_KEY]"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "[REDACTED_AWS_KEY]"),
    (re.compile(r"(?i)\b(bearer|token|api[_-]?key|secret|password)\b\s*[:=]\s*[\"']?([^\s\"',]{8,})"),
     r"\1=[REDACTED]"),
    (re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"), "[REDACTED_EMAIL]"),
)


class ContractError(Exception):
    """Raised when cases, adapter results, or a baseline violate the contract."""


def sha256_text(text: str) -> str:
    """Return a prefixed SHA-256 digest for text."""
    return f"{DIGEST_PREFIX}{hashlib.sha256(text.encode('utf-8')).hexdigest()}"


def sha256_file(path: Path) -> str:
    """Return a prefixed SHA-256 digest for a file's bytes."""
    return f"{DIGEST_PREFIX}{hashlib.sha256(path.read_bytes()).hexdigest()}"


def redact(text: str) -> str:
    """Redact credential-shaped and personal-data-shaped substrings."""
    redacted = text
    for pattern, replacement in _REDACTIONS:
        redacted = pattern.sub(replacement, redacted)
    return redacted


def _iter_skill_files(skill_path: Path) -> list[Path]:
    """List content files that identify a skill revision (excludes artifacts)."""
    files: list[Path] = []
    for path in sorted(skill_path.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(skill_path)
        if relative.name == BASELINE_FILENAME:
            continue
        if any(part.startswith(".") or part.endswith("-workspace") for part in relative.parts):
            continue
        files.append(path)
    return files


def skill_digest(skill_path: Path) -> str:
    """Digest the skill revision so a report names exactly what was evaluated."""
    entries = [
        f"{path.relative_to(skill_path).as_posix()}:{sha256_file(path)}"
        for path in _iter_skill_files(skill_path)
    ]
    if not entries:
        raise ContractError(f"skill directory has no content to digest: {skill_path}")
    return sha256_text("\n".join(entries))


def fixture_digest(skill_path: Path, cases: Iterable[dict[str, Any]]) -> str:
    """Digest every input fixture referenced by the selected cases."""
    entries: list[str] = []
    for case in cases:
        for name in case.get("files", []):
            target = skill_path / name
            if not target.is_file():
                raise ContractError(
                    f"case {case['id']} references a missing fixture: {name}"
                )
            entries.append(f"{name}:{sha256_file(target)}")
    if not entries:
        return NO_FIXTURES
    return sha256_text("\n".join(entries))


def load_cases(skill_path: Path) -> list[dict[str, Any]]:
    """Load behavioral cases from the skill's static `evals/evals.json`."""
    evals_path = skill_path / CASE_SOURCE
    try:
        data = json.loads(evals_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise ContractError(f"missing case file: {evals_path}") from None
    except json.JSONDecodeError as exc:
        raise ContractError(f"invalid JSON in {evals_path}: {exc.msg}") from None
    except OSError as exc:
        raise ContractError(f"cannot read {evals_path}: {exc}") from None
    if not isinstance(data, dict) or not isinstance(data.get("evals"), list):
        raise ContractError(f"{evals_path} must be an object with an 'evals' array")
    cases: list[dict[str, Any]] = []
    for raw in data["evals"]:
        cases.append(_normalize_case(raw, evals_path))
    if not cases:
        raise ContractError(f"{evals_path} contains no cases")
    return cases


def _normalize_case(raw: Any, evals_path: Path) -> dict[str, Any]:
    """Validate and normalize one case; behavioral runs need these fields."""
    if not isinstance(raw, dict):
        raise ContractError(f"{evals_path}: every case must be an object")
    case_id = raw.get("id")
    if type(case_id) is not int:
        raise ContractError(f"{evals_path}: case id must be an integer, got {case_id!r}")
    prompt = raw.get("prompt")
    if not isinstance(prompt, str) or not prompt.strip():
        raise ContractError(f"{evals_path}: case {case_id} needs a non-empty prompt")
    assertions = raw.get("assertions")
    if not isinstance(assertions, list) or not assertions or not all(
        isinstance(item, str) and item.strip() for item in assertions
    ):
        raise ContractError(
            f"{evals_path}: case {case_id} needs a non-empty array of assertion strings"
        )
    bucket = raw.get("bucket", UNTAGGED)
    if bucket not in BUCKETS | {UNTAGGED}:
        raise ContractError(f"{evals_path}: case {case_id} has unknown bucket {bucket!r}")
    files = raw.get("files", [])
    if not isinstance(files, list) or not all(isinstance(item, str) for item in files):
        raise ContractError(f"{evals_path}: case {case_id} files must be a string array")
    expected = raw.get("expected_output", "")
    return {
        "id": case_id,
        "bucket": bucket,
        "prompt": prompt,
        "expected_output": expected if isinstance(expected, str) else "",
        "assertions": list(assertions),
        "files": list(files),
    }


def select_cases(cases: list[dict[str, Any]], case_ids: list[int] | None) -> list[dict[str, Any]]:
    """Select a subset of cases by id, failing loudly on unknown ids."""
    if not case_ids:
        return cases
    known = {case["id"] for case in cases}
    unknown = [case_id for case_id in case_ids if case_id not in known]
    if unknown:
        raise ContractError(f"unknown case id(s): {', '.join(str(i) for i in unknown)}")
    wanted = set(case_ids)
    return [case for case in cases if case["id"] in wanted]


def validate_result(
    doc: Any,
    skill_name: str,
    case_ids: set[int],
    configurations: tuple[str, ...] = CONFIGURATIONS,
) -> list[str]:
    """Validate one adapter result document; return contract issues (empty = ok)."""
    issues: list[str] = []
    if not isinstance(doc, dict):
        return ["result must be a JSON object"]
    if doc.get("schema_version") != SCHEMA_VERSION:
        issues.append(f"schema_version must be {SCHEMA_VERSION!r}")
    if doc.get("skill_name") != skill_name:
        issues.append(f"skill_name must be {skill_name!r}")
    if doc.get("case_id") not in case_ids:
        issues.append(f"case_id must be one of {sorted(case_ids)}")
    configuration = doc.get("configuration")
    if configuration not in configurations:
        issues.append(f"configuration must be one of {list(configurations)}")
    status = doc.get("status")
    if status not in RESULT_STATUSES:
        issues.append(f"status must be one of {list(RESULT_STATUSES)}")
        return issues
    if status != "graded":
        reason = doc.get("reason")
        if not isinstance(reason, str) or not reason.strip():
            issues.append(f"status {status!r} requires a non-empty reason")
        return issues
    issues.extend(_validate_assertion_results(doc.get("assertion_results")))
    issues.extend(_validate_activation(doc.get("activation")))
    duration = doc.get("duration_ms")
    if duration is not None and (not isinstance(duration, (int, float)) or duration < 0):
        issues.append("duration_ms must be a non-negative number when present")
    return issues


def _validate_assertion_results(raw: Any) -> list[str]:
    """Validate the graded assertion array."""
    if not isinstance(raw, list) or not raw:
        return ["graded results require a non-empty assertion_results array"]
    issues: list[str] = []
    for index, item in enumerate(raw, start=1):
        if not isinstance(item, dict):
            issues.append(f"assertion_results[{index}] must be an object")
            continue
        for field in ("text", "evidence"):
            value = item.get(field)
            if not isinstance(value, str) or not value.strip():
                issues.append(f"assertion_results[{index}].{field} must be a non-empty string")
        if item.get("result") not in ASSERTION_RESULTS:
            issues.append(
                f"assertion_results[{index}].result must be one of {list(ASSERTION_RESULTS)}"
            )
    return issues


def _validate_activation(raw: Any) -> list[str]:
    """Validate skill-activation evidence (required to detect false positives)."""
    if not isinstance(raw, dict):
        return ["graded results require an activation object"]
    if "skill_loaded" not in raw:
        return ["activation.skill_loaded is required (null when unobserved)"]
    if raw["skill_loaded"] not in (True, False, None):
        return ["activation.skill_loaded must be true, false, or null"]
    evidence = raw.get("evidence", "")
    if not isinstance(evidence, str):
        return ["activation.evidence must be a string when present"]
    return []


def validate_usage(usage: Any) -> list[str]:
    """Validate optional usage measurements; absent values stay unavailable."""
    if usage is None:
        return []
    if not isinstance(usage, dict):
        return ["usage must be an object when present"]
    issues: list[str] = []
    tokens = usage.get("total_tokens")
    if tokens is not None and (not isinstance(tokens, int) or isinstance(tokens, bool) or tokens < 0):
        issues.append("usage.total_tokens must be a non-negative integer or null")
    cost = usage.get("cost_usd")
    if cost is not None and (not isinstance(cost, (int, float)) or cost < 0):
        issues.append("usage.cost_usd must be a non-negative number or null")
    return issues
