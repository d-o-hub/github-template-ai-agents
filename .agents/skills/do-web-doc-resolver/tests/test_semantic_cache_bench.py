"""
Performance tests for semantic cache implementation.
"""

import os
import tempfile
import time

import pytest

# Skip all tests if dependencies not available
pytestmark = [
    pytest.mark.skipif(
        os.environ.get("DO_WDR_SEMANTIC_CACHE", "1") == "0",
        reason="Semantic cache disabled via environment",
    ),
]

# Try to import optional dependencies
try:
    import sentence_transformers  # noqa: F401
    import sqlite_vec  # noqa: F401

    DEPS_AVAILABLE = True
except ImportError:
    DEPS_AVAILABLE = False


@pytest.fixture
def temp_cache_dir():
    """Provide a temporary directory for cache tests."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir


@pytest.fixture
def semantic_cache(temp_cache_dir):
    """Create a fresh semantic cache instance for testing."""
    if not DEPS_AVAILABLE:
        pytest.skip("sqlite-vec or sentence-transformers not available")

    # Reset any existing instance
    from scripts.semantic_cache import reset_semantic_cache

    reset_semantic_cache()

    # Create new instance with low threshold for testing
    from scripts.semantic_cache import SemanticCache

    cache = SemanticCache(
        cache_dir=temp_cache_dir,
        threshold=0.7,  # Lower threshold for testing
        max_entries=100,
    )

    if not cache.enabled:
        pytest.skip("Semantic cache could not be enabled")

    yield cache

    cache.close()
    reset_semantic_cache()


@pytest.mark.benchmark
class TestSemanticCachePerformance:
    """Performance tests for semantic cache."""

    def test_semantic_cache_query_latency(self, semantic_cache) -> None:
        """Test that cache query latency is under threshold."""
        # Pre-populate cache
        query = "performance test query"
        result = {"source": "test", "content": "test content"}
        semantic_cache.store(query, result)

        # Force model to load
        semantic_cache.query(query)

        # Measure query latency
        latencies = []
        for _ in range(20):
            start = time.time()
            semantic_cache.query(query)  # Ignore result
            end = time.time()
            latencies.append((end - start) * 1000)  # Convert to ms

        avg_latency = sum(latencies) / len(latencies)
        max_latency = max(latencies)

        # Increased thresholds for CI environments
        # Should be under 200ms on average
        assert avg_latency < 200, f"Average query latency {avg_latency:.2f}ms exceeds 200ms"
        # Max should be reasonable too
        assert max_latency < 500, f"Max query latency {max_latency:.2f}ms exceeds 500ms"

    def test_semantic_cache_hit_rate(self, semantic_cache) -> None:
        """Test cache hit rate for similar queries."""
        # Store base query
        base_query = "python dictionary methods get setdefault"
        result = {
            "source": "test",
            "content": "Python dict has methods like get(), setdefault(), update()",
        }
        semantic_cache.store(base_query, result)

        # Test similar queries
        similar_queries = [
            "python dict get method",
            "setdefault python dictionary",
            "how to use dict methods in python",
            "python dictionary get vs setdefault",
        ]

        hits = 0
        for q in similar_queries:
            entry = semantic_cache.query(q)
            if entry is not None:
                hits += 1

        hit_rate = hits / len(similar_queries)
        # Should achieve >30% hit rate for similar queries
        assert hit_rate >= 0.30, f"Hit rate {hit_rate * 100:.1f}% below 30% threshold"
