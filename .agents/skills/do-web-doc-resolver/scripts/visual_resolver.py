"""Visual resolver stub for CLIP-based content extraction."""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger(__name__)


@dataclass
class VisualResult:
    """Result from visual resolution."""

    content: str | None = None
    score: float = 0.0
    metadata: dict[str, Any] = field(default_factory=dict)


class VisualResolver:
    """Visual content resolver using CLIP/VLM models.

    Stub implementation — requires MISTRAL_API_KEY or OPENROUTER_API_KEY
    and the sentence-transformers package to function.
    """

    def __init__(self) -> None:
        self._available: bool | None = None

    def is_available(self) -> bool:
        """Check if dependencies and API keys are present."""
        if self._available is not None:
            return self._available

        try:
            import os

            has_key = bool(
                os.getenv("MISTRAL_API_KEY") or os.getenv("OPENROUTER_API_KEY")
            )
            if not has_key:
                self._available = False
                return False

            # sentence-transformers is optional
            import sentence_transformers  # noqa: F401

            self._available = True
        except ImportError:
            self._available = False

        return self._available

    def resolve(self, url: str, query: str) -> VisualResult | None:
        """Resolve URL content synchronously (stub)."""
        logger.debug("VisualResolver.resolve called for %s (stub)", url)
        return None

    async def resolve_async(self, url: str, query: str) -> VisualResult | None:
        """Resolve URL content asynchronously (stub)."""
        logger.debug("VisualResolver.resolve_async called for %s (stub)", url)
        return None
