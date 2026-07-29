import pytest
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent / "scripts" / "lib"))

from paths import validate_safe_path, FORBIDDEN_PATHS, PathValidationError


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
        ".boto", ".gcloud", ".azure"
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
        "secret.passwd", "secret.pwd", "secret.htpasswd", "app_history"
    ]
    for p in sensitive_extensions:
        with pytest.raises(PathValidationError):
            validate_safe_path(p, base, "test", check_forbidden=True)

    # Case-insensitivity for patterns
    case_patterns = [".ENV.LOCAL", "SECRET.PEM", "MY.KEY", "KEY.P12", "MY.JKS"]
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
    private_keys = ["id_rsa_personal", "id_ed25519_github", "id_dsa_old", "id_ecdsa_corp", "id_xmss_test"]
    for pk in private_keys:
        with pytest.raises(PathValidationError):
            validate_safe_path(pk, base, "test", check_forbidden=True)

    # Public keys should be allowed
    public_keys = ["id_rsa.pub", "id_ed25519_github.pub", "id_dsa_old.pub", "id_ecdsa_corp.pub", "id_xmss_test.pub"]
    for pub in public_keys:
        res = validate_safe_path(pub, base, "test", check_forbidden=True)
        expected = (base / pub).resolve()
        if res != expected:
            raise AssertionError(f"Expected {expected}, got {res}")
