"""Regression guard for the vendored Firecrawl v2 integration."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_diagnostic_uses_v2_endpoint() -> None:
    source = (ROOT / "scripts/diagnose_providers.py").read_text(encoding="utf-8")
    assert "https://api.firecrawl.dev/v2/scrape" in source
    assert "https://api.firecrawl.dev/v1/scrape" not in source


def test_sdk_dependency_requires_v2_compatible_release() -> None:
    manifests = (ROOT / "pyproject.toml", ROOT / "requirements.txt")
    for manifest in manifests:
        content = manifest.read_text(encoding="utf-8")
        assert "firecrawl-py>=4.57.0" in content
