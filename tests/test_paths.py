import pytest
from pathlib import Path

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
