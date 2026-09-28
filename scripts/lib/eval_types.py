"""Shared types and data classes for the evaluation runner."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path


class EvalType(Enum):
    """Types of evaluations that can be performed."""
    STRUCTURE = "structure"
    COMMAND = "command"
    FILE_VALIDATION = "file_validation"


class EvalStatus(Enum):
    """Status of an individual eval scenario."""
    PASS = "PASS"
    FAIL = "FAIL"
    SKIP = "SKIP"
    ERROR = "ERROR"


class EvalBucket(Enum):
    """Optional eval taxonomy (NVIDIA SkillEvaluator 4-bucket datasets).

    explicit   - the request directly names the skill's job.
    implicit   - the request needs the skill without naming the job.
    contextual - the request is adjacent; tests non-triggering boundaries.
    negative   - out-of-scope; the skill must stay unloaded.
    """

    EXPLICIT = "explicit"
    IMPLICIT = "implicit"
    CONTEXTUAL = "contextual"
    NEGATIVE = "negative"


EVAL_BUCKETS = frozenset(b.value for b in EvalBucket)


@dataclass
class EvalResult:
    """Result of a single eval scenario."""
    eval_id: int
    status: EvalStatus
    message: str = ""
    details: list[str] = field(default_factory=list)
    duration_ms: float = 0.0
    total_tokens: int = 0


@dataclass
class SkillEvalResult:
    """Result of evaluating a single skill."""
    skill_name: str
    skill_path: Path
    status: EvalStatus
    evals_run: int = 0
    evals_passed: int = 0
    evals_failed: int = 0
    evals_skipped: int = 0
    eval_results: list[EvalResult] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


@dataclass
class EvalReport:
    """Overall evaluation report."""
    total_skills: int = 0
    skills_passed: int = 0
    skills_failed: int = 0
    total_evals: int = 0
    evals_passed: int = 0
    evals_failed: int = 0
    evals_skipped: int = 0
    skill_results: list[SkillEvalResult] = field(default_factory=list)
