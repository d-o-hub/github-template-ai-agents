# scripts/lib/paths.py
"""Path validation utilities for CLI scripts."""

from __future__ import annotations
import sys
from pathlib import Path

FORBIDDEN_OUTPUT_DIRS = frozenset({".git", "scripts", ".agents", ".github"})


def validate_safe_path(
    raw: str,
    base: Path,
    param_name: str,
    check_forbidden: bool = False,
) -> Path:
    """
    Resolve `raw` relative to `base` and assert it stays within `base`.
    Raises SystemExit(1) on violation.
    """
    base_resolved = base.resolve()
    candidate = Path(raw)
    if not candidate.is_absolute():
        candidate = base_resolved / candidate
    candidate = candidate.resolve()

    try:
        candidate.relative_to(base_resolved)
    except ValueError:
        print(
            f"Error: --{param_name} resolves outside allowed directory "
            f"({base_resolved}): {candidate}",
            file=sys.stderr,
        )
        sys.exit(1)

    if check_forbidden and candidate != base_resolved:
        top_level = candidate.relative_to(base_resolved).parts[0]
        if top_level in FORBIDDEN_OUTPUT_DIRS:
            print(
                f"Error: --{param_name} targets a forbidden directory: {top_level}/",
                file=sys.stderr,
            )
            sys.exit(1)

    return candidate
