import pytest
from pathlib import Path
import sys
import os

# Add scripts/lib to path so we can import paths
sys.path.append(os.path.abspath("scripts/lib"))
from paths import validate_safe_path, FORBIDDEN_OUTPUT_DIRS

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

    with pytest.raises(SystemExit):
        validate_safe_path("../outside", base, "test")

def test_validate_safe_path_absolute_outside(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()

    with pytest.raises(SystemExit):
        validate_safe_path(str(outside), base, "test")

def test_validate_safe_path_forbidden(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    for forbidden in FORBIDDEN_OUTPUT_DIRS:
        (base / forbidden).mkdir()
        with pytest.raises(SystemExit):
            validate_safe_path(forbidden, base, "test", check_forbidden=True)
        with pytest.raises(SystemExit):
            validate_safe_path(f"{forbidden}/file.txt", base, "test", check_forbidden=True)

def test_validate_safe_path_symlink_escape(tmp_path):
    base = tmp_path / "repo"
    base.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "secret.txt").write_text("secret")

    # Create a symlink inside base pointing outside
    (base / "link_to_outside").symlink_to(outside)

    with pytest.raises(SystemExit):
        validate_safe_path("link_to_outside/secret.txt", base, "test")
