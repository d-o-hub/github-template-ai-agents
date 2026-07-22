# tests/test_live_api_integrations.py
"""Live integration tests for providers that require real API keys.

Run explicitly:
    pytest -m live -s tests/test_live_api_integrations.py
"""

import logging
import os
import sys
import uuid

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from scripts.resolve import (  # noqa: E402
    _cache_key,
    _get_cache,
    _rate_limits,
    resolve_with_exa,
    resolve_with_exa_mcp,
    resolve_with_firecrawl,
    resolve_with_jina,
    resolve_with_mistral_browser,
    resolve_with_mistral_websearch,
    resolve_with_serper,
    resolve_with_tavily,
)

pytestmark = pytest.mark.live

# Stable public URL that works reliably in CI (no SSL issues)
_TEST_URL = "https://docs.python.org/3/"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _require_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        pytest.skip(f"{name} not set")
    return value


def _clear_cached_result(input_value: str, source: str, rate_limit_key: str | None = None) -> None:
    cache = _get_cache()
    if cache is not None:
        try:
            cache.delete(_cache_key(input_value, source))
        except Exception:
            pass
    _rate_limits.pop(rate_limit_key or source, None)


# ---------------------------------------------------------------------------
# Free providers (no API key required)
# ---------------------------------------------------------------------------
def test_live_exa_mcp_no_api_key():
    """Exa MCP is free - no key needed, should always return results."""
    query = f"Rust async runtime overview {uuid.uuid4().hex[:8]}"
    _clear_cached_result(query, "exa_mcp")
    result = resolve_with_exa_mcp(query)
    if result is None:
        pytest.skip("Exa MCP returned None - check network or MCP endpoint availability")
    assert result.source == "exa_mcp"
    assert isinstance(result.content, str)
    assert len(result.content.strip()) > 0


def test_live_jina_no_api_key():
    """Jina Reader is free (20 RPM) - no key needed."""
    _clear_cached_result(_TEST_URL, "jina")
    result = resolve_with_jina(_TEST_URL)
    if result is None:
        pytest.skip("Jina Reader returned None - check network or rate limit")
    assert result.source == "jina"
    assert result.url == _TEST_URL
    assert isinstance(result.content, str)
    assert len(result.content.strip()) > 0


# ---------------------------------------------------------------------------
# API-key providers
# ---------------------------------------------------------------------------
def test_live_exa_sdk_with_real_api_key():
    _require_env("EXA_API_KEY")
    pytest.importorskip("exa_py")
    query = f"Rust agent frameworks {uuid.uuid4().hex[:8]}"
    _clear_cached_result(query, "exa")
    result = resolve_with_exa(query)
    assert result is not None, "Exa SDK returned None - check EXA_API_KEY and quota"
    assert result.source == "exa"
    assert isinstance(result.content, str)
    assert len(result.content.strip()) > 0


def test_live_tavily_with_real_api_key(caplog):
    _require_env("TAVILY_API_KEY")
    pytest.importorskip("tavily")
    query = f"Rust agent frameworks {uuid.uuid4().hex[:8]}"
    _clear_cached_result(query, "tavily")
    with caplog.at_level(logging.DEBUG):
        result = resolve_with_tavily(query)
    if result is None:
        print(f"\nLOGS:\n{caplog.text}")
        pytest.skip("Tavily returned None - likely quota exhausted (432)")
    assert result.source == "tavily"
    assert isinstance(result.content, str)
    assert len(result.content.strip()) > 0


def test_live_firecrawl_with_real_api_key():
    _require_env("FIRECRAWL_API_KEY")
    pytest.importorskip("firecrawl")
    _clear_cached_result(_TEST_URL, "firecrawl")
    result = resolve_with_firecrawl(_TEST_URL)
    if result is None:
        pytest.skip("Firecrawl returned None - likely quota exhausted")
    assert result.source == "firecrawl"
    assert result.url is not None
    assert isinstance(result.content, str)


def test_live_mistral_browser_with_real_api_key():
    _require_env("MISTRAL_API_KEY")
    mistralai = pytest.importorskip("mistralai")
    _ = mistralai  # noqa: F841
    _clear_cached_result(_TEST_URL, "mistral_browser", rate_limit_key="mistral")
    result = resolve_with_mistral_browser(_TEST_URL)
    if result is None:
        pytest.skip("Mistral browser returned None - API may have changed or quota exceeded")
    assert result.source == "mistral-browser"
    assert result.url is not None
    assert isinstance(result.content, str)
    assert len(result.content.strip()) > 0


def test_live_mistral_websearch_with_real_api_key():
    _require_env("MISTRAL_API_KEY")
    mistralai = pytest.importorskip("mistralai")
    _ = mistralai  # noqa: F841
    query = f"Rust async runtime overview {uuid.uuid4().hex[:8]}"
    _clear_cached_result(query, "mistral_websearch", rate_limit_key="mistral")
    result = resolve_with_mistral_websearch(query)
    if result is None:
        pytest.skip("Mistral websearch returned None - check MISTRAL_API_KEY and quota")
    assert result.source == "mistral-websearch"
    assert isinstance(result.content, str)
    assert len(result.content.strip()) > 0


def test_live_serper_with_real_api_key():
    _require_env("SERPER_API_KEY")
    query = f"Rust agent frameworks {uuid.uuid4().hex[:8]}"
    _clear_cached_result(query, "serper", rate_limit_key="serper")
    result = resolve_with_serper(query)
    if result is None:
        pytest.skip("Serper returned None - check SERPER_API_KEY and quota")
    assert result.source == "serper"
    assert isinstance(result.content, str)
    assert len(result.content.strip()) > 0
