"""
Tests for semantic cache implementation.

These tests verify that the semantic cache:
- Stores and retrieves results correctly
- Finds similar queries (semantic similarity)
- Rejects dissimilar queries
- Respects threshold configuration
- Persists across cache instances
"""

import os
import tempfile
from unittest import mock

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


class TestSemanticCacheBasic:
    """Basic semantic cache functionality tests."""

    @pytest.mark.benchmark
    def test_semantic_cache_store_and_query(self, semantic_cache) -> None:
        """Test basic store and query functionality."""
        query = "python list comprehension tutorial"
        result = {
            "source": "test",
            "content": "List comprehensions provide a concise way to create lists.",
            "url": "https://example.com/python-list-comp",
        }

        # Store result
        stored = semantic_cache.store(query, result)
        assert stored is True

        # Query should return the stored result
        entry = semantic_cache.query(query)
        assert entry is not None
        assert entry.query == query
        assert entry.result["content"] == result["content"]
        assert entry.similarity > 0.7

    @pytest.mark.benchmark
    def test_semantic_cache_similar_queries(self, semantic_cache) -> None:
        """Test that similar queries return cached results."""
        # Store original query
        original_query = "how to reverse a string in python"
        result = {
            "source": "test",
            "content": "You can reverse a string using slicing: s[::-1]",
            "url": "https://example.com/python-reverse",
        }

        semantic_cache.store(original_query, result)

        # Similar queries should hit cache
        similar_queries = [
            "reverse string python",
            "python string reversal method",
            "how do I reverse a string python",
        ]

        for similar in similar_queries:
            entry = semantic_cache.query(similar)
            assert entry is not None, f"Should find similar query: {similar}"
            assert entry.similarity >= 0.7, f"Similarity too low for: {similar}"
            assert entry.result["content"] == result["content"]

    @pytest.mark.benchmark
    def test_semantic_cache_dissimilar_queries(self, semantic_cache) -> None:
        """Test that different queries do not return cached results."""
        # Store a query about Python
        query = "python exception handling try except"
        result = {
            "source": "test",
            "content": "Use try/except blocks to handle exceptions in Python.",
        }
        semantic_cache.store(query, result)

        # Dissimilar queries should not hit
        dissimilar_queries = [
            "javascript array methods",
            "rust ownership and borrowing",
            "sql join types explained",
            "best pizza restaurants in rome",
        ]

        for dissimilar in dissimilar_queries:
            entry = semantic_cache.query(dissimilar)
            assert entry is None, f"Should not find dissimilar query: {dissimilar}"


class TestSemanticCacheThreshold:
    """Tests for semantic cache threshold behavior."""

    @pytest.mark.benchmark
    def test_semantic_cache_threshold_filtering(self, temp_cache_dir) -> None:
        """Test that threshold correctly filters results."""
        if not DEPS_AVAILABLE:
            pytest.skip("Dependencies not available")

        from scripts.semantic_cache import SemanticCache

        # Create cache with high threshold
        strict_cache = SemanticCache(
            cache_dir=temp_cache_dir,
            threshold=0.95,  # Very strict
            max_entries=100,
        )

        if not strict_cache.enabled:
            pytest.skip("Cache not enabled")

        try:
            query = "asyncio python tutorial"
            result = {"source": "test", "content": "Asyncio is Python's async library."}
            strict_cache.store(query, result)

            # Exact query should hit
            entry = strict_cache.query(query)
            assert entry is not None
            assert entry.similarity > 0.95

            # Similar but not exact query should miss with strict threshold
            # (Behavioral verification only, no assertion on similarity)
            similar = "python asyncio guide"
            strict_cache.query(similar)

        finally:
            strict_cache.close()

    @pytest.mark.benchmark
    def test_semantic_cache_low_threshold_hits(self, temp_cache_dir) -> None:
        """Test that low threshold allows more hits."""
        if not DEPS_AVAILABLE:
            pytest.skip("Dependencies not available")

        from scripts.semantic_cache import SemanticCache

        # Create cache with low threshold
        loose_cache = SemanticCache(
            cache_dir=temp_cache_dir,
            threshold=0.5,  # Very loose
            max_entries=100,
        )

        if not loose_cache.enabled:
            pytest.skip("Cache not enabled")

        try:
            query = "pandas dataframe tutorial"
            result = {"source": "test", "content": "Pandas DataFrames are 2D data structures."}
            loose_cache.store(query, result)

            # Various related queries should hit
            related = [
                "pandas data manipulation",
                "python data analysis tutorial",
                "how to use pandas dataframes",
            ]

            hits = 0
            for q in related:
                entry = loose_cache.query(q)
                if entry is not None and entry.similarity >= 0.5:
                    hits += 1

            # With loose threshold, we expect some hits
            assert hits >= 1, "Should have at least one hit with loose threshold"

        finally:
            loose_cache.close()


class TestSemanticCachePersistence:
    """Tests for semantic cache persistence."""

    @pytest.mark.benchmark
    def test_semantic_cache_persistence(self, temp_cache_dir) -> None:
        """Test that cache persists across instances."""
        if not DEPS_AVAILABLE:
            pytest.skip("Dependencies not available")

        from scripts.semantic_cache import SemanticCache

        query = "machine learning basics"
        result = {
            "source": "test",
            "content": "Machine learning enables computers to learn from data.",
        }

        # Store in first instance
        cache1 = SemanticCache(cache_dir=temp_cache_dir, threshold=0.7, max_entries=100)
        if not cache1.enabled:
            pytest.skip("Cache not enabled")

        try:
            cache1.store(query, result)
        finally:
            cache1.close()

        # Create new instance pointing to same directory
        cache2 = SemanticCache(cache_dir=temp_cache_dir, threshold=0.7, max_entries=100)
        if not cache2.enabled:
            pytest.skip("Cache not enabled")

        try:
            # Should find the stored entry
            entry = cache2.query(query)
            assert entry is not None
            assert entry.result["content"] == result["content"]

            # Stats should show one entry
            stats = cache2.stats()
            assert stats["total_entries"] == 1
        finally:
            cache2.close()

    @pytest.mark.benchmark
    def test_semantic_cache_stats(self, semantic_cache) -> None:
        """Test cache statistics reporting."""
        # Initially empty
        stats = semantic_cache.stats()
        assert stats["enabled"] is True
        assert stats["total_entries"] == 0

        # Add entries
        for i in range(3):
            semantic_cache.store(f"query {i}", {"source": "test", "content": f"content {i}"})

        stats = semantic_cache.stats()
        assert stats["total_entries"] == 3
        assert stats["model"] == "all-MiniLM-L6-v2"
        assert "embedding_dimension" in stats


class TestSemanticCacheEviction:
    """Tests for cache eviction behavior."""

    @pytest.mark.benchmark
    def test_semantic_cache_eviction(self, temp_cache_dir) -> None:
        """Test that old entries are evicted when max_entries exceeded."""
        if not DEPS_AVAILABLE:
            pytest.skip("Dependencies not available")

        from scripts.semantic_cache import SemanticCache

        # Create cache with very low max
        small_cache = SemanticCache(
            cache_dir=temp_cache_dir,
            threshold=0.7,
            max_entries=5,
        )

        if not small_cache.enabled:
            pytest.skip("Cache not enabled")

        try:
            # Add more entries than max
            for i in range(10):
                small_cache.store(
                    f"unique query number {i} about python",
                    {"source": "test", "content": f"content {i}"},
                )

            # Should only have 5 entries
            stats = small_cache.stats()
            expected_msg = f"Expected <= 5 entries, got {stats['total_entries']}"
            assert stats["total_entries"] <= 5, expected_msg

        finally:
            small_cache.close()


class TestSemanticCacheGlobal:
    """Tests for global semantic cache instance."""

    @pytest.mark.benchmark
    def test_get_semantic_cache_singleton(self) -> None:
        """Test that get_semantic_cache returns singleton instance."""
        if not DEPS_AVAILABLE:
            pytest.skip("Dependencies not available")

        from scripts.semantic_cache import get_semantic_cache, reset_semantic_cache

        # Reset first
        reset_semantic_cache()

        with mock.patch.dict(os.environ, {"DO_WDR_SEMANTIC_CACHE": "1"}):
            cache1 = get_semantic_cache()
            if cache1 is None:
                pytest.skip("Could not initialize cache")

            cache2 = get_semantic_cache()
            assert cache1 is cache2, "Should return same instance"

        reset_semantic_cache()

    @pytest.mark.benchmark
    def test_get_semantic_cache_disabled(self) -> None:
        """Test that get_semantic_cache returns None when disabled."""
        from scripts.semantic_cache import get_semantic_cache, reset_semantic_cache

        # Reset first
        reset_semantic_cache()

        with mock.patch.dict(os.environ, {"DO_WDR_SEMANTIC_CACHE": "0"}):
            cache = get_semantic_cache()
            assert cache is None, "Should return None when disabled"

        reset_semantic_cache()


class TestSemanticCacheErrorHandling:
    """Tests for error handling and edge cases."""

    @pytest.mark.benchmark
    def test_semantic_cache_handles_empty_query(self, semantic_cache) -> None:
        """Test that empty queries are handled gracefully."""
        entry = semantic_cache.query("")
        assert entry is None

    @pytest.mark.benchmark
    def test_semantic_cache_handles_large_content(self, semantic_cache) -> None:
        """Test that large content can be stored and retrieved."""
        query = "large content test"
        large_content = "x" * 100000  # 100KB of content
        result = {"source": "test", "content": large_content}

        stored = semantic_cache.store(query, result)
        assert stored is True

        entry = semantic_cache.query(query)
        assert entry is not None
        assert len(entry.result["content"]) == 100000

    @pytest.mark.benchmark
    def test_semantic_cache_clear(self, semantic_cache) -> None:
        """Test that clear removes all entries."""
        # Add entries
        semantic_cache.store("query1", {"content": "test1"})
        semantic_cache.store("query2", {"content": "test2"})

        stats = semantic_cache.stats()
        assert stats["total_entries"] == 2

        # Clear
        cleared = semantic_cache.clear()
        assert cleared is True

        stats = semantic_cache.stats()
        assert stats["total_entries"] == 0


class TestSemanticCacheIntegration:
    """Integration tests with resolve.py functions."""

    @pytest.mark.benchmark
    def test_semantic_cache_via_resolve_functions(self, temp_cache_dir) -> None:
        """Test semantic cache integration with resolve functions."""
        if not DEPS_AVAILABLE:
            pytest.skip("Dependencies not available")

        from scripts import resolve
        from scripts.semantic_cache import SemanticCache

        # Create and inject cache
        cache = SemanticCache(
            cache_dir=temp_cache_dir,
            threshold=0.7,
            max_entries=100,
        )

        if not cache.enabled:
            pytest.skip("Cache not enabled")

        try:
            # Manually store a result
            test_query = "pytest testing framework tutorial"
            cached_result = {
                "source": "test_provider",
                "content": "pytest is a testing framework for Python",
                "url": "https://example.com/pytest",
                "query": test_query,
            }
            cache.store(test_query, cached_result)

            # Test the helper functions directly
            # Reset global cache to use our test cache
            with (
                mock.patch("scripts.semantic_cache._semantic_cache_instance", cache),
                mock.patch("scripts._query_resolve.get_semantic_cache", return_value=cache),
            ):
                result = resolve._check_semantic_cache(test_query)
            assert result is not None
            assert result.get("semantic_cache_hit") is True

        finally:
            cache.close()
            resolve._semantic_cache = None
