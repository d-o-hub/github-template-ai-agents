"""
Shared ThreadPoolExecutor for the Web Doc Resolver.

Provides a single thread pool for all async-to-sync conversions,
reducing thread creation overhead and improving performance.
"""

import concurrent.futures
import threading

# Shared thread pool for async-to-sync conversions
_shared_pool: concurrent.futures.ThreadPoolExecutor | None = None
_pool_lock = threading.Lock()


def get_shared_pool(max_workers: int = 10) -> concurrent.futures.ThreadPoolExecutor:
    """Get or create the shared ThreadPoolExecutor."""
    global _shared_pool
    with _pool_lock:
        if _shared_pool is None or _shared_pool._shutdown:
            _shared_pool = concurrent.futures.ThreadPoolExecutor(
                max_workers=max_workers,
                thread_name_prefix="wdr-worker",
            )
    return _shared_pool


def shutdown_shared_pool() -> None:
    """Shutdown the shared ThreadPoolExecutor."""
    global _shared_pool
    with _pool_lock:
        if _shared_pool is not None:
            _shared_pool.shutdown(wait=False)
            _shared_pool = None
