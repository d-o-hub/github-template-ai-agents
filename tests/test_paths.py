import sys
from pathlib import Path

import pytest

from paths import (
    validate_safe_path,
    validate_canonical_name,
    FORBIDDEN_PATHS,
    PathValidationError,
)


def test_validate_safe_path_normal(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    (base / "subdir").mkdir()

    # Relative path
    res = validate_safe_path("subdir", base, "test")
    assert res == (base / "subdir").resolve()

    # Dot path
    res = validate_safe_path(".", base, "test")
    assert res == base.resolve()


def test_validate_safe_path_traversal(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()

    with pytest.raises(PathValidationError):
        validate_safe_path("../outside", base, "test")


def test_validate_safe_path_absolute_outside(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()

    with pytest.raises(PathValidationError):
        validate_safe_path(str(outside), base, "test")


def test_validate_safe_path_forbidden(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    for forbidden in FORBIDDEN_PATHS:
        # Create parent directories if forbidden is nested (none are now, but good practice)
        forbidden_path = base / forbidden
        forbidden_path.parent.mkdir(parents=True, exist_ok=True)
        # Note: If it's meant to be a file, mkdir will still work for our test
        # as the validation check only looks at the top-level part.
        forbidden_path.mkdir(exist_ok=True)

        with pytest.raises(PathValidationError):
            validate_safe_path(forbidden, base, "test", check_forbidden=True)
        with pytest.raises(PathValidationError):
            validate_safe_path(f"{forbidden}/file.txt", base, "test", check_forbidden=True)

    # Test nested forbidden path
    (base / "subdir").mkdir()
    with pytest.raises(PathValidationError):
        validate_safe_path("subdir/.env", base, "test", check_forbidden=True)

    # Test newly added forbidden paths
    with pytest.raises(PathValidationError):
        validate_safe_path(".git-credentials", base, "test", check_forbidden=True)
    with pytest.raises(PathValidationError):
        validate_safe_path(".bash_history", base, "test", check_forbidden=True)
    with pytest.raises(PathValidationError):
        validate_safe_path("id_rsa", base, "test", check_forbidden=True)

    # Test newly added shell/app history and terraform paths
    # Note: terraform.tfstate is covered by pattern matching, others by explicit denylist
    new_forbidden = [
        ".sh_history", ".lesshst", ".viminfo", ".mysql_history",
        ".psql_history", ".sqlite_history", "terraform.tfstate",
        "terraform.tfstate.backup", ".terraform", ".cargo", ".s3cfg",
        ".boto", ".gcloud", ".azure", "_netrc", ".oci", ".sentryclirc",
        ".vault-token", ".password-store", ".erlang.cookie",
        ".vscode", ".idea", ".env.vault", ".zshenv", ".zprofile",
        ".zlogin", ".zlogout", ".bash_login", ".pgpass", ".my.cnf",
        ".irb_history", ".pry_history", ".pg_service.conf",
        ".tcshrc", ".cshrc", ".login", ".logout", ".rediscli_history",
        ".dbshell", ".kshrc", "pip.conf", ".gemrc", ".condarc",
        "nuget.config", ".sops.yaml", ".sops", ".zsh_sessions",
        ".m2", ".netrc.bak"
    ]
    for p in new_forbidden:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)


def test_validate_safe_path_patterns(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()

    # .env* patterns
    with pytest.raises(PathValidationError):
        validate_safe_path(".env.custom", base, "test", check_forbidden=True)
    with pytest.raises(PathValidationError):
        validate_safe_path(".env.local.backup", base, "test", check_forbidden=True)

    # Sensitive extension patterns
    sensitive_extensions = [
        "secret.pem", "my.key", "cert.pfx", "prod.tfstate",
        "cert.crt", "bundle.cer", "key.p12", "key.pkcs8", "key.pk8",
        "key.der", "my.keystore", "my.jks", "config.dockercfg", "prod.publishsettings",
        "secret.gpg", "secret.pgp", "secret.asc", "key.p8", "key.pkcs12",
        "secret.passwd", "secret.pwd", "secret.htpasswd", "app_history",
        "client_secret.json", "credentials.json", "kubeconfig", "my_kubeconfig",
        "client_secret_xyz.json", "secrets.json", "secrets.yml", "secrets.yaml",
        "credentials.yml", "credentials.yaml", "production.secrets", "api.credentials",
        "my.vault", "client.ovpn", "passwords.kdbx", "login.keychain",
        "login.keychain-db", "system.keyring", "db.kdb"
    ]
    for p in sensitive_extensions:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)

    # Prefix matches
    prefix_patterns = [
        "client_secret", "client_secret_local", "service_account.json", "service-account-key.json",
        "kubeconfig", "kubeconfig_prod",
        "secret_keys.json", "secrets_config", "credential_helper", "credentials_file",
        "netrc_backup", ".netrc_old", ".npmrc_custom", ".yarnrc_custom", ".pypirc_prod",
        "auth.json_copy", "token_secret.json", "token.txt", "access_token.json", "access-token.txt",
        "refresh_token.json", "refresh-token.txt", "auth_token.json", "auth-token.txt",
        "session_token.json", "session-token.txt", "bearer_token.txt", "bearer-token.txt",
        "app_secret.json", "app-secret.json", "api_key_prod", "api_key.json",
        "api-key.txt", "id-token.txt", "oauth_token.json", "oauth-token.txt",
        "jwt_token.json", "jwt-token.txt",
        "private_key.txt", "private-key.txt", "privkey", "secret_key.json", "secret-key.txt"
    ]
    for p in prefix_patterns:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)

    # Additional sensitive extension suffix patterns
    additional_suffixes = [
        "vpn_config.ovpn", "passwords.kdbx", "login.keychain", "user.keychain-db",
        "config.env", "prod.env", "secrets.env", "terraform.tfvars",
        "terraform.tfvars.json", "override.tfvars", "secrets.tfvars.json",
        "cluster.kubeconfig.yaml", "cluster.kubeconfig.yml"
    ]
    for p in additional_suffixes:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)

    # Case-insensitivity for patterns
    case_patterns = [
        ".ENV.LOCAL", "SECRET.PEM", "MY.KEY", "KEY.P12", "MY.JKS",
        "CLIENT_SECRET_PROD", "KUBECONFIG", "VPN.OVPN", "STORE.KDBX"
    ]
    for p in case_patterns:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)

    # Nested pattern matches
    (base / "subdir").mkdir()
    with pytest.raises(PathValidationError):
        validate_safe_path("subdir/id_rsa.pem", base, "test", check_forbidden=True)

    # SSH private key pattern-based matches (custom/backup suffixes)
    ssh_private_patterns = [
        "id_rsa_backup", "id_ed25519_sk", "id_ecdsa_old", "id_xmss.backup",
        "identity", "identity_backup", "identity_ecdsa"
    ]
    for p in ssh_private_patterns:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)

    # Public keys should be allowed
    ssh_public_patterns = [
        "id_rsa.pub", "id_ed25519_sk.pub", "id_ecdsa_old.pub"
    ]
    for p in ssh_public_patterns:
        res = validate_safe_path(p, base, "test", check_forbidden=True)
        assert res == (base / p).resolve()

    # Explicit checks for newly added VCS folders and alternative shell histories
    vcs_and_histories = [
        ".hg", ".hgignore", ".hgrc", ".svn",
        ".fish_history", ".ash_history", ".tcsh_history"
    ]
    for p in vcs_and_histories:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)


def test_validate_safe_path_case_insensitivity(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()

    # On case-sensitive filesystems, this is just a different folder.
    # On case-insensitive ones, this IS the .git folder.
    # Security-wise, we should block it regardless for cross-platform safety.
    with pytest.raises(PathValidationError):
        validate_safe_path(".GIT", base, "test", check_forbidden=True)

    with pytest.raises(PathValidationError):
        validate_safe_path(".Env", base, "test", check_forbidden=True)


def test_validate_safe_path_symlink_escape(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "secret.txt").write_text("secret")

    # Create a symlink inside base pointing outside
    (base / "link_to_outside").symlink_to(outside)

    with pytest.raises(PathValidationError):
        validate_safe_path("link_to_outside/secret.txt", base, "test")


def test_validate_safe_path_ssh_keys(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()

    # Dynamic private keys (e.g. custom names)
    private_keys = ["id_rsa_personal", "id_ed25519_github", "id_dsa_old", "id_ecdsa_corp", "id_xmss_test", "id_custom_key"]
    for pk in private_keys:
        with pytest.raises(PathValidationError):
            validate_safe_path(pk, base, "test", check_forbidden=True)

    # Public keys should be allowed
    public_keys = ["id_rsa.pub", "id_ed25519_github.pub", "id_dsa_old.pub", "id_ecdsa_corp.pub", "id_xmss_test.pub", "id_custom_key.pub"]
    for pub in public_keys:
        res = validate_safe_path(pub, base, "test", check_forbidden=True)
        expected = (base / pub).resolve()
        if res != expected:
            raise AssertionError(f"Expected {expected}, got {res}")


def test_validate_canonical_name_allows_sensitive_substring(tmp_path):
    """A skill dir name is content, not a credential path.

    Regression: `secrets-management` tripped the `secret` prefix, so
    run-evals.py reported "not found" and the generated README published
    53 of 54 skills.
    """
    base = tmp_path / "skills"
    base.mkdir()
    (base / "secrets-management").mkdir()

    res = validate_canonical_name("secrets-management", base, "skill")
    assert res == (base / "secrets-management").resolve()


def test_validate_canonical_name_requires_single_segment(tmp_path):
    base = tmp_path / "skills"
    base.mkdir()
    (base / "nested").mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()

    for bad in ("", ".", "..", "nested/child", "./secrets-management", str(base / "secrets-management")):
        with pytest.raises(PathValidationError):
            validate_canonical_name(bad, base, "skill")

    # Hidden names and credential-shaped names stay refused.
    for hidden_or_credential in (".git", ".env", "id_rsa", "private.pem", "credentials.json"):
        with pytest.raises(PathValidationError):
            validate_canonical_name(hidden_or_credential, base, "skill")

    # Traversal out of the base is still refused.
    with pytest.raises(PathValidationError):
        validate_canonical_name("../outside", base, "skill")


def test_validate_canonical_name_does_not_relax_validate_safe_path(tmp_path):
    """The exemption is scoped to the name helper; the denylist still bites."""
    base = tmp_path / "skills"
    base.mkdir()

    for denied in (".env", "id_rsa", "credentials.json"):
        with pytest.raises(PathValidationError):
            validate_safe_path(denied, base, "files", check_forbidden=True)


def test_every_skill_directory_is_discoverable():
    """No skill may be invisible to the generators that publish the catalog.

    Guards the whole class, not just the name that broke: any future skill
    whose directory name trips the denylist would silently vanish from
    run-evals.py and .agents/skills/README.md.
    """
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
    from lib.paths import validate_canonical_name

    skills_dir = Path(__file__).resolve().parents[1] / ".agents" / "skills"
    assert skills_dir.is_dir()

    hidden = []
    for entry in sorted(skills_dir.iterdir()):
        if not entry.is_dir() or entry.name.startswith("_"):
            continue
        try:
            validate_canonical_name(entry.name, skills_dir, "skill")
        except PathValidationError:
            hidden.append(entry.name)

    assert hidden == [], f"skills hidden from discovery by path validation: {hidden}"
