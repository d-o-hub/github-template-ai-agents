# scripts/lib/paths.py
# Security Hardening: 2026-07-06 - Expanded forbidden paths.
# Security Hardening: 2026-07-07 - Case-insensitive forbidden path validation.
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
    ".secrets",
    ".git-credentials",
    ".bash_history",
    ".zsh_history",
    ".python_history",
    ".node_repl_history",
    ".sh_history",
    ".lesshst",
    ".viminfo",
    ".mysql_history",
    ".psql_history",
    ".sqlite_history",
    "terraform.tfstate.backup",
    ".terraform",  # Directory: blocks .terraform/ and its contents
    "id_rsa",
    "id_ed25519",
    "id_ecdsa",
    "id_dsa",
    "known_hosts",
    "authorized_keys",
    ".env.local",
    ".env.development",
    ".env.test",
    ".env.production",
    ".bash_logout",
    ".inputrc",
    ".wget-hsts",
    "rclone.conf",
    ".hg",
    ".hgignore",
    ".hgrc",
    ".svn",
    ".fish_history",
    ".ash_history",
    ".tcsh_history",
    ".cargo",
    ".s3cfg",
    ".boto",
    ".gcloud",
    ".azure",
    "_netrc",
    ".oci",
    ".sentryclirc",
    ".vault-token",
    ".password-store",
    ".erlang.cookie",
    ".vscode",
    ".idea",
    ".env.vault",
    ".zshenv",
    ".zprofile",
    ".zlogin",
    ".zlogout",
    ".bash_login",
})

# Pre-calculate lowercase forbidden paths for efficient case-insensitive matching.
FORBIDDEN_PATHS_LOWER = frozenset({p.lower() for p in FORBIDDEN_PATHS})


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
        for part in candidate.relative_to(base_resolved).parts:
            part_lower = part.lower()
            # Strict matches
            if part_lower in FORBIDDEN_PATHS_LOWER:
                raise PathValidationError(
                    f"--{param_name} targets a forbidden path: {part}"
                )

            # Pattern-based matches
            # .env* covers various environment file naming conventions.
            # Extensions cover common certificate, private key, and state formats.
            # Note: .key is intentionally broad to catch private keys despite potential false positives.
            # SSH private key prefixes cover custom-named keys and newer types (e.g. id_ed25519_sk, id_rsa_backup).
            if (
                part_lower.startswith((".env", "client_secret", "kubeconfig", "secret", "credential")) or
                part_lower.endswith((
                    ".pem", ".key", ".pfx", ".tfstate", ".crt", ".cer",
                    ".p12", ".pkcs8", ".pk8", ".der", ".keystore", ".jks",
                    ".dockercfg", ".publishsettings", ".gpg", ".pgp", ".asc",
                    ".p8", ".pkcs12", ".passwd", ".pwd", ".htpasswd", "_history",
                    "credentials.json", "client_secret.json", "kubeconfig",
                    ".secrets", ".credentials", ".vault", "secrets.json",
                    "secrets.yml", "secrets.yaml", "credentials.yml", "credentials.yaml"
                )) or
                (
                    part_lower.startswith(("identity", "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519", "id_xmss")) and
                    not part_lower.endswith(".pub")
                )
            ):
                raise PathValidationError(
                    f"--{param_name} targets a sensitive file pattern: {part}"
                )

    return candidate
