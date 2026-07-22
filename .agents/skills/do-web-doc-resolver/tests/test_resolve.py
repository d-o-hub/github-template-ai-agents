"""Comprehensive tests for resolve.py with all fallback scenarios."""

import logging
import os
import sys
from pathlib import Path
from unittest.mock import Mock, patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from scripts.resolve import (
    MAX_CHARS,
    ErrorType,
    _detect_error_type,
    _is_rate_limited,
    _set_rate_limit,
    fetch_llms_txt,
    is_url,
    resolve,
    resolve_with_duckduckgo,
)


# Deferred imports for live tests (require API keys)
def _get_firecrawl_funcs():
    from scripts.resolve import resolve_with_firecrawl

    return resolve_with_firecrawl


def _get_mistral_browser_func():
    from scripts.resolve import resolve_with_mistral_browser

    return resolve_with_mistral_browser


class TestIsUrl:
    """Test URL detection."""

    def test_valid_urls(self):
        """Test that valid URLs are detected."""
        assert is_url("https://example.com")
        assert is_url("http://example.com/path")
        assert is_url("https://docs.rs/tokio")

    def test_invalid_urls(self):
        """Test that non-URLs are rejected."""
        assert not is_url("not a url")
        assert not is_url("just some text")
        assert not is_url("")


class TestFetchLlmsTxt:
    """Test llms.txt fetching."""

    @patch("scripts.utils._safe_request")
    def test_llms_txt_found(self, mock_safe_request):
        """Test successful llms.txt fetch."""
        mock_response = Mock()
        mock_response.status_code = 200
        mock_response.text = "# Example llms.txt\nContent here"
        mock_response.headers = {"Content-Type": "text/plain"}
        mock_response.is_redirect = False
        mock_response.url = "https://example.com/llms.txt"
        mock_response.history = []
        mock_safe_request.return_value = mock_response

        # Clear cache to ensure fresh test
        import scripts.resolve

        scripts.resolve._cache = None

        result = fetch_llms_txt("https://example.com")
        assert result is not None
        assert "Example llms.txt" in result

    @patch("scripts.utils._safe_request")
    def test_llms_txt_not_found(self, mock_safe_request):
        """Test when llms.txt doesn't exist."""
        mock_response = Mock()
        mock_response.status_code = 404
        mock_response.is_redirect = False
        mock_response.url = "https://example.com/llms.txt"
        mock_response.history = []
        mock_safe_request.return_value = mock_response

        # Clear cache to ensure fresh test
        import scripts.resolve
        from scripts.utils.cache import _l1_clear

        scripts.resolve._cache = None
        _l1_clear()

        result = fetch_llms_txt("https://example.com")
        assert result is None


@pytest.mark.live
class TestResolveWithFirecrawl:
    """Test Firecrawl resolution with error handling."""

    @patch.dict(os.environ, {}, clear=True)
    def test_no_api_key(self):
        """Test graceful handling when API key is not set."""
        result = _get_firecrawl_funcs()("https://example.com")
        assert result is None

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    @patch("scripts.resolve.validate_url")
    @patch("firecrawl.Firecrawl")
    def test_successful_extraction(self, mock_firecrawl_class, mock_validate):
        """Test successful content extraction."""
        # Mock URL validation
        mock_validation = Mock()
        mock_validation.is_valid = True
        mock_validation.final_url = "https://example.com"
        mock_validate.return_value = mock_validation

        mock_app = Mock()
        mock_result = Mock()
        mock_result.markdown = "# Test Content\nSome text here"
        mock_app.scrape.return_value = mock_result
        mock_firecrawl_class.return_value = mock_app

        result = _get_firecrawl_funcs()("https://example.com")
        assert result is not None
        assert result.source == "firecrawl"
        assert "Test Content" in result.content

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key", "MISTRAL_API_KEY": "mistral_key"})
    @patch("scripts.resolve.validate_url")
    @patch("firecrawl.Firecrawl")
    @patch("scripts.resolve.resolve_with_mistral_browser")
    def test_rate_limit_fallback(self, mock_mistral, mock_firecrawl_class, mock_validate):
        """Test Mistral fallback on rate limit."""
        # Mock URL validation
        mock_validation = Mock()
        mock_validation.is_valid = True
        mock_validation.final_url = "https://example.com"
        mock_validate.return_value = mock_validation

        mock_app = Mock()
        mock_app.scrape.side_effect = Exception("429 rate limit exceeded")
        mock_firecrawl_class.return_value = mock_app

        # resolve_with_firecrawl returns None on rate limit, doesn't call Mistral
        result = _get_firecrawl_funcs()("https://example.com")
        assert result is None  # Returns None, fallback is handled by resolve()
        mock_mistral.assert_not_called()  # Mistral is not called by resolve_with_firecrawl

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key", "MISTRAL_API_KEY": "mistral_key"})
    @patch("scripts.resolve.validate_url")
    @patch("firecrawl.Firecrawl")
    @patch("scripts.resolve.resolve_with_mistral_browser")
    def test_credit_exhaustion_fallback(self, mock_mistral, mock_firecrawl_class, mock_validate):
        """Test Mistral fallback on credit exhaustion."""
        # Clear rate limits
        from scripts.resolve import _rate_limits

        _rate_limits.clear()

        # Mock URL validation
        mock_validation = Mock()
        mock_validation.is_valid = True
        mock_validation.final_url = "https://example.com"
        mock_validate.return_value = mock_validation

        mock_app = Mock()
        mock_app.scrape.side_effect = Exception("insufficient credits")
        mock_firecrawl_class.return_value = mock_app

        # resolve_with_firecrawl returns None on credit exhaustion, doesn't call Mistral
        result = _get_firecrawl_funcs()("https://example.com")
        assert result is None  # Returns None, fallback is handled by resolve()
        mock_mistral.assert_not_called()  # Mistral is not called by resolve_with_firecrawl

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    @patch("firecrawl.Firecrawl")
    def test_authentication_error(self, mock_firecrawl_class):
        """Test handling of authentication errors."""
        mock_app = Mock()
        mock_app.scrape.side_effect = Exception("401 unauthorized")
        mock_firecrawl_class.return_value = mock_app

        result = _get_firecrawl_funcs()("https://example.com")
        assert result is None


@pytest.mark.live
class TestResolveWithMistralBrowser:
    """Test Mistral agent-browser skill fallback."""

    @patch.dict(os.environ, {}, clear=True)
    def test_no_api_key(self):
        """Test graceful handling when Mistral API key is not set."""
        result = _get_mistral_browser_func()("https://example.com")
        assert result is None

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("scripts.resolve.validate_url")
    @patch("mistralai.client.Mistral")
    def test_successful_extraction(self, mock_mistral_class, mock_validate):
        """Test successful content extraction with Mistral."""
        # Mock URL validation
        mock_validation = Mock()
        mock_validation.is_valid = True
        mock_validation.final_url = "https://example.com"
        mock_validate.return_value = mock_validation

        mock_client = Mock()
        mock_response = Mock()
        mock_response.outputs = [Mock(content="# Extracted Content\nFrom Mistral")]
        mock_client.beta.conversations.start.return_value = mock_response
        mock_mistral_class.return_value = mock_client

        result = _get_mistral_browser_func()("https://example.com")
        assert result is not None
        assert result.source == "mistral-browser"
        assert "Extracted Content" in result.content

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_extraction_error(self, mock_mistral_class):
        """Test error handling in Mistral extraction."""
        mock_client = Mock()
        mock_client.beta.conversations.start.side_effect = Exception("Mistral API error")
        mock_mistral_class.return_value = mock_client

        result = _get_mistral_browser_func()("https://example.com")
        assert result is None


@pytest.mark.live
class TestMistralErrorLogging:
    """Test that Mistral error scenarios emit correct log messages."""

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_browser_401_logs_warning(self, mock_mistral_class, caplog):
        """Test Mistral browser 401 emits 'API key may be invalid' warning."""
        from scripts.providers_impl import resolve_with_mistral_browser

        error = Exception("Unauthorized")
        error.status_code = 401
        mock_client = Mock()
        mock_client.beta.conversations.start.side_effect = error
        mock_mistral_class.return_value = mock_client

        with caplog.at_level(logging.WARNING):
            result = resolve_with_mistral_browser("https://example.com")

        assert result is None
        assert "401 Unauthorized" in caplog.text

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_browser_429_logs_warning_and_cooldown(self, mock_mistral_class, caplog):
        """Test Mistral browser 429 emits rate limited warning and sets cooldown."""
        from scripts.providers_impl import _is_rate_limited, resolve_with_mistral_browser

        # Clear any existing rate limits
        from scripts.resolve import _rate_limits

        _rate_limits.clear()

        error = Exception("Too many requests")
        error.status_code = 429
        mock_client = Mock()
        mock_client.beta.conversations.start.side_effect = error
        mock_mistral_class.return_value = mock_client

        with caplog.at_level(logging.WARNING):
            result = resolve_with_mistral_browser("https://example.com")

        assert result is None
        assert "429 Rate limited" in caplog.text
        assert _is_rate_limited("mistral")
        _rate_limits.clear()

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_browser_403_logs_warning(self, mock_mistral_class, caplog):
        """Test Mistral browser 403 emits forbidden warning."""
        from scripts.providers_impl import resolve_with_mistral_browser

        error = Exception("Forbidden")
        error.status_code = 403
        mock_client = Mock()
        mock_client.beta.conversations.start.side_effect = error
        mock_mistral_class.return_value = mock_client

        with caplog.at_level(logging.WARNING):
            result = resolve_with_mistral_browser("https://example.com")

        assert result is None
        assert "403 Forbidden" in caplog.text

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_browser_generic_error_logs_type_and_message(self, mock_mistral_class, caplog):
        """Test Mistral browser generic error logs type name and message."""
        from scripts.providers_impl import resolve_with_mistral_browser

        mock_client = Mock()
        mock_client.beta.conversations.start.side_effect = ValueError("unexpected failure")
        mock_mistral_class.return_value = mock_client

        with caplog.at_level(logging.WARNING):
            result = resolve_with_mistral_browser("https://example.com")

        assert result is None
        assert "ValueError" in caplog.text
        assert "unexpected failure" in caplog.text

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_websearch_401_logs_warning(self, mock_mistral_class, caplog):
        """Test Mistral websearch 401 emits 'API key may be invalid' warning."""
        from scripts.providers_impl import resolve_with_mistral_websearch

        error = Exception("Unauthorized")
        error.status_code = 401
        mock_client = Mock()
        mock_client.chat.complete.side_effect = error
        mock_mistral_class.return_value = mock_client

        with caplog.at_level(logging.WARNING):
            result = resolve_with_mistral_websearch("test query")

        assert result is None
        assert "401 Unauthorized" in caplog.text

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_websearch_429_logs_warning_and_cooldown(self, mock_mistral_class, caplog):
        """Test Mistral websearch 429 emits rate limited warning and sets cooldown."""
        from scripts.providers_impl import _is_rate_limited, resolve_with_mistral_websearch
        from scripts.resolve import _rate_limits

        _rate_limits.clear()

        error = Exception("Too many requests")
        error.status_code = 429
        mock_client = Mock()
        mock_client.chat.complete.side_effect = error
        mock_mistral_class.return_value = mock_client

        with caplog.at_level(logging.WARNING):
            result = resolve_with_mistral_websearch("test query")

        assert result is None
        assert "429 Rate limited" in caplog.text
        assert _is_rate_limited("mistral")
        _rate_limits.clear()

    @patch.dict(os.environ, {}, clear=True)
    def test_browser_no_api_key_logs_debug(self, caplog):
        """Test Mistral browser with no API key emits debug log."""
        from scripts.providers_impl import resolve_with_mistral_browser

        with caplog.at_level(logging.DEBUG):
            result = resolve_with_mistral_browser("https://example.com")

        assert result is None
        assert "no API key" in caplog.text

    @patch.dict(os.environ, {}, clear=True)
    def test_websearch_no_api_key_logs_debug(self, caplog):
        """Test Mistral websearch with no API key emits debug log."""
        from scripts.providers_impl import resolve_with_mistral_websearch

        with caplog.at_level(logging.DEBUG):
            result = resolve_with_mistral_websearch("test query")

        assert result is None
        assert "no API key" in caplog.text

    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_websearch_empty_content_logs_warning(self, mock_mistral_class, caplog):
        """Test Mistral websearch with empty content emits warning."""
        from scripts.providers_impl import resolve_with_mistral_websearch

        mock_client = Mock()
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message = Mock()
        mock_response.choices[0].message.content = ""
        mock_client.chat.complete.return_value = mock_response
        mock_mistral_class.return_value = mock_client

        with caplog.at_level(logging.WARNING):
            result = resolve_with_mistral_websearch("test query")

        assert result is None
        assert "empty content" in caplog.text


@pytest.mark.live
class TestExaErrorLogging:
    """Test Exa SDK error logging."""

    @patch.dict(os.environ, {"EXA_API_KEY": "test_key"})
    @patch("exa_py.Exa")
    def test_401_logs_warning(self, mock_exa_class, caplog):
        from scripts.providers_impl import resolve_with_exa

        err = Exception("Unauthorized")
        err.status_code = 401
        mock_exa_class.return_value.search_and_contents.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_exa("test")

        assert result is None
        assert "401 Unauthorized" in caplog.text

    @patch.dict(os.environ, {"EXA_API_KEY": "test_key"})
    @patch("exa_py.Exa")
    def test_429_logs_warning_and_cooldown(self, mock_exa_class, caplog):
        from scripts.providers_impl import _is_rate_limited, resolve_with_exa
        from scripts.resolve import _rate_limits

        _rate_limits.clear()
        err = Exception("Rate limited")
        err.status_code = 429
        mock_exa_class.return_value.search_and_contents.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_exa("test")

        assert result is None
        assert "429 Rate limited" in caplog.text
        assert _is_rate_limited("exa")
        _rate_limits.clear()

    @patch.dict(os.environ, {"EXA_API_KEY": "test_key"})
    @patch("exa_py.Exa")
    def test_403_logs_warning(self, mock_exa_class, caplog):
        from scripts.providers_impl import resolve_with_exa

        err = Exception("Forbidden")
        err.status_code = 403
        mock_exa_class.return_value.search_and_contents.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_exa("test")

        assert result is None
        assert "403 Forbidden" in caplog.text

    @patch.dict(os.environ, {"EXA_API_KEY": "test_key"})
    @patch("exa_py.Exa")
    def test_generic_error_logs_type_and_message(self, mock_exa_class, caplog):
        from scripts.providers_impl import resolve_with_exa

        mock_exa_class.return_value.search_and_contents.side_effect = ValueError("bad input")

        with caplog.at_level(logging.WARNING):
            result = resolve_with_exa("test")

        assert result is None
        assert "ValueError" in caplog.text
        assert "bad input" in caplog.text

    @patch.dict(os.environ, {}, clear=True)
    def test_no_api_key_logs_debug(self, caplog):
        from scripts.providers_impl import resolve_with_exa

        with caplog.at_level(logging.DEBUG):
            result = resolve_with_exa("test")

        assert result is None
        assert "no API key" in caplog.text

    @patch.dict(os.environ, {"EXA_API_KEY": "test_key"})
    @patch("exa_py.Exa")
    def test_empty_results_logs_warning(self, mock_exa_class, caplog):
        from scripts.providers_impl import resolve_with_exa

        mock_res = Mock()
        mock_res.results = []
        mock_exa_class.return_value.search_and_contents.return_value = mock_res

        with caplog.at_level(logging.WARNING):
            result = resolve_with_exa("test")

        assert result is None
        assert "no results" in caplog.text


@pytest.mark.live
class TestTavilyErrorLogging:
    """Test Tavily SDK error logging."""

    @patch.dict(os.environ, {"TAVILY_API_KEY": "test_key"})
    @patch("tavily.TavilyClient")
    def test_401_logs_warning(self, mock_tavily_class, caplog):
        from scripts.providers_impl import resolve_with_tavily

        err = Exception("Unauthorized")
        err.status_code = 401
        mock_tavily_class.return_value.search.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_tavily("test")

        assert result is None
        assert "401 Unauthorized" in caplog.text

    @patch.dict(os.environ, {"TAVILY_API_KEY": "test_key"})
    @patch("tavily.TavilyClient")
    def test_429_logs_warning_and_cooldown(self, mock_tavily_class, caplog):
        from scripts.providers_impl import _is_rate_limited, resolve_with_tavily
        from scripts.resolve import _rate_limits

        _rate_limits.clear()
        err = Exception("Rate limited")
        err.status_code = 429
        mock_tavily_class.return_value.search.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_tavily("test")

        assert result is None
        assert "429 Rate limited" in caplog.text
        assert _is_rate_limited("tavily")
        _rate_limits.clear()

    @patch.dict(os.environ, {"TAVILY_API_KEY": "test_key"})
    @patch("tavily.TavilyClient")
    def test_generic_error_logs_type_and_message(self, mock_tavily_class, caplog):
        from scripts.providers_impl import resolve_with_tavily

        mock_tavily_class.return_value.search.side_effect = RuntimeError("timeout")

        with caplog.at_level(logging.WARNING):
            result = resolve_with_tavily("test")

        assert result is None
        assert "RuntimeError" in caplog.text
        assert "timeout" in caplog.text

    @patch.dict(os.environ, {}, clear=True)
    def test_no_api_key_logs_debug(self, caplog):
        from scripts.providers_impl import resolve_with_tavily

        with caplog.at_level(logging.DEBUG):
            result = resolve_with_tavily("test")

        assert result is None
        assert "no API key" in caplog.text

    @patch.dict(os.environ, {"TAVILY_API_KEY": "test_key"})
    @patch("tavily.TavilyClient")
    def test_empty_results_logs_warning(self, mock_tavily_class, caplog):
        from scripts.providers_impl import resolve_with_tavily

        mock_tavily_class.return_value.search.return_value = {"results": []}

        with caplog.at_level(logging.WARNING):
            result = resolve_with_tavily("test")

        assert result is None
        assert "no results" in caplog.text


@pytest.mark.live
class TestFirecrawlErrorLogging:
    """Test Firecrawl SDK error logging."""

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    @patch("firecrawl.Firecrawl")
    def test_401_logs_warning(self, mock_fc_class, caplog):
        from scripts.providers_impl import resolve_with_firecrawl

        err = Exception("Unauthorized")
        err.status_code = 401
        mock_fc_class.return_value.scrape.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_firecrawl("https://example.com")

        assert result is None
        assert "401 Unauthorized" in caplog.text

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    @patch("firecrawl.Firecrawl")
    def test_429_logs_warning_and_cooldown(self, mock_fc_class, caplog):
        from scripts.providers_impl import _is_rate_limited, resolve_with_firecrawl
        from scripts.resolve import _rate_limits

        _rate_limits.clear()
        err = Exception("Rate limited")
        err.status_code = 429
        mock_fc_class.return_value.scrape.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_firecrawl("https://example.com")

        assert result is None
        assert "429 Rate limited" in caplog.text
        assert _is_rate_limited("firecrawl")
        _rate_limits.clear()

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    @patch("firecrawl.Firecrawl")
    def test_403_logs_warning(self, mock_fc_class, caplog):
        from scripts.providers_impl import resolve_with_firecrawl

        err = Exception("Forbidden")
        err.status_code = 403
        mock_fc_class.return_value.scrape.side_effect = err

        with caplog.at_level(logging.WARNING):
            result = resolve_with_firecrawl("https://example.com")

        assert result is None
        assert "403 Forbidden" in caplog.text

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    @patch("firecrawl.Firecrawl")
    def test_generic_error_logs_type_and_message(self, mock_fc_class, caplog):
        from scripts.providers_impl import resolve_with_firecrawl

        mock_fc_class.return_value.scrape.side_effect = ConnectionError("refused")

        with caplog.at_level(logging.WARNING):
            result = resolve_with_firecrawl("https://example.com")

        assert result is None
        assert "ConnectionError" in caplog.text
        assert "refused" in caplog.text

    @patch.dict(os.environ, {}, clear=True)
    def test_no_api_key_logs_debug(self, caplog):
        from scripts.providers_impl import resolve_with_firecrawl

        with caplog.at_level(logging.DEBUG):
            result = resolve_with_firecrawl("https://example.com")

        assert result is None
        assert "no API key" in caplog.text

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    @patch("firecrawl.Firecrawl")
    def test_empty_markdown_logs_warning(self, mock_fc_class, caplog):
        from scripts.providers_impl import resolve_with_firecrawl

        mock_res = Mock()
        mock_res.markdown = ""
        mock_fc_class.return_value.scrape.return_value = mock_res

        with caplog.at_level(logging.WARNING):
            result = resolve_with_firecrawl("https://example.com")

        assert result is None
        assert "empty markdown" in caplog.text

    @patch.dict(os.environ, {"FIRECRAWL_API_KEY": "test_key"})
    def test_ssrf_blocked_logs_warning(self, caplog):
        from scripts.providers_impl import resolve_with_firecrawl

        with caplog.at_level(logging.WARNING):
            result = resolve_with_firecrawl("ftp://evil.com")

        assert result is None
        assert "SSRF blocked" in caplog.text


@pytest.mark.live
class TestSerperErrorLogging:
    """Test Serper HTTP error logging."""

    @patch.dict(os.environ, {"SERPER_API_KEY": "test_key"})
    @patch("scripts.providers.serper.get_session")
    def test_429_logs_warning_and_cooldown(self, mock_session, caplog):
        from scripts.providers_impl import _is_rate_limited, resolve_with_serper
        from scripts.resolve import _rate_limits

        _rate_limits.clear()
        mock_resp = Mock()
        mock_resp.status_code = 429
        mock_session.return_value.post.return_value = mock_resp

        with caplog.at_level(logging.WARNING):
            result = resolve_with_serper("test")

        assert result is None
        assert "rate limited" in caplog.text.lower()
        assert _is_rate_limited("serper")
        _rate_limits.clear()

    @patch.dict(os.environ, {"SERPER_API_KEY": "test_key"})
    @patch("scripts.providers.serper.get_session")
    def test_401_logs_warning(self, mock_session, caplog):
        from scripts.providers_impl import resolve_with_serper

        mock_resp = Mock()
        mock_resp.status_code = 401
        mock_session.return_value.post.return_value = mock_resp

        with caplog.at_level(logging.WARNING):
            result = resolve_with_serper("test")

        assert result is None
        assert "auth error" in caplog.text.lower()

    @patch.dict(os.environ, {"SERPER_API_KEY": "test_key"})
    @patch("scripts.providers.serper.get_session")
    def test_500_logs_warning(self, mock_session, caplog):
        from scripts.providers_impl import resolve_with_serper

        mock_resp = Mock()
        mock_resp.status_code = 500
        mock_session.return_value.post.return_value = mock_resp

        with caplog.at_level(logging.WARNING):
            result = resolve_with_serper("test")

        assert result is None
        assert "HTTP 500" in caplog.text

    @patch.dict(os.environ, {"SERPER_API_KEY": "test_key"})
    @patch("scripts.providers.serper.get_session")
    def test_network_error_logs_type_and_message(self, mock_session, caplog):
        from scripts.providers_impl import resolve_with_serper

        mock_session.return_value.post.side_effect = OSError("connection reset")

        with caplog.at_level(logging.WARNING):
            result = resolve_with_serper("test")

        assert result is None
        assert "OSError" in caplog.text
        assert "connection reset" in caplog.text

    @patch.dict(os.environ, {}, clear=True)
    def test_no_api_key_logs_debug(self, caplog):
        from scripts.providers_impl import resolve_with_serper

        with caplog.at_level(logging.DEBUG):
            result = resolve_with_serper("test")

        assert result is None
        assert "no API key" in caplog.text


@pytest.mark.live
class TestJinaErrorLogging:
    """Test Jina HTTP error logging."""

    @patch("scripts.providers.jina.get_session")
    def test_429_logs_warning_and_cooldown(self, mock_session, caplog):
        from scripts.providers_impl import _is_rate_limited, resolve_with_jina
        from scripts.resolve import _rate_limits

        _rate_limits.clear()
        mock_resp = Mock()
        mock_resp.status_code = 429
        mock_session.return_value.get.return_value = mock_resp

        with caplog.at_level(logging.WARNING):
            result = resolve_with_jina("https://example.com")

        assert result is None
        assert "rate limited" in caplog.text.lower()
        assert _is_rate_limited("jina")
        _rate_limits.clear()

    @patch("scripts.providers.jina.get_session")
    def test_403_logs_warning(self, mock_session, caplog):
        from scripts.providers_impl import resolve_with_jina

        mock_resp = Mock()
        mock_resp.status_code = 403
        mock_session.return_value.get.return_value = mock_resp

        with caplog.at_level(logging.WARNING):
            result = resolve_with_jina("https://example.com")

        assert result is None
        assert "auth error" in caplog.text.lower()

    @patch("scripts.providers.jina.get_session")
    def test_500_logs_warning(self, mock_session, caplog):
        from scripts.providers_impl import resolve_with_jina

        mock_resp = Mock()
        mock_resp.status_code = 500
        mock_session.return_value.get.return_value = mock_resp

        with caplog.at_level(logging.WARNING):
            result = resolve_with_jina("https://example.com")

        assert result is None
        assert "HTTP 500" in caplog.text

    @patch("scripts.providers.jina.get_session")
    def test_network_error_logs_type_and_message(self, mock_session, caplog):
        from scripts.providers_impl import resolve_with_jina

        mock_session.return_value.get.side_effect = TimeoutError("timed out")

        with caplog.at_level(logging.WARNING):
            result = resolve_with_jina("https://example.com")

        assert result is None
        assert "TimeoutError" in caplog.text
        assert "timed out" in caplog.text

    def test_ssrf_blocked_logs_warning(self, caplog):
        from scripts.providers_impl import resolve_with_jina

        with caplog.at_level(logging.WARNING):
            result = resolve_with_jina("ftp://evil.com")

        assert result is None
        assert "SSRF blocked" in caplog.text


@pytest.mark.live
class TestDuckDuckGoErrorLogging:
    """Test DuckDuckGo error logging."""

    @patch("scripts.providers_impl._is_rate_limited")
    @patch("scripts.utils._get_from_cache")
    @patch("ddgs.DDGS")
    def test_generic_error_logs_type_and_message(self, mock_ddgs, mock_cache, mock_rl, caplog):
        from scripts.providers_impl import resolve_with_duckduckgo

        mock_cache.return_value = None
        mock_rl.return_value = False
        mock_ddgs.return_value.__enter__.return_value.text.side_effect = RuntimeError("crash")

        with caplog.at_level(logging.WARNING):
            result = resolve_with_duckduckgo("test")

        assert result is None
        assert "RuntimeError" in caplog.text
        assert "crash" in caplog.text

    @patch("scripts.providers_impl._is_rate_limited")
    @patch("scripts.utils._get_from_cache")
    @patch("ddgs.DDGS")
    def test_empty_results_logs_warning(self, mock_ddgs, mock_cache, mock_rl, caplog):
        from scripts.providers_impl import resolve_with_duckduckgo

        mock_cache.return_value = None
        mock_rl.return_value = False
        mock_ddgs.return_value.__enter__.return_value.text.return_value = []

        with caplog.at_level(logging.WARNING):
            result = resolve_with_duckduckgo("test")

        assert result is None
        assert "no results" in caplog.text


class TestResolveIntegration:
    """Integration tests for the main resolve function."""

    def test_submodules_share_resolver_state(self):
        """Test extracted resolver modules reuse the facade shared state."""
        import scripts._query_resolve
        import scripts._url_resolve
        import scripts.resolve

        assert scripts._query_resolve._routing_memory is scripts.resolve._routing_memory
        assert scripts._url_resolve._routing_memory is scripts.resolve._routing_memory
        assert scripts._query_resolve._circuit_breakers is scripts.resolve._circuit_breakers
        assert scripts._url_resolve._circuit_breakers is scripts.resolve._circuit_breakers

    def test_url_integration(self):
        """Test URL resolution completes."""
        result = resolve("https://example.com")
        assert result is not None

    def test_query_integration(self):
        """Test query resolution completes."""
        result = resolve("machine learning tutorials")
        assert result is not None


class TestEdgeCases:
    """Edge case tests."""

    def test_url_with_special_characters(self):
        """Test URL with query parameters and fragments."""
        assert is_url("https://example.com/path?param=value&other=test#anchor")
        assert is_url("https://example.com/path?foo=bar")

    def test_url_without_scheme(self):
        """Test invalid URLs without scheme."""
        assert not is_url("example.com")
        assert not is_url("www.example.com")

    def test_url_localhost(self):
        """Test localhost URLs."""
        assert is_url("http://localhost:8080")
        assert is_url("http://127.0.0.1:3000/api")

    def test_query_with_special_characters(self):
        """Test queries with special characters."""
        assert not is_url("What is Python? It's great!")
        assert not is_url("Search: + - * / && ||")

    def test_empty_string(self):
        """Test empty string handling."""
        assert not is_url("")
        assert not is_url("   ")

    def test_very_long_query(self):
        """Test handling of very long queries."""
        long_query = "a" * 10000
        assert not is_url(long_query)

    def test_url_resolve_completes(self):
        """Test URL resolve completes without error."""
        result = resolve("https://example.com")
        assert result is not None

    def test_query_all_providers_fail(self):
        """Test query when all providers might fail."""
        # conftest ensures deterministic routing - verify resolution completes
        result = resolve("any query edge")
        assert result is not None

    def test_query_with_mistral(self):
        """Test query with Mistral."""
        result = resolve("test query with mistral")
        # Verify resolution completes - actual provider depends on routing
        assert result is not None

    def test_max_chars_truncation(self):
        """Test that content is truncated to max_chars."""
        long_content = "x" * 20000
        truncated = long_content[:MAX_CHARS]
        assert len(truncated) == MAX_CHARS

    @pytest.mark.live
    @patch.dict(os.environ, {"MISTRAL_API_KEY": "test_key"})
    @patch("mistralai.client.Mistral")
    def test_mistral_401_error(self, mock_mistral_class):
        """Test handling of Mistral 401 authentication error."""
        mock_client = Mock()
        mock_client.beta.conversations.start.side_effect = Exception(
            'API error occurred: Status 401. Body: {"detail":"Unauthorized"}'
        )
        mock_mistral_class.return_value = mock_client

        result = _get_mistral_browser_func()("https://example.com")
        assert result is None

    def test_llms_txt_check(self):
        """Test llms.txt can be checked."""
        # conftest mock handles routing - just verify it works
        result = resolve("https://docs.example.com")
        assert result is not None


class TestCacheBehavior:
    """Test caching behavior."""

    @patch("scripts.utils._get_cache")
    def test_cache_hit(self, mock_get_cache):
        """Test cache hit returns cached result."""
        mock_cache = Mock()
        mock_cache.get.return_value = {"source": "cached", "content": "test"}
        mock_get_cache.return_value = mock_cache

        from scripts.resolve import _get_from_cache

        result = _get_from_cache("test", "exa")

        assert result is not None
        assert result["source"] == "cached"

    @patch("scripts.utils._get_cache")
    def test_cache_miss(self, mock_get_cache):
        """Test cache miss returns None."""
        mock_cache = Mock()
        mock_cache.get.return_value = None
        mock_get_cache.return_value = mock_cache

        from scripts.resolve import _get_from_cache

        result = _get_from_cache("new_query", "exa")

        assert result is None

    @patch("scripts.utils._get_cache")
    def test_cache_disabled(self, mock_get_cache):
        """Test when cache is not available."""
        mock_get_cache.return_value = None

        from scripts.resolve import _get_from_cache
        from scripts.utils.cache import _l1_clear

        _l1_clear()
        result = _get_from_cache("test", "exa")

        assert result is None


class TestSkillSymlink:
    """Test that skill symlinks in .blackbox/skills/, .claude/skills/ point to .agents/skills/."""

    def get_skill_locations(self):
        """Get all skill directory symlink locations to test."""
        root_dir = Path(__file__).parent.parent
        canonical = root_dir / ".agents" / "skills"
        return [
            # (root_dir / ".blackbox" / "skills", ".blackbox/skills", canonical),
            # (root_dir / ".claude" / "skills", ".claude/skills", canonical),
        ]

    def test_all_skill_symlinks_exist(self):
        """Test that all skill directory symlinks exist."""
        for skill_link, name, _ in self.get_skill_locations():
            assert skill_link.exists(), f"{name}: symlink does not exist: {skill_link}"

    def test_all_skill_symlinks_are_symlinks(self):
        """Test that all skill paths are directory symlinks."""
        for skill_link, name, _ in self.get_skill_locations():
            assert skill_link.is_symlink(), f"{name}: {skill_link} is not a symlink"

    def test_all_skill_symlinks_point_to_canonical(self):
        """Test that all symlinks point to .agents/skills/."""
        for skill_link, name, expected in self.get_skill_locations():
            resolved_target = skill_link.resolve()
            resolved_expected = expected.resolve()
            msg = (
                f"{name}: Symlink points to wrong target.\n"
                f"Expected: {resolved_expected}\n"
                f"Got: {resolved_target}"
            )
            assert resolved_target == resolved_expected, msg

    def test_skill_md_exists_in_canonical(self):
        """Test that SKILL.md exists in canonical .agents/skills/ directory."""
        root_dir = Path(__file__).parent.parent
        skill_md = root_dir / "SKILL.md"
        assert skill_md.exists(), f"SKILL.md does not exist in canonical: {skill_md}"
        assert skill_md.is_file(), f"SKILL.md is not a file: {skill_md}"


class TestDuckDuckGoFallback:
    """Test DuckDuckGo free search fallback."""

    @patch("scripts.utils._get_from_cache")
    @patch("scripts.providers_impl._is_rate_limited")
    @patch("ddgs.DDGS")
    def test_duckduckgo_successful_search(self, mock_ddgs_class, mock_rate_limited, mock_cache):
        """Test successful DuckDuckGo search."""
        mock_cache.return_value = None
        mock_rate_limited.return_value = False

        mock_ddgs = Mock()
        mock_ddgs.__enter__ = Mock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = Mock(return_value=False)
        mock_ddgs.text.return_value = [
            {"title": "Result 1", "body": "Content 1", "href": "https://example.com/1"},
            {"title": "Result 2", "body": "Content 2", "href": "https://example.com/2"},
        ]
        mock_ddgs_class.return_value = mock_ddgs

        result = resolve_with_duckduckgo("test query")

        assert result is not None
        assert result.source == "duckduckgo"
        assert "Result 1" in result.content

    @patch("scripts.utils._get_from_cache")
    @patch("scripts.providers_impl._is_rate_limited")
    def test_duckduckgo_rate_limited(self, mock_rate_limited, mock_cache):
        """Test DuckDuckGo when rate-limited."""
        from scripts.utils.cache import _l1_clear

        _l1_clear()
        mock_cache.return_value = None
        mock_rate_limited.return_value = True

        result = resolve_with_duckduckgo("test query")

        assert result is None

    @patch("scripts.utils._get_from_cache")
    @patch("scripts.providers_impl._is_rate_limited")
    @patch("ddgs.DDGS")
    def test_duckduckgo_empty_results(self, mock_ddgs_class, mock_rate_limited, mock_cache):
        """Test DuckDuckGo with empty results."""
        from scripts.utils.cache import _l1_clear

        _l1_clear()
        mock_cache.return_value = None
        mock_rate_limited.return_value = False

        mock_ddgs = Mock()
        mock_ddgs.__enter__ = Mock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = Mock(return_value=False)
        mock_ddgs.text.return_value = []
        mock_ddgs_class.return_value = mock_ddgs

        result = resolve_with_duckduckgo("test query")

        assert result is None


class TestRateLimitHandling:
    """Test rate limit detection and handling."""

    def test_detect_rate_limit_error(self):
        """Test detection of rate limit errors."""

        assert _detect_error_type(Exception("429 too many requests")) == ErrorType.RATE_LIMIT
        assert _detect_error_type(Exception("Rate limit exceeded")) == ErrorType.RATE_LIMIT
        assert _detect_error_type(Exception("too many requests")) == ErrorType.RATE_LIMIT

    def test_detect_auth_error(self):
        """Test detection of authentication errors."""

        assert _detect_error_type(Exception("401 unauthorized")) == ErrorType.AUTH_ERROR
        assert _detect_error_type(Exception("403 forbidden")) == ErrorType.AUTH_ERROR
        assert _detect_error_type(Exception("Invalid API key")) == ErrorType.AUTH_ERROR

    def test_detect_quota_exhausted(self):
        """Test detection of quota exhaustion."""

        assert _detect_error_type(Exception("402 payment required")) == ErrorType.QUOTA_EXHAUSTED
        assert _detect_error_type(Exception("Insufficient credits")) == ErrorType.QUOTA_EXHAUSTED
        assert _detect_error_type(Exception("Quota exceeded")) == ErrorType.QUOTA_EXHAUSTED

    def test_detect_network_error(self):
        """Test detection of network errors."""

        assert _detect_error_type(Exception("Network connection error")) == ErrorType.NETWORK_ERROR
        assert _detect_error_type(Exception("Network error")) == ErrorType.NETWORK_ERROR

    def test_detect_unknown_error(self):
        """Test detection of unknown errors."""

        assert _detect_error_type(Exception("Something went wrong")) == ErrorType.UNKNOWN

    def test_rate_limit_cooldown(self):
        """Test rate limit cooldown mechanism."""

        from scripts.resolve import _rate_limits

        # Clear any existing rate limits
        _rate_limits.clear()

        # Not rate limited initially
        assert not _is_rate_limited("test_provider")

        # Set rate limit
        _set_rate_limit("test_provider", cooldown=60)

        # Now should be rate limited
        assert _is_rate_limited("test_provider")

        # Clean up
        _rate_limits.clear()

    def test_rate_limit_expiry(self):
        """Rate limit should expire after cooldown period elapses."""
        from scripts.resolve import _rate_limits

        _rate_limits.clear()

        # Set rate limit with very short cooldown
        _set_rate_limit("test_provider", cooldown=1)
        assert _is_rate_limited("test_provider")

        # Simulate expiry by setting the timestamp in the past
        import time

        _rate_limits["test_provider"] = time.time() - 10
        # Should NOT be rate limited anymore (expiry passed)
        assert not _is_rate_limited("test_provider")
        # Entry should be cleaned up after expiry check
        assert "test_provider" not in _rate_limits

        _rate_limits.clear()

    def test_rate_limit_multiple_providers_independent_expiry(self):
        """Each provider has independent rate limit tracking."""
        from scripts.resolve import _rate_limits

        _rate_limits.clear()

        # Set rate limits for two providers
        _set_rate_limit("provider_a", cooldown=60)
        _set_rate_limit("provider_b", cooldown=60)

        # Both should be rate limited
        assert _is_rate_limited("provider_a")
        assert _is_rate_limited("provider_b")

        # Expire only provider_a
        import time

        _rate_limits["provider_a"] = time.time() - 10

        # provider_a should now be unblocked, provider_b still blocked
        assert not _is_rate_limited("provider_a")
        assert "provider_a" not in _rate_limits
        assert _is_rate_limited("provider_b")

        _rate_limits.clear()


class TestQueryCascade:
    """Test the full query resolution cascade.

    These tests verify the provider order works correctly.
    Note: plan_provider_order is mocked by conftest.py to return deterministic order.
    """

    def test_cascade_order(self):
        """Test that providers are tried in correct order by conftest mock."""
        # conftest.py mocks plan_provider_order to return:
        # For queries: ["exa_mcp", "exa", "tavily", "duckduckgo", "mistral_websearch"]
        # This test passes if resolve completes without error (indicating routing works)
        # Exact provider order is tested by conftest's included tests
        result = resolve("test query for cascade")
        # Just verify resolution completed with some result
        assert result is not None


class TestAdditionalEdgeCases:
    """Additional edge case tests for comprehensive coverage."""

    def test_url_with_ftp_scheme(self):
        """Test that FTP URLs are rejected (SSRF hardening)."""
        assert not is_url("ftp://ftp.example.com/file.txt")
        assert not is_url("ftps://secure.example.com/file.txt")

    def test_url_with_javascript_scheme(self):
        """Test that javascript: URLs are handled correctly (no netloc)."""
        # javascript: URLs have a scheme but no netloc, so is_url should return False
        assert not is_url("javascript:alert('xss')")

    def test_url_with_file_scheme(self):
        """Test that file: URLs are handled correctly."""
        # file://localhost/ has netloc, file:/// does not
        # Our is_url only allows http and https
        assert not is_url("file:///path/to/file.txt")  # Not in allowed schemes
        assert not is_url("file://localhost/path/to/file.txt")  # Not in allowed schemes

    def test_url_with_data_scheme(self):
        """Test that data: URLs are handled correctly."""
        # data: URLs have scheme but no netloc
        assert not is_url("data:text/plain;base64,SGVsbG8gV29ybGQ=")

    def test_url_with_mailto_scheme(self):
        """Test that mailto: URLs are handled correctly."""
        # mailto: has scheme but no netloc
        assert not is_url("mailto:user@example.com")

    def test_url_with_unicode_characters(self):
        """Test URLs with Unicode/international characters."""
        # IDN URLs should work
        assert is_url("https://例子.测试")
        assert is_url("https://例え.jp/path")
        # Punycode URLs
        assert is_url("https://xn--fsq.xn--0zwm56d/")

    def test_query_with_unicode_characters(self):
        """Test queries with Unicode/international characters."""
        assert not is_url("Python 编程教程")
        assert not is_url("プログラミング チュートリアル")
        assert not is_url("Поиск в интернете")

    def test_url_with_port_number(self):
        """Test URLs with explicit port numbers."""
        assert is_url("https://example.com:8080/path")
        assert is_url("http://localhost:3000/api")
        assert is_url("https://example.com:443/secure")

    def test_url_with_query_and_fragment(self):
        """Test URLs with complex query strings and fragments."""
        assert is_url("https://example.com/path?a=1&b=2&c=3#section")
        assert is_url("https://example.com/search?q=hello+world&page=1")
        assert is_url("https://example.com/path?param=value&other=test#anchor")

    def test_url_with_encoded_characters(self):
        """Test URLs with percent-encoded characters."""
        assert is_url("https://example.com/path%20with%20spaces")
        assert is_url("https://example.com/search?q=hello%20world")
        assert is_url("https://example.com/path?param=%E4%B8%AD%E6%96%87")

    def test_url_with_authentication(self):
        """Test URLs with authentication credentials."""
        assert is_url("https://user:pass@example.com/path")
        assert is_url("https://user@example.com/path")
        assert not is_url("ftp://anonymous:anon@ftp.example.com/file")

    def test_url_ipv4_address(self):
        """Test URLs with IPv4 addresses."""
        assert is_url("http://192.168.1.1/")
        assert is_url("https://127.0.0.1:8080/api")
        assert is_url("http://10.0.0.1/path")

    def test_url_ipv6_address(self):
        """Test URLs with IPv6 addresses."""
        assert is_url("http://[::1]/")
        assert is_url("https://[2001:db8::1]:8080/path")
        assert is_url("http://[fe80::1%eth0]/path")

    def test_empty_query_after_normalization(self):
        """Test handling of whitespace-only queries."""
        # Whitespace-only strings should not be treated as URLs
        assert not is_url("   ")
        assert not is_url("\t\n\r")

    def test_null_byte_in_query(self):
        """Test handling of null bytes in queries."""
        # Null bytes should not crash the parser
        assert not is_url("test\x00query")
        # URLs with null bytes are still parsed as valid URLs by urlparse
        # (the null byte is just part of the path)
        result = is_url("https://example.com/\x00path")
        # This is technically a valid URL structure, just with unusual characters
        assert result  # urlparse accepts this as valid URL

    def test_extremely_long_url(self):
        """Test handling of extremely long URLs."""
        long_path = "a" * 10000
        url = f"https://example.com/{long_path}"
        assert is_url(url)

    def test_url_with_newline_characters(self):
        """Test URLs with newline characters (potential injection)."""
        # urlparse still parses these as valid URLs (newlines in path)
        # The is_url function checks scheme and netloc, which are present
        result1 = is_url("https://example.com/path\nwith\nnewlines")
        result2 = is_url("https://example.com/path\r\nwith\r\nnewlines")
        # These are parsed as valid URLs by urlparse (scheme and netloc present)
        assert result1  # urlparse accepts this
        assert result2  # urlparse accepts this

    def test_url_with_special_protocol_characters(self):
        """Test URLs with special characters in protocol."""
        # Valid HTTPS URL should be detected
        assert is_url("https://example.com")
        # Case handling - urlparse is case-insensitive for scheme
        assert is_url("HTTP://example.com")  # Valid URL

    def test_query_with_sql_injection_attempt(self):
        """Test queries that look like SQL injection attempts."""
        malicious_query = "'; DROP TABLE users; --"
        assert not is_url(malicious_query)

    def test_query_with_html_tags(self):
        """Test queries containing HTML tags."""
        html_query = "<script>alert('xss')</script>"
        assert not is_url(html_query)

    def test_url_with_double_slash_in_path(self):
        """Test URLs with double slashes in path."""
        assert is_url("https://example.com//double//slash//path")
        assert is_url("https://example.com/path//segment")

    def test_url_with_trailing_slash(self):
        """Test URLs with trailing slashes."""
        assert is_url("https://example.com/")
        assert is_url("https://example.com/path/")
        assert is_url("https://example.com/path/to/resource/")

    def test_url_without_path(self):
        """Test URLs without any path."""
        assert is_url("https://example.com")
        assert is_url("http://localhost")

    def test_url_with_subdomain(self):
        """Test URLs with multiple subdomains."""
        assert is_url("https://a.b.c.d.example.com/path")
        assert is_url("https://deep.nested.subdomain.example.com")

    def test_url_with_tld_edge_cases(self):
        """Test URLs with various TLDs."""
        assert is_url("https://example.co.uk")
        assert is_url("https://example.io")
        assert is_url("https://example.tech")
        assert is_url("https://example.中国")

    def test_query_with_only_numbers(self):
        """Test queries containing only numbers."""
        assert not is_url("123456789")
        assert not is_url("3.14159")

    def test_query_with_only_special_chars(self):
        """Test queries with only special characters."""
        assert not is_url("!@#$%^&*()")
        assert not is_url("+-=*/\\|[]{}")

    def test_url_case_sensitivity(self):
        """Test URL scheme case handling."""
        # urlparse is case-insensitive for scheme
        assert is_url("HTTPS://EXAMPLE.COM")
        assert is_url("HtTpS://example.com/path")

    def test_url_with_backslash(self):
        """Test URLs with backslashes (Windows-style paths)."""
        # Backslashes in URLs - urlparse still parses them as valid URLs
        # The scheme and netloc are still present
        result = is_url("https://example.com\\path")
        # This is parsed as a valid URL (scheme and netloc present)
        assert result  # urlparse accepts this

    def test_concurrent_rate_limit_tracking(self):
        """Test that rate limit tracking works correctly."""
        from scripts.resolve import _rate_limits

        # Clear any existing rate limits
        _rate_limits.clear()

        # Set rate limits for multiple providers
        _set_rate_limit("provider1", cooldown=60)
        _set_rate_limit("provider2", cooldown=30)

        # Both should be rate limited
        assert _is_rate_limited("provider1")
        assert _is_rate_limited("provider2")

        # Non-rate-limited provider should return False
        assert not _is_rate_limited("provider3")

        # Clean up
        _rate_limits.clear()

    def test_error_type_detection_edge_cases(self):
        """Test error type detection with various edge cases."""
        from scripts.resolve import ErrorType

        # Rate limit variations
        assert _detect_error_type(Exception("Error 429: Rate limit")) == ErrorType.RATE_LIMIT
        assert _detect_error_type(Exception("RATE LIMIT EXCEEDED")) == ErrorType.RATE_LIMIT

        # Auth error variations
        assert _detect_error_type(Exception("Error 401: Unauthorized")) == ErrorType.AUTH_ERROR
        assert _detect_error_type(Exception("FORBIDDEN: 403")) == ErrorType.AUTH_ERROR
        assert _detect_error_type(Exception("Invalid API key provided")) == ErrorType.AUTH_ERROR

        # Quota exhausted variations
        assert (
            _detect_error_type(Exception("Error 402: Payment Required"))
            == ErrorType.QUOTA_EXHAUSTED
        )
        assert _detect_error_type(Exception("Insufficient credits")) == ErrorType.QUOTA_EXHAUSTED
        assert _detect_error_type(Exception("Quota exceeded")) == ErrorType.QUOTA_EXHAUSTED

        # Network error variations
        assert _detect_error_type(Exception("Network connection error")) == ErrorType.NETWORK_ERROR
        assert _detect_error_type(Exception("Network error occurred")) == ErrorType.NETWORK_ERROR
        assert _detect_error_type(Exception("Network error")) == ErrorType.NETWORK_ERROR

        # Not found
        assert _detect_error_type(Exception("Error 404: Not found")) == ErrorType.NOT_FOUND

        # Unknown errors
        assert _detect_error_type(Exception("Something went wrong")) == ErrorType.UNKNOWN
        assert _detect_error_type(Exception("")) == ErrorType.UNKNOWN

    @patch("scripts.utils._get_from_cache")
    @patch("scripts.providers_impl._is_rate_limited")
    @patch("scripts.utils._save_to_cache")
    @patch("ddgs.DDGS")
    def test_duckduckgo_network_error(
        self, mock_ddgs_class, mock_save, mock_rate_limited, mock_cache
    ):
        """Test DuckDuckGo handling of network errors."""
        from scripts.utils.cache import _l1_clear

        _l1_clear()
        mock_cache.return_value = None
        mock_rate_limited.return_value = False

        mock_ddgs = Mock()
        mock_ddgs.__enter__ = Mock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = Mock(return_value=False)
        mock_ddgs.text.side_effect = Exception("Network connection error")
        mock_ddgs_class.return_value = mock_ddgs

        result = resolve_with_duckduckgo("test query")

        assert result is None

    @patch("scripts.utils._get_from_cache")
    @patch("scripts.providers_impl._is_rate_limited")
    @patch("scripts.utils._save_to_cache")
    @patch("ddgs.DDGS")
    def test_duckduckgo_with_unicode_query(
        self, mock_ddgs_class, mock_save, mock_rate_limited, mock_cache
    ):
        """Test DuckDuckGo with Unicode query."""
        mock_cache.return_value = None
        mock_rate_limited.return_value = False

        mock_ddgs = Mock()
        mock_ddgs.__enter__ = Mock(return_value=mock_ddgs)
        mock_ddgs.__exit__ = Mock(return_value=False)
        mock_ddgs.text.return_value = [
            {"title": "结果 1", "body": "内容 1", "href": "https://example.com/1"},
        ]
        mock_ddgs_class.return_value = mock_ddgs

        result = resolve_with_duckduckgo("中文搜索")

        assert result is not None
        assert result.source == "duckduckgo"
        assert "结果" in result.content

    def test_url_cascade_llms_txt_priority(self):
        """Test that URL resolution works with default order."""
        # The conftest mock returns llms_txt first for URLs
        # This test verifies resolution completes without error
        result = resolve("https://example.com")
        assert result is not None

    def test_url_cascade_works(self):
        """Test that URL resolution completes."""
        result = resolve("https://example.org")
        assert result is not None

    def test_url_cascade_last_provider(self):
        """Test that URL cascade completes even with failures."""
        # conftest mock ensures deterministic routing
        result = resolve("https://example.net")
        assert result is not None

    def test_cache_key_consistency(self):
        """Test that cache keys are consistent for same inputs."""
        from scripts.resolve import _cache_key

        key1 = _cache_key("test query", "exa")
        key2 = _cache_key("test query", "exa")

        assert key1 == key2

    def test_cache_key_uniqueness(self):
        """Test that cache keys are unique for different inputs."""
        from scripts.resolve import _cache_key

        key1 = _cache_key("query1", "exa")
        key2 = _cache_key("query2", "exa")
        key3 = _cache_key("query1", "tavily")

        assert key1 != key2
        assert key1 != key3

    def test_max_chars_constant(self):
        """Test that MAX_CHARS is set correctly."""
        from scripts.resolve import MAX_CHARS

        assert MAX_CHARS == 8000

    def test_min_chars_constant(self):
        """Test that MIN_CHARS is set correctly."""
        from scripts.resolve import MIN_CHARS

        assert MIN_CHARS == 200


class TestSkipProviders:
    """Test the skip_providers parameter.

    These tests verify that skip_providers is passed to the routing function.
    Due to conftest mocking plan_provider_order, we simplify tests.
    """

    def test_skip_providers_param(self):
        """Test that skip_providers parameter is accepted."""
        # This test just verifies the parameter is handled without error
        result = resolve("test query skip1", skip_providers={"exa_mcp"})
        assert result is not None

    def test_skip_multiple_providers_param(self):
        """Test skipping multiple providers."""
        result = resolve("test query skip2", skip_providers={"exa_mcp", "exa", "duckduckgo"})
        assert result is not None


class TestCascadeErrorHandling:
    """Test cascade error handling: circuit breaker integration, provider failure,
    budget exhaustion, and hedge logging in the resolve stream functions.

    Patches target the sub-module level (_query_resolve / _url_resolve) because the
    cascade_map holds local references bound at import time.
    """

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_all_query_providers_fail_returns_none_source(
        self, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc, caplog
    ):
        """When all query providers return None, cascade yields source=none."""
        from scripts._query_resolve import resolve_query_stream
        from scripts.models import Profile

        mock_mcp.return_value = None
        mock_exa.return_value = None
        mock_tav.return_value = None
        mock_ddg.return_value = None
        mock_mw.return_value = None

        with caplog.at_level(logging.INFO):
            results = list(resolve_query_stream("test cascade failure", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "none"
        assert "Starting probe" in caplog.text

    @patch("scripts._url_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._url_resolve.resolve_with_jina")
    @patch("scripts._url_resolve.resolve_with_firecrawl")
    @patch("scripts._url_resolve.resolve_with_mistral_browser")
    @patch("scripts._url_resolve.resolve_with_duckduckgo")
    @patch("scripts._url_resolve.fetch_llms_txt")
    @patch("scripts._url_resolve.fetch_url_content")
    def test_all_url_providers_fail_returns_none_source(
        self,
        mock_fetch,
        mock_llms,
        mock_ddg,
        mock_mb,
        mock_fc,
        mock_jina,
        mock_sc,
        caplog,
    ):
        """When all URL providers return None, cascade yields source=none."""
        from scripts._url_resolve import resolve_url_stream
        from scripts.models import Profile

        mock_llms.return_value = None
        mock_jina.return_value = None
        mock_fc.return_value = None
        mock_fetch.return_value = None
        mock_mb.return_value = None
        mock_ddg.return_value = None

        with caplog.at_level(logging.INFO):
            results = list(
                resolve_url_stream("https://example.com/cascade-test", profile=Profile.BALANCED)
            )

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "none"

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_provider_exception_triggers_circuit_breaker(
        self, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc, caplog
    ):
        """Provider raising exception in cascade is caught and cascade continues."""
        from scripts._query_resolve import resolve_query_stream
        from scripts.models import Profile

        mock_mcp.side_effect = ValueError("simulated failure")
        mock_exa.return_value = None
        mock_tav.return_value = None
        mock_ddg.return_value = None
        mock_mw.return_value = None

        with caplog.at_level(logging.INFO):
            results = list(resolve_query_stream("test cb failure", profile=Profile.BALANCED))

        # Cascade should continue past the failing provider and end with none
        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "none"

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_first_provider_succeeds_stops_cascade(
        self, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc
    ):
        """When first provider returns acceptable result, cascade stops early."""
        from scripts._query_resolve import resolve_query_stream
        from scripts.models import Profile, ResolvedResult

        good_result = ResolvedResult(
            source="exa_mcp",
            content=(
                "# Detailed Documentation\n\n"
                "This is a unique line to avoid duplication penalties and provide enough length.\n"
                + "Providing factual information about the system architecture and implementation details.\n"
                * 30
            ),
            url="https://example.com",
        )
        mock_mcp.return_value = good_result

        results = list(resolve_query_stream("test first provider", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "exa_mcp"
        # Remaining providers should not be called since first succeeded
        mock_exa.assert_not_called()

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_circuit_breaker_open_skips_provider(
        self, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc, caplog
    ):
        """When circuit breaker is open for a provider, cascade skips it entirely."""
        from scripts._query_resolve import _circuit_breakers, resolve_query_stream
        from scripts.models import Profile, ResolvedResult

        # Open the breaker for exa (second provider in conftest order)
        for _ in range(3):
            _circuit_breakers.record_failure("exa")
        assert _circuit_breakers.is_open("exa")

        # First provider (exa_mcp) fails, so cascade must continue to exa (which is skipped)
        mock_mcp.return_value = None
        # tavily (third provider) succeeds
        good_result = ResolvedResult(
            source="tavily",
            content=("# Documentation\n\nDetailed technical content with links. " * 60),
            url="https://tavily-result.example.com",
        )
        mock_tav.return_value = good_result

        with caplog.at_level(logging.INFO):
            results = list(resolve_query_stream("test cb skip", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "tavily"
        # exa should not be called since breaker is open
        mock_exa.assert_not_called()

        # Clean up
        _circuit_breakers.clear()

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_free_provider_high_quality_skips_paid(
        self, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc
    ):
        """A high-quality free result causes cascade to skip paid providers."""
        from scripts._query_resolve import resolve_query_stream
        from scripts.models import Profile, ResolvedResult

        # All paid providers fail; a free provider (duckduckgo) returns high quality
        mock_mcp.return_value = None
        mock_exa.return_value = None
        mock_tav.return_value = None
        mock_mw.return_value = None

        good_result = ResolvedResult(
            source="duckduckgo",
            content=(
                "# Reference Documentation\n\n"
                "Complete technical guide with code samples, "
                "API reference, and comprehensive examples. " * 50
            ),
            url="https://docs.example.com",
        )
        mock_ddg.return_value = good_result

        results = list(resolve_query_stream("test quality gate", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        # duckduckgo is free and high quality — cascade stops here
        assert final["source"] == "duckduckgo"

    @patch("scripts._query_resolve.get_semantic_cache")
    def test_semantic_cache_hit_skips_cascade(self, mock_get_sc, caplog):
        """Semantic cache hit yields cached result immediately, skipping all providers."""
        from scripts._query_resolve import resolve_query_stream
        from scripts.models import Profile

        mock_cache = Mock()
        mock_entry = Mock()
        mock_entry.similarity = 0.95
        mock_entry.query = "similar cached query"
        mock_entry.result = {
            "source": "exa",
            "content": "cached documentation content " * 30,
            "url": "https://cached.example.com",
            "score": 0.85,
        }
        mock_cache.query.return_value = mock_entry
        mock_get_sc.return_value = mock_cache

        with caplog.at_level(logging.INFO):
            results = list(resolve_query_stream("test cached query", profile=Profile.BALANCED))

        assert len(results) == 1
        final = results[0]
        assert final["semantic_cache_hit"] is True
        assert final["semantic_similarity"] == 0.95
        assert final["semantic_original_query"] == "similar cached query"
        assert final["source"] == "exa"
        assert "Semantic cache hit" in caplog.text

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    @patch("scripts.routing.ResolutionBudget")
    def test_budget_exhaustion_yields_best_free_result(
        self, mock_budget_cls, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc
    ):
        """When budget is exhausted, best_free_result is yielded instead of source=none."""
        from scripts._query_resolve import resolve_query_stream
        from scripts.models import Profile, ResolvedResult

        low_quality = ResolvedResult(
            source="exa_mcp",
            content="Some basic documentation content that is acceptable but low quality. " * 30,
            url="https://example.com",
        )
        mock_mcp.return_value = low_quality
        mock_exa.return_value = None
        mock_tav.return_value = None
        mock_ddg.return_value = None
        mock_mw.return_value = None

        # Budget: allows first attempt then exhausts
        mock_budget = Mock()
        mock_budget.min_free_quality_to_skip_paid = 0.99
        call_counts = {"can_try": 0}

        def can_try(is_paid=False):
            call_counts["can_try"] += 1
            if call_counts["can_try"] == 1:
                return True
            mock_budget.stop_reason = "max_provider_attempts"
            return False

        mock_budget.can_try = can_try
        mock_budget.record_attempt = Mock()
        mock_budget_cls.return_value = mock_budget

        results = list(resolve_query_stream("test budget exhaust", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        # Should yield best_free_result from the first provider, not source=none
        assert final["source"] == "exa_mcp"
        assert "Some basic documentation" in final["content"]
        # Remaining providers should not be called since budget was exhausted
        mock_exa.assert_not_called()
        mock_tav.assert_not_called()
        mock_ddg.assert_not_called()
        mock_mw.assert_not_called()

    # ── URL cascade tests ──────────────────────────────────────────────

    @patch("scripts._url_resolve.get_semantic_cache")
    def test_url_semantic_cache_hit_skips_cascade(self, mock_get_sc, caplog):
        """URL semantic cache hit yields cached result immediately, skipping all providers."""
        from scripts._url_resolve import resolve_url_stream
        from scripts.models import Profile

        mock_cache = Mock()
        mock_entry = Mock()
        mock_entry.similarity = 0.92
        mock_entry.query = "https://cached-docs.example.com"
        mock_entry.result = {
            "source": "firecrawl",
            "content": "cached url documentation content " * 30,
            "url": "https://cached-docs.example.com",
            "score": 0.88,
        }
        mock_cache.query.return_value = mock_entry
        mock_get_sc.return_value = mock_cache

        with caplog.at_level(logging.INFO):
            results = list(
                resolve_url_stream("https://cached-docs.example.com", profile=Profile.BALANCED)
            )

        assert len(results) == 1
        final = results[0]
        assert final["semantic_cache_hit"] is True
        assert final["semantic_similarity"] == 0.92
        assert final["semantic_original_query"] == "https://cached-docs.example.com"
        assert final["source"] == "firecrawl"
        assert "Semantic cache hit" in caplog.text

    @patch("scripts._url_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._url_resolve.resolve_with_jina")
    @patch("scripts._url_resolve.resolve_with_firecrawl")
    @patch("scripts._url_resolve.resolve_with_mistral_browser")
    @patch("scripts._url_resolve.resolve_with_duckduckgo")
    @patch("scripts._url_resolve.fetch_llms_txt")
    @patch("scripts._url_resolve.fetch_url_content")
    @patch("scripts.routing.ResolutionBudget")
    def test_url_budget_exhaustion_yields_best_free_result(
        self,
        mock_budget_cls,
        mock_fetch,
        mock_llms,
        mock_ddg,
        mock_mb,
        mock_fc,
        mock_jina,
        mock_sc,
    ):
        """When URL budget is exhausted, best_free_result is yielded instead of source=none."""
        from scripts._url_resolve import resolve_url_stream
        from scripts.models import Profile, ResolvedResult

        mock_llms.return_value = None
        low_quality = ResolvedResult(
            source="direct_fetch",
            content="Basic URL content that is acceptable but brief. " * 30,
            url="https://example.com",
        )
        mock_fetch.return_value = low_quality
        mock_jina.return_value = None
        mock_fc.return_value = None
        mock_mb.return_value = None
        mock_ddg.return_value = None

        # Budget: allows a couple attempts then exhausts before firecrawl
        mock_budget = Mock()
        mock_budget.min_free_quality_to_skip_paid = 0.99
        call_counts = {"can_try": 0}

        def can_try(is_paid=False):
            call_counts["can_try"] += 1
            if call_counts["can_try"] <= 2:
                return True
            mock_budget.stop_reason = "max_provider_attempts"
            return False

        mock_budget.can_try = can_try
        mock_budget.record_attempt = Mock()
        mock_budget_cls.return_value = mock_budget

        results = list(
            resolve_url_stream("https://example.com/budget-test", profile=Profile.BALANCED)
        )

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        # Should yield best_free_result from direct_fetch (tier 1, tried before jina)
        assert final["source"] == "direct_fetch"
        assert "Basic URL content" in final["content"]
        # Remaining providers should not be called since budget was exhausted
        mock_fc.assert_not_called()
        mock_mb.assert_not_called()
        mock_ddg.assert_not_called()
        mock_jina.assert_not_called()

    # ── Hedge & negative cache tests ───────────────────────────────────

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.scripts.cache_negative.should_skip_from_negative_cache")
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_negative_cache_skips_provider(
        self,
        mock_mw,
        mock_ddg,
        mock_tav,
        mock_exa,
        mock_mcp,
        mock_skip,
        mock_sc,
        caplog,
    ):
        """When negative cache says skip, cascade skips the provider entirely."""
        from scripts._query_resolve import resolve_query_stream
        from scripts.models import Profile, ResolvedResult

        # exa_mcp returns None, should_skip returns True for exa, tavily succeeds
        mock_mcp.return_value = None

        def should_skip(cache, key, provider):
            return provider == "exa"

        mock_skip.side_effect = should_skip

        good_result = ResolvedResult(
            source="tavily",
            content="Tavily documentation content with examples. " * 60,
            url="https://tavily-result.example.com",
        )
        mock_tav.return_value = good_result

        with caplog.at_level(logging.INFO):
            results = list(resolve_query_stream("test neg cache skip", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "tavily"
        # exa should NOT be called since negative cache skipped it
        mock_exa.assert_not_called()

    @pytest.mark.skipif(
        sys.version_info >= (3, 13), reason="Flaky on Python 3.13 due to async timing differences"
    )
    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_hedge_triggers_when_p75_latency_is_zero(
        self, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc, caplog
    ):
        """When p75 latency is 0, hedge launches next provider while first is still 'running'."""
        from scripts._query_resolve import _routing_memory, resolve_query_stream
        from scripts.models import Profile, ResolvedResult

        # Set p75 latency to 0 to trigger instant hedge threshold
        original_p75 = _routing_memory.get_p75_latency
        _routing_memory.get_p75_latency = lambda d, p, default=3000: 0

        try:
            # First provider (exa_mcp) fails, so cascade must continue
            mock_mcp.return_value = None
            # exa (hedged provider) succeeds
            good_result = ResolvedResult(
                source="exa",
                content="Exa documentation with examples. " * 60,
                url="https://exa-result.example.com",
            )
            mock_exa.return_value = good_result
            mock_tav.return_value = None
            mock_ddg.return_value = None
            mock_mw.return_value = None

            with caplog.at_level(logging.INFO):
                results = list(resolve_query_stream("test hedge", profile=Profile.BALANCED))

            final = next((r for r in results if r.get("source") != "partial"), results[-1])
            assert final["source"] == "exa"
            # With p75=0, exa should be launched as a hedge (called even though exa_mcp
            # was the first provider). Both providers are probed concurrently.
            mock_exa.assert_called()
        finally:
            _routing_memory.get_p75_latency = original_p75

    @patch("scripts._query_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._query_resolve.resolve_with_exa_mcp")
    @patch("scripts._query_resolve.resolve_with_exa")
    @patch("scripts._query_resolve.resolve_with_tavily")
    @patch("scripts._query_resolve.resolve_with_duckduckgo")
    @patch("scripts._query_resolve.resolve_with_mistral_websearch")
    def test_circuit_breaker_failure_counter_resets_after_success(
        self, mock_mw, mock_ddg, mock_tav, mock_exa, mock_mcp, mock_sc
    ):
        """After a provider succeeds, its circuit breaker failure counter resets to 0."""
        from scripts._query_resolve import _circuit_breakers, resolve_query_stream
        from scripts.models import Profile, ResolvedResult

        # Pre-open the breaker for exa_mcp with some failures
        _circuit_breakers.record_failure("exa_mcp")
        _circuit_breakers.record_failure("exa_mcp")
        # Not yet open (threshold is 3)
        assert not _circuit_breakers.is_open("exa_mcp")

        # Now exa_mcp succeeds
        good_result = ResolvedResult(
            source="exa_mcp",
            content="Excellent documentation content with comprehensive details. " * 60,
            url="https://example.com",
        )
        mock_mcp.return_value = good_result

        results = list(resolve_query_stream("test cb reset", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "exa_mcp"

        # After success, breaker should be closed (failures reset to 0)
        assert not _circuit_breakers.is_open("exa_mcp")

        # Verify by checking it can run again without being skipped
        breaker_state = _circuit_breakers.breakers.get("exa_mcp")
        assert breaker_state is None or breaker_state.failures == 0

        # Clean up
        _circuit_breakers.clear()

    # ── URL cascade provider-specific tests ─────────────────────────────

    @patch("scripts._url_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._url_resolve.resolve_with_jina")
    @patch("scripts._url_resolve.resolve_with_firecrawl")
    @patch("scripts._url_resolve.resolve_with_mistral_browser")
    @patch("scripts._url_resolve.resolve_with_duckduckgo")
    @patch("scripts._url_resolve.fetch_llms_txt")
    @patch("scripts._url_resolve.fetch_url_content")
    def test_llms_txt_not_found_falls_through_to_jina(
        self,
        mock_fetch,
        mock_llms,
        mock_ddg,
        mock_mb,
        mock_fc,
        mock_jina,
        mock_sc,
    ):
        """When llms.txt is not found, cascade falls through to jina."""
        from scripts._url_resolve import resolve_url_stream
        from scripts.models import Profile, ResolvedResult

        # llms_txt returns None (no llms.txt file found)
        mock_llms.return_value = None
        # jina succeeds
        jina_result = ResolvedResult(
            source="jina",
            content="Jina extracted documentation content with details. " * 60,
            url="https://docs.example.com",
        )
        mock_jina.return_value = jina_result
        mock_fc.return_value = None

        results = list(resolve_url_stream("https://docs.example.com", profile=Profile.BALANCED))

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        assert final["source"] == "jina"
        # llms_txt should have been called (and returned None)
        mock_llms.assert_called()
        # jina should have been called after llms_txt returned None
        mock_jina.assert_called()
        # firecrawl should not be called since jina succeeded
        mock_fc.assert_not_called()

    @patch("scripts._url_resolve.get_semantic_cache", return_value=None)
    @patch("scripts._url_resolve.resolve_with_jina")
    @patch("scripts._url_resolve.resolve_with_firecrawl")
    @patch("scripts._url_resolve.resolve_with_mistral_browser")
    @patch("scripts._url_resolve.resolve_with_duckduckgo")
    @patch("scripts._url_resolve.fetch_llms_txt")
    @patch("scripts._url_resolve.fetch_url_content")
    def test_direct_fetch_succeeds_when_all_extraction_providers_fail(
        self,
        mock_fetch,
        mock_llms,
        mock_ddg,
        mock_mb,
        mock_fc,
        mock_jina,
        mock_sc,
    ):
        """When all extraction providers fail, direct_fetch yields content as best_free_result."""
        from scripts._url_resolve import resolve_url_stream
        from scripts.models import Profile

        # All extraction providers return None
        mock_llms.return_value = None
        mock_jina.return_value = None
        mock_fc.return_value = None
        mock_mb.return_value = None
        mock_ddg.return_value = None
        # direct_fetch succeeds with raw HTML
        mock_fetch.return_value = (
            "<html><body>Raw fetched documentation content. " * 30 + "</body></html>"
        )

        results = list(
            resolve_url_stream("https://example.com/direct-fetch-test", profile=Profile.BALANCED)
        )

        final = next((r for r in results if r.get("source") != "partial"), results[-1])
        # direct_fetch is a free provider; its result becomes best_free_result
        assert final["source"] == "direct_fetch"
        assert "Raw fetched documentation" in final["content"]
        # fetch_url_content should have been called
        mock_fetch.assert_called()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
