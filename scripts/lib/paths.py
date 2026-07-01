# scripts/lib/paths.py
"""Path validation utilities for CLI scripts."""

from __future__ import annotations
from pathlib import Path

FORBIDDEN_PATHS = frozenset({
    ".git",
    "scripts",
    ".agents",
    ".github",
    "bin",
    "hooks",
    ".githooks",
    "plans",
    "agents-docs",
    ".claude",
    ".qwen",
    ".gemini",
    ".windsurf",
    ".cursor",
    ".opencode",
    ".commandcode",
    ".env",
    ".envrc",
    "Makefile",
    ".gitignore",
    "package.json",
    "package-lock.json",
    "pnpm-lock.yaml",
    "bun.lockb",
    "composer.json",
    "composer.lock",
    "requirements.txt",
    "pyproject.toml",
    "Gemfile",
    "Gemfile.lock",
    ".npmrc",
    ".yarnrc",
    ".yarnrc.yml",
    ".netrc",
    ".pypirc",
    "auth.json",
    ".ssh",
    ".aws",
    ".kube",
    ".docker",
    ".gnupg",
    ".gitconfig",
    ".bashrc",
    ".zshrc",
    ".profile",
    ".bash_profile",
    "LICENSE",
    "VERSION",
})


class PathValidationError(Exception):
    """Raised when a path fails safe-path validation."""


def validate_safe_path(
    raw: str,
    base: Path,
    param_name: str,
    check_forbidden: bool = False,
) -> Path:
    """
    Resolve `raw` relative to `base` and assert it stays within `base`.
    Raises PathValidationError on violation.
    """
    base_resolved = base.resolve()
    candidate = Path(raw)
    if not candidate.is_absolute():
        candidate = base_resolved / candidate
    candidate = candidate.resolve()

    try:
        candidate.relative_to(base_resolved)
    except ValueError:
        raise PathValidationError(
            f"--{param_name} resolves outside allowed directory "
            f"({base_resolved}): {candidate}"
        ) from None

    if check_forbidden and candidate != base_resolved:
        top_level = candidate.relative_to(base_resolved).parts[0]
        if top_level in FORBIDDEN_PATHS:
            raise PathValidationError(
                f"--{param_name} targets a forbidden path: {top_level}"
            )

    return candidate
