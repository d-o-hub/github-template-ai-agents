# scripts/lib/paths.py
# Security Hardening: 2026-07-06 - Expanded forbidden paths.
# Security Hardening: 2026-07-07 - Case-insensitive forbidden path validation.
# Security Hardening: 2026-08-18 - Added VPN, keychain, and DB history file pattern protections.
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
    ".rediscli_history",
    ".dbshell",
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
    ".pgpass",
    ".my.cnf",
    ".irb_history",
    ".pry_history",
    ".pg_service.conf",
    ".tcshrc",
    ".cshrc",
    ".login",
    ".logout",
    ".dbshell",
    ".rediscli_history",
    ".kshrc",
    "pip.conf",
    ".gemrc",
    ".condarc",
    "nuget.config",
    ".sops.yaml",
    ".sops",
    ".zsh_sessions",
    # Low-severity filename-policy gap within the allowed base:
    # validate_safe_path already confines via resolve()+relative_to,
    # so this denylist only blocks these in-base names.
    ".curlrc",
    ".wgetrc",
    ".m2",
    ".netrc.bak",
    ".gradle",
})

# Pre-calculate lowercase forbidden paths for efficient case-insensitive matching.
FORBIDDEN_PATHS_LOWER = frozenset({p.lower() for p in FORBIDDEN_PATHS})

# Module-level constants for pattern-based sensitive file validation to avoid string duplication.
# Scope note (low-severity filename-policy gap): validate_safe_path() resolves and
# confines the candidate inside the allowed base (resolve() + relative_to()) before
# this denylist runs, and current callers only probe existence or write reports
# inside that base. These patterns block repo-local overwrites and existence
# probes of sensitive filenames, not arbitrary credential reads.
# Fail-closed startswith() policy: prefix matching intentionally over-blocks
# (e.g. `tokenizer`, `token_secret_backup`); false positives are accepted for
# denylist safety. Conversely, camelCase/infix forms (e.g. `myAccessToken`,
# `mytokenfile`) are NOT covered unless matched by another prefix/suffix.
SENSITIVE_PREFIXES = (
    ".env",
    "client_secret",
    "service_account",
    "service-account",
    "kubeconfig",
    "secret",
    "credential",
    "netrc",
    ".netrc",
    ".npmrc",
    ".yarnrc",
    ".pypirc",
    "auth.json",
    "token",
    "access_token",
    "access-token",
    "refresh_token",
    "refresh-token",
    "auth_token",
    "auth-token",
    "session_token",
    "session-token",
    "bearer_token",
    "bearer-token",
    "app_secret",
    "app-secret",
    "api_secret",
    "api-secret",
    "app_key",
    "app-key",
    "api_key",
    "api-key",
    "id-token",
    "oauth_token",
    "oauth-token",
    "jwt_token",
    "jwt-token",
    "private_key",
    "private-key",
    "privkey",
    # NOTE: `secret_key`/`secret-key` intentionally omitted: already covered by
    # the `secret` prefix above (see #879 precedent); listing them would be dead config.
)

SENSITIVE_SUFFIXES = (
    ".pem", ".key", ".pfx", ".tfstate", ".crt", ".cer",
    ".p12", ".pkcs8", ".pk8", ".der", ".keystore", ".jks",
    ".dockercfg", ".publishsettings", ".gpg", ".pgp", ".asc",
    ".p8", ".pkcs12", ".passwd", ".pwd", ".htpasswd", "_history",
    "credentials.json", "client_secret.json", "kubeconfig",
    # Low-severity filename-policy gap within the allowed base:
    # validate_safe_path already confines via resolve()+relative_to,
    # so these suffixes only block matching in-base names (not arbitrary reads).
    "kubeconfig.yaml", "kubeconfig.yml",
    ".secrets", ".credentials", ".vault", "secrets.json",
    "secrets.yml", "secrets.yaml", "credentials.yml", "credentials.yaml",
    ".ovpn", ".kdbx", ".keychain", ".keychain-db", ".keyring", ".kdb",
    ".env", ".tfvars", ".tfvars.json",
)

SSH_KEY_PREFIXES = (
    "identity",
    "id_",
    "id_rsa",
    "id_dsa",
    "id_ecdsa",
    "id_ed25519",
    "id_xmss",
)


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
                part_lower.startswith(SENSITIVE_PREFIXES) or
                part_lower.endswith(SENSITIVE_SUFFIXES) or
                (
                    part_lower.startswith(SSH_KEY_PREFIXES) and
                    not part_lower.endswith(".pub")
                )
            ):
                raise PathValidationError(
                    f"--{param_name} targets a sensitive file pattern: {part}"
                )

    return candidate


def validate_canonical_name(
    raw: str,
    base: Path,
    param_name: str,
) -> Path:
    """
    Resolve a single-segment child *name* under `base`, exempt from substring matching.

    `SENSITIVE_PREFIXES` exists to keep credential-bearing files from being read
    or overwritten, and it deliberately over-blocks (`tokenizer`,
    `token_secret_backup`): for a file path, a false positive costs nothing.
    Applied to a curated skills tree it hides real skills -- `.agents/skills/secrets-management`
    trips the `secret` prefix, so `run-evals.py --skill secrets-management`
    reported "not found" and the generated README published 53 of 54 skills.

    So the exemption is narrow by design. What still blocks:

    * exact credential names (`.git`, `.env`, `Makefile`, `requirements.txt`)
    * hidden names (leading `.`)
    * key and certificate formats (`.pem`, `.key`, `.id_rsa`, …)

    What no longer blocks is a name that merely *contains* a sensitive word.

    Traversal and confinement are unaffected: the name must be a single segment
    and `validate_safe_path` still requires containment under `base`.
    """
    if not raw or Path(raw).name != raw:
        raise PathValidationError(
            f"--{param_name} must be a single path segment, not a path: {raw}"
        )

    name_lower = raw.lower()
    if name_lower.startswith("."):
        raise PathValidationError(
            f"--{param_name} must not be a hidden name: {raw}"
        )
    if name_lower in FORBIDDEN_PATHS_LOWER:
        raise PathValidationError(
            f"--{param_name} targets a forbidden path: {raw}"
        )
    if name_lower.endswith(SENSITIVE_SUFFIXES) or (
        name_lower.startswith(SSH_KEY_PREFIXES) and not name_lower.endswith(".pub")
    ):
        raise PathValidationError(
            f"--{param_name} targets a sensitive file pattern: {raw}"
        )

    return validate_safe_path(raw, base, param_name, check_forbidden=False)
