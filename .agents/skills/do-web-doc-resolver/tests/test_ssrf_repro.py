"""Regression tests for SSRF protections."""

import os
import sys
from unittest.mock import patch

import requests

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from scripts.utils import fetch_llms_txt, fetch_url_content, is_safe_url, validate_url


class TestSSRFGuards:
    """Ensure SSRF protections trigger for malicious redirects."""

    @patch("scripts.utils._safe_request")
    def test_validate_url_blocks_redirect(self, mock_safe_request):
        mock_safe_request.side_effect = requests.RequestException("SSRF blocked")

        result = validate_url("http://public-site.com/redirect")
        assert not result.is_valid

    def test_fetch_llms_txt_blocks_private_url(self):
        assert fetch_llms_txt("http://127.0.0.1/llms.txt") is None

    @patch("scripts.utils._safe_request")
    def test_fetch_url_content_blocks_redirect(self, mock_safe_request):
        mock_safe_request.side_effect = requests.RequestException("SSRF blocked")

        result = fetch_url_content("http://public-site.com/redirect")
        assert result is None

    def test_is_safe_url_blocks_unspecified_ipv6(self):
        """Verify that [::] is blocked by is_safe_url."""
        assert not is_safe_url("http://[::]/")
        assert not is_safe_url("http://[::]:8080/")
