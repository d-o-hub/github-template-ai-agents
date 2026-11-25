from unittest.mock import patch

import pytest

import scripts.providers_impl
import scripts.quality
import scripts.resolve
import scripts.routing
import scripts.routing_memory
import scripts.state
import scripts.synthesis
import scripts.utils


class MemoryCache:
    def __init__(self):
        self.data = {}

    def get(self, key):
        return self.data.get(key)

    def set(self, key, value, expire=None):
        self.data[key] = value

    def clear(self):
        self.data.clear()


@pytest.fixture(autouse=True)
def setup_test_env():
    # Fresh cache for every test to avoid cross-test contamination
    cache = MemoryCache()

    # Apply to all possible locations
    scripts.utils._cache = cache
    if hasattr(scripts.resolve, "_cache"):
        scripts.resolve._cache = cache

    # Mock get_cache to return our memory cache
    with patch("scripts.utils.get_cache", return_value=cache):
        # Reset shared state via state.py singletons
        scripts.state.routing_memory.clear()
        scripts.state.circuit_breakers.clear()
        scripts.providers_impl._clear_rate_limits()

        # Mock synthesis to avoid LLM calls
        original_should_synth = scripts.synthesis.should_call_llm_synthesis
        original_merge = scripts.synthesis.deterministic_merge
        scripts.synthesis.should_call_llm_synthesis = lambda x: False
        scripts.synthesis.deterministic_merge = lambda x: "Merged content"

        # Force deterministic order for tests
        original_plan = scripts.routing.plan_provider_order

        def mock_plan(target, is_url, custom_order=None, skip_providers=None, **kwargs):
            if custom_order:
                base = list(custom_order)
            elif is_url:
                base = [
                    "llms_txt",
                    "jina",
                    "firecrawl",
                    "direct_fetch",
                    "mistral_browser",
                    "duckduckgo",
                ]
            else:
                base = ["exa_mcp", "exa", "tavily", "duckduckgo", "mistral_websearch"]

            skip = skip_providers or set()
            return [p for p in base if p not in skip]

        scripts.routing.plan_provider_order = mock_plan

        yield

        # Restore
        scripts.synthesis.should_call_llm_synthesis = original_should_synth
        scripts.synthesis.deterministic_merge = original_merge
        scripts.routing.plan_provider_order = original_plan
