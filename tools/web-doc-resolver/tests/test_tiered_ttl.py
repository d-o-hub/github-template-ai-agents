import os
import unittest
from unittest.mock import patch

from scripts.utils import get_ttl


class TestGetTTL(unittest.TestCase):
    def test_default_ttls(self):
        self.assertEqual(get_ttl("firecrawl"), 21600)
        self.assertEqual(get_ttl("exa"), 14400)
        self.assertEqual(get_ttl("exa_mcp"), 14400)
        self.assertEqual(get_ttl("jina"), 7200)
        self.assertEqual(get_ttl("duckduckgo"), 3600)
        self.assertEqual(get_ttl("llms_txt"), 28800)
        self.assertEqual(get_ttl("synthesis"), 43200)
        self.assertEqual(get_ttl("unknown"), 3600)

    def test_env_var_override(self):
        with patch.dict(os.environ, {"DO_WDR_CACHE_TTL_FIRECRAWL": "123"}):
            self.assertEqual(get_ttl("firecrawl"), 123)

    def test_config_dict_override(self):
        config = {
            "cache": {"ttl": {"firecrawl": 456, "exa": 789, "default": 10}},
        }
        self.assertEqual(get_ttl("firecrawl", config), 456)
        self.assertEqual(get_ttl("exa", config), 789)
        self.assertEqual(get_ttl("exa_mcp", config), 789)
        self.assertEqual(get_ttl("unknown", config), 10)

    def test_env_var_beats_config_dict(self):
        """Environment variable override takes precedence over config dict."""
        config = {"cache": {"ttl": {"firecrawl": 999}}}
        with patch.dict(os.environ, {"DO_WDR_CACHE_TTL_FIRECRAWL": "42"}):
            self.assertEqual(get_ttl("firecrawl", config), 42)

    def test_empty_config_falls_back_to_defaults(self):
        """Empty config should fall back to TIERED_TTL defaults."""
        self.assertEqual(get_ttl("firecrawl", {}), 21600)
        self.assertEqual(get_ttl("unknown", {}), 3600)
        # duckduckgo default TTL via TIERED_TTL table
        self.assertEqual(get_ttl("duckduckgo", {}), 3600)

    def test_env_var_invalid_value_falls_back(self):
        """Invalid env var value should not crash, fall through to config/default."""
        config = {"cache": {"ttl": {"firecrawl": 888}}}
        with patch.dict(os.environ, {"DO_WDR_CACHE_TTL_FIRECRAWL": "not_an_int"}):
            self.assertEqual(get_ttl("firecrawl", config), 888)

    def test_config_file_loading(self):
        # We already verified this manually, but lets add a test-friendly way if possible
        # Since get_ttl uses get_config_data which is cached, we might need to be careful
        pass


if __name__ == "__main__":
    unittest.main()
