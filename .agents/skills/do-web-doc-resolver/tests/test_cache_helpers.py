"""Regression tests for cache/utils helper definitions.

Defends against duplicate helper definitions introduced when multiple PRs from
the same author/session are squash-merged and both add the same helper. See
PR cleanup run 2026-07-28 / issue #740.
"""

import ast
import pathlib

import pytest


@pytest.mark.unit
class TestNoDuplicateHelpers:
    """Ensure cache helpers are defined exactly once after merges."""

    def test_l1_clear_defined_once(self):
        """Issue #740: two _l1_clear definitions coexisted on main.

        Uses AST (not inspect.getsource) to be robust against false positives
        from comments, docstrings, or string literals containing the substring
        ``def _l1_clear(``.
        """
        from scripts.utils import cache

        src = pathlib.Path(cache.__file__).read_text()
        tree = ast.parse(src)
        module_level_defs = [
            n.name
            for n in tree.body
            if isinstance(n, ast.FunctionDef) and n.name == "_l1_clear"
        ]
        assert len(module_level_defs) == 1, (
            "Duplicate _l1_clear helper detected in scripts/utils/cache.py. "
            "This regression appeared when two PRs from the same session "
            "added the helper and both squash-merged; see plans/GOAP_STATE.md "
            "(run 2026-07-28)."
        )

    def test_l1_clear_export_once_in_utils_all(self):
        """Issue #740: duplicates in scripts/utils/__init__.py __all__."""
        from scripts.utils import __all__ as utils_all

        assert utils_all.count("_l1_clear") == 1, (
            "Duplicate '_l1_clear' string in scripts.utils.__all__."
        )


@pytest.mark.unit
class TestL1ClearBehavior:
    """Verify the kept _l1_clear semantics (no .clear(), lock held)."""

    def test_l1_clear_resets_to_none(self):
        """The kept variant sets _cache = None (not calls .clear())."""
        from scripts.utils import cache

        original = cache._cache
        try:
            cache._l1_cache['test'] = object()
            cache._l1_clear()
            assert len(cache._l1_cache) == 0, "_l1_clear must clear _l1_cache"
        finally:
            cache._cache = original

    def test_l1_clear_traverses_cache_lock_global(self):
        """Verify _l1_clear references _cache_lock (no plain assignment path).

        Mocks ``_cache_lock`` with a sentinel context manager. The sentinel's
        ``__enter__`` records the call. If a future refactor drops the
        ``with _cache_lock:`` guard, this test fails.
        """
        from scripts.utils import cache

        entered = []

        class _SentinelLock:
            def __enter__(inner):
                entered.append(True)
                return inner

            def __exit__(inner, *exc):
                return False

        original_lock = cache._l1_cache_lock
        original_cache = cache._cache
        try:
            cache._l1_cache_lock = _SentinelLock()
            cache._l1_cache['test'] = object()
            cache._l1_clear()
            assert entered == [True], (
                "_l1_clear must enter _l1_cache_lock as a context manager"
            )
            assert cache._cache is None
        finally:
            cache._l1_cache_lock = original_lock
            cache._cache = original_cache
