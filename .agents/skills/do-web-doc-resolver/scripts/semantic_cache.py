"""
Semantic Cache implementation using sqlite-vec + sentence-transformers.

Provides semantic caching for resolved queries and URLs using local embeddings.
The all-MiniLM-L6-v2 model is used (small, ~80MB, fast) and runs entirely locally.
"""

import json
import logging
import os
import struct
import time
from dataclasses import dataclass, field
from typing import Any, cast

try:
    from pysqlite3 import dbapi2 as sqlite3
except ImportError:
    import sqlite3

logger = logging.getLogger(__name__)

# Default configuration
DEFAULT_MODEL = "all-MiniLM-L6-v2"
DEFAULT_THRESHOLD = 0.85
DEFAULT_MAX_ENTRIES = 10000


@dataclass
class SemanticCacheEntry:
    """A single semantic cache entry."""

    query: str
    result: dict[str, Any]
    timestamp: float = field(default_factory=time.time)
    similarity: float = 0.0

    def to_dict(self) -> dict[str, Any]:
        """Convert entry to dictionary."""
        return {
            "query": self.query,
            "result": self.result,
            "timestamp": self.timestamp,
            "similarity": self.similarity,
        }


class SemanticCache:
    """
    Semantic cache using sqlite-vec for vector similarity search.

    Uses sentence-transformers for local embeddings (all-MiniLM-L6-v2 model).
    Falls back gracefully if sqlite-vec or embeddings fail to load.

    Attributes:
        cache_dir: Directory for cache storage
        threshold: Minimum similarity score for cache hits (0.0-1.0)
        max_entries: Maximum number of entries to store
        enabled: Whether the cache is operational
    """

    def __init__(
        self,
        cache_dir: str | None = None,
        threshold: float = DEFAULT_THRESHOLD,
        max_entries: int = DEFAULT_MAX_ENTRIES,
        model_name: str = DEFAULT_MODEL,
    ) -> None:
        """
        Initialize semantic cache.

        Args:
            cache_dir: Directory for cache storage. Defaults to ~/.cache/do-web-doc-resolver/semantic
            threshold: Minimum cosine similarity for cache hits (0.0-1.0)
            max_entries: Maximum number of entries before LRU eviction
            model_name: Sentence-transformers model to use
        """
        self.enabled = False
        self._model: Any = None
        self._model_name = model_name
        self.threshold = threshold
        self.max_entries = max_entries
        self._embedding_dimension: int | None = None

        # Set up cache directory
        if cache_dir is None:
            cache_dir = os.path.expanduser(
                os.getenv(
                    "WEB_RESOLVER_SEMANTIC_CACHE_DIR", "~/.cache/do-web-doc-resolver/semantic"
                )
            )
        self.cache_dir = cache_dir
        os.makedirs(self.cache_dir, exist_ok=True)

        self.db_path = os.path.join(self.cache_dir, "semantic_cache.db")

        # Try to initialize - failures disable the cache gracefully
        try:
            self._init_db()
            self._init_model()
            self.enabled = True
            logger.info("Semantic cache initialized at %s", self.db_path)
        except Exception as e:
            logger.warning("Semantic cache initialization failed: %s. Cache disabled.", e)
            self.enabled = False

    def _init_db(self) -> None:
        """Initialize sqlite-vec extension and database schema."""
        self._conn = sqlite3.connect(self.db_path)
        self._conn.row_factory = sqlite3.Row

        # Try to load sqlite-vec extension
        vec_loaded = False
        try:
            import sqlite_vec

            self._conn.enable_load_extension(True)
            sqlite_vec.load(self._conn)
            self._conn.enable_load_extension(False)
            vec_loaded = True
            logger.debug("sqlite-vec extension loaded successfully")
        except ImportError:
            logger.warning("sqlite-vec not installed, trying dynamic loading")
        except Exception as e:
            logger.warning("Failed to load sqlite-vec via Python API: %s", e)

        if not vec_loaded:
            # Try loading as dynamic library
            try:
                self._conn.enable_load_extension(True)
                # Try common paths
                lib_paths = [
                    "libsqlite_vec.so",
                    "libsqlite_vec.dylib",
                    "sqlite_vec.so",
                    "sqlite_vec.dylib",
                    "libsqlite_vec",
                ]
                for lib in lib_paths:
                    try:
                        self._conn.execute(f"SELECT load_extension('{lib}')")
                        vec_loaded = True
                        logger.debug("Loaded sqlite-vec from %s", lib)
                        break
                    except sqlite3.OperationalError:
                        continue
                self._conn.enable_load_extension(False)
            except Exception as e:
                logger.warning("Failed to load sqlite-vec dynamically: %s", e)

        if not vec_loaded:
            raise RuntimeError("sqlite-vec extension could not be loaded")

        # Create tables
        self._conn.execute("""
            CREATE TABLE IF NOT EXISTS cache_entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                query TEXT UNIQUE NOT NULL,
                result_json TEXT NOT NULL,
                timestamp REAL NOT NULL,
                access_count INTEGER DEFAULT 1,
                last_accessed REAL NOT NULL
            )
        """)

        # Virtual table for vector search - will be created after we know embedding dim
        self._conn.commit()

    def _init_model(self) -> None:
        """Initialize sentence-transformers model (lazy loading)."""
        # Don't load model yet - do it on first use
        self._model = None
        self._model_loading = False

    def _load_model(self) -> Any:
        """Load the embedding model if not already loaded."""
        if self._model is None and not self._model_loading:
            self._model_loading = True
            try:
                from sentence_transformers import SentenceTransformer

                logger.info("Loading sentence-transformers model: %s", self._model_name)
                self._model = SentenceTransformer(self._model_name)
                self._embedding_dimension = self._model.get_embedding_dimension()
                logger.info("Model loaded. Embedding dimension: %s", self._embedding_dimension)

                # Create vector table now that we know the dimension
                self._create_vector_table()
            except Exception as e:
                logger.error("Failed to load embedding model: %s", e)
                raise
            finally:
                self._model_loading = False
        return self._model

    def _create_vector_table(self) -> None:
        """Create the virtual vector table for similarity search."""
        if self._embedding_dimension is None:
            return

        # Create virtual table with float32 embeddings
        # We use the implicit rowid to link to cache_entries.id
        self._conn.execute(f"""
            CREATE VIRTUAL TABLE IF NOT EXISTS vec_cache USING vec0(
                embedding float[{self._embedding_dimension}]
            )
        """)
        self._conn.commit()

    def _embedding_to_blob(self, embedding: list[float]) -> bytes:
        """Convert list of floats to binary blob for sqlite-vec."""
        # Pack as little-endian float32 (4 bytes per float)
        return struct.pack(f"<{len(embedding)}f", *embedding)

    def _compute_embedding(self, text: str) -> list[float]:
        """
        Compute embedding for text using sentence-transformers.

        Args:
            text: Input text to embed

        Returns:
            List of float values representing the embedding vector
        """
        model = self._load_model()
        if model is None:
            raise RuntimeError("Embedding model not available")

        embedding = model.encode(text, convert_to_numpy=True, normalize_embeddings=True)
        return cast(list[float], embedding.tolist())

    def query(self, query_str: str) -> SemanticCacheEntry | None:
        """
        Query the semantic cache for similar entries.

        Args:
            query_str: Query string to search for

        Returns:
            SemanticCacheEntry if similar entry found above threshold, None otherwise
        """
        if not self.enabled:
            return None

        try:
            # Compute query embedding
            query_embedding = self._compute_embedding(query_str)
            embedding_blob = self._embedding_to_blob(query_embedding)

            # Search for similar vectors using cosine similarity
            # sqlite-vec returns distance (1 - similarity for cosine)
            cursor = self._conn.execute(
                """
                SELECT ce.id, ce.query, ce.result_json, ce.timestamp, vc.distance
                FROM vec_cache vc
                JOIN cache_entries ce ON ce.id = vc.rowid
                WHERE embedding MATCH ?
                AND k = 1
            """,
                (embedding_blob,),
            )

            row = cursor.fetchone()
            if row is None:
                return None

            # Convert distance to similarity
            # Since we use normalized embeddings, sqlite-vec uses L2 distance by default
            # cosine_similarity = 1 - (L2_distance^2 / 2)
            distance = row["distance"]
            if distance is None:
                distance = (
                    2.0  # Max L2 distance for normalized vectors is sqrt(2^2) = 2.0? No, it's 2.
                )

            similarity = 1.0 - (distance * distance / 2.0)

            if similarity < self.threshold:
                return None

            # Update access stats
            self._conn.execute(
                """
                UPDATE cache_entries
                SET access_count = access_count + 1, last_accessed = ?
                WHERE id = ?
            """,
                (time.time(), row["id"]),
            )
            self._conn.commit()

            result = json.loads(row["result_json"])

            return SemanticCacheEntry(
                query=row["query"],
                result=result,
                timestamp=row["timestamp"],
                similarity=similarity,
            )

        except Exception as e:
            logger.warning("Semantic cache query failed: %s", e)
            return None

    def store(self, query_str: str, result: dict[str, Any]) -> bool:
        """
        Store a result in the semantic cache.

        Args:
            query_str: Original query string
            result: Result dictionary to cache

        Returns:
            True if stored successfully, False otherwise
        """
        if not self.enabled:
            return False

        try:
            # Compute embedding
            embedding = self._compute_embedding(query_str)
            embedding_blob = self._embedding_to_blob(embedding)

            # Check for existing entry and delete if present
            # Virtual tables (vec0) don't support REPLACE well, so we delete manually
            cursor = self._conn.execute(
                "SELECT id FROM cache_entries WHERE query = ?",
                (query_str,),
            )
            old_row = cursor.fetchone()
            if old_row:
                old_id = old_row["id"]
                self._conn.execute("DELETE FROM vec_cache WHERE rowid = ?", (old_id,))
                self._conn.execute("DELETE FROM cache_entries WHERE id = ?", (old_id,))

            # Insert into main table
            cursor = self._conn.execute(
                """
                INSERT INTO cache_entries
                (query, result_json, timestamp, last_accessed)
                VALUES (?, ?, ?, ?)
            """,
                (query_str, json.dumps(result), time.time(), time.time()),
            )
            entry_id = cursor.lastrowid

            # Insert into vector table using the same ID as rowid
            self._conn.execute(
                """
                INSERT INTO vec_cache (rowid, embedding)
                VALUES (?, ?)
            """,
                (entry_id, embedding_blob),
            )

            self._conn.commit()

            # Evict old entries if over limit
            self._maybe_evict()

            return True

        except Exception as e:
            logger.warning("Failed to store in semantic cache: %s", e)
            return False

    def _maybe_evict(self) -> None:
        """Evict oldest entries if cache exceeds max_entries limit."""
        try:
            # Count entries
            cursor = self._conn.execute("SELECT COUNT(*) as count FROM cache_entries")
            count = cursor.fetchone()["count"]

            if count > self.max_entries:
                # Delete oldest entries (by last_accessed)
                to_delete = count - self.max_entries
                cursor = self._conn.execute(
                    """
                    SELECT id FROM cache_entries
                    ORDER BY last_accessed ASC, access_count ASC
                    LIMIT ?
                """,
                    (to_delete,),
                )
                ids_to_delete = [row["id"] for row in cursor.fetchall()]

                for entry_id in ids_to_delete:
                    self._conn.execute("DELETE FROM vec_cache WHERE rowid = ?", (entry_id,))
                    self._conn.execute("DELETE FROM cache_entries WHERE id = ?", (entry_id,))

                self._conn.commit()
                logger.info("Evicted %d old semantic cache entries", len(ids_to_delete))

        except Exception as e:
            logger.warning("Cache eviction failed: %s", e)

    def close(self) -> None:
        """Close database connection."""
        if hasattr(self, "_conn") and self._conn:
            self._conn.close()
            self._conn = None

    def clear(self) -> bool:
        """
        Clear all cached entries.

        Returns:
            True if cleared successfully, False otherwise
        """
        if not self.enabled:
            return False

        try:
            self._conn.execute("DELETE FROM vec_cache")
            self._conn.execute("DELETE FROM cache_entries")
            self._conn.commit()
            logger.info("Semantic cache cleared")
            return True
        except Exception as e:
            logger.warning("Failed to clear semantic cache: %s", e)
            return False

    def stats(self) -> dict[str, Any]:
        """
        Get cache statistics.

        Returns:
            Dictionary with cache statistics
        """
        if not self.enabled:
            return {"enabled": False}

        try:
            cursor = self._conn.execute("SELECT COUNT(*) as count FROM cache_entries")
            total_entries = cursor.fetchone()["count"]

            cursor = self._conn.execute("SELECT AVG(access_count) as avg_access FROM cache_entries")
            avg_access = cursor.fetchone()["avg_access"] or 0

            return {
                "enabled": True,
                "total_entries": total_entries,
                "max_entries": self.max_entries,
                "threshold": self.threshold,
                "model": self._model_name,
                "embedding_dimension": self._embedding_dimension,
                "avg_access_count": round(avg_access, 2),
                "db_path": self.db_path,
            }
        except Exception as e:
            logger.warning("Failed to get cache stats: %s", e)
            return {"enabled": True, "error": str(e)}

    def __enter__(self) -> "SemanticCache":
        """Context manager entry."""
        return self

    def __exit__(self, exc_type: Any, exc_val: Any, exc_tb: Any) -> None:
        """Context manager exit."""
        self.close()


# Global singleton instance
_semantic_cache_instance: SemanticCache | None = None


def get_semantic_cache() -> SemanticCache | None:
    """
    Get or create the global semantic cache instance.

    Returns:
        SemanticCache instance if enabled and initialized, None otherwise
    """
    global _semantic_cache_instance

    if _semantic_cache_instance is None:
        # Check if enabled via environment
        enabled = os.environ.get("DO_WDR_SEMANTIC_CACHE", "1") == "1"
        if not enabled:
            logger.debug("Semantic cache disabled via DO_WDR_SEMANTIC_CACHE=0")
            return None

        try:
            threshold = float(os.environ.get("DO_WDR_CACHE_THRESHOLD", "0.85"))
            max_entries = int(os.environ.get("DO_WDR_CACHE_MAX_ENTRIES", "10000"))
            _semantic_cache_instance = SemanticCache(threshold=threshold, max_entries=max_entries)
            if not _semantic_cache_instance.enabled:
                return None
        except Exception as e:
            logger.warning("Failed to initialize semantic cache: %s", e)
            return None

    return _semantic_cache_instance if _semantic_cache_instance.enabled else None


def reset_semantic_cache() -> None:
    """Reset the global semantic cache instance (mainly for testing)."""
    global _semantic_cache_instance
    if _semantic_cache_instance:
        _semantic_cache_instance.close()
    _semantic_cache_instance = None
