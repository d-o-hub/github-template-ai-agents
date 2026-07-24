"""Visual resolver using Playwright + CLIP for content extraction."""

from __future__ import annotations

import asyncio
import base64
import io
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
    """Visual content resolver using Playwright + CLIP models.

    Requires:
    - MISTRAL_API_KEY or OPENROUTER_API_KEY for VLM fallback
    - playwright package (pip install playwright && playwright install chromium)
    - sentence-transformers + Pillow + numpy for CLIP-based similarity
    """

    def __init__(self) -> None:
        self._available: bool | None = None
        self._clip_model: Any = None
        self._processor: Any = None
        self._playwright: Any = None
        self._browser: Any = None

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
            from PIL import Image  # noqa: F401

            self._available = True
        except ImportError:
            self._available = False

        return self._available

    def _init_clip(self) -> None:
        """Lazy initialize CLIP model."""
        if self._clip_model is not None:
            return

        try:
            from sentence_transformers import SentenceTransformer

            self._clip_model = SentenceTransformer("clip-ViT-B-32")
            logger.debug("CLIP model loaded successfully")
        except Exception as e:
            logger.warning("Failed to load CLIP model: %s", e)
            self._clip_model = None

    async def _init_playwright(self) -> Any:
        """Lazy initialize Playwright browser."""
        if self._browser is not None:
            return self._browser

        try:
            from playwright.async_api import async_playwright

            self._playwright = await async_playwright().start()
            self._browser = await self._playwright.chromium.launch(headless=True)
            logger.debug("Playwright browser launched")
            return self._browser
        except Exception as e:
            logger.warning("Failed to launch Playwright: %s", e)
            return None

    async def _capture_screenshot(self, url: str) -> bytes | None:
        """Capture a screenshot of the URL using Playwright."""
        browser = await self._init_playwright()
        if browser is None:
            return None

        try:
            page = await browser.new_page()
            await page.goto(url, wait_until="networkidle", timeout=30000)
            screenshot = await page.screenshot(full_page=True)
            await page.close()
            return screenshot
        except Exception as e:
            logger.warning("Screenshot capture failed for %s: %s", url, e)
            return None

    async def _extract_text_content(self, url: str) -> str | None:
        """Extract text content from the page using Playwright."""
        browser = await self._init_playwright()
        if browser is None:
            return None

        try:
            page = await browser.new_page()
            await page.goto(url, wait_until="networkidle", timeout=30000)

            # Extract main content areas
            content = await page.evaluate("""() => {
                // Try common content selectors
                const selectors = [
                    'article', 'main', '[role="main"]',
                    '.content', '.post', '.article',
                    '#content', '#main'
                ];

                for (const sel of selectors) {
                    const el = document.querySelector(sel);
                    if (el && el.textContent.trim().length > 100) {
                        return el.textContent.trim();
                    }
                }

                // Fallback to body text
                return document.body ? document.body.textContent.trim() : '';
            }""")

            await page.close()
            return content if content else None
        except Exception as e:
            logger.warning("Text extraction failed for %s: %s", url, e)
            return None

    def _compute_similarity(self, image_bytes: bytes, query: str) -> float:
        """Compute CLIP similarity between image and query text."""
        self._init_clip()
        if self._clip_model is None:
            return 0.0

        try:
            from PIL import Image

            image = Image.open(io.BytesIO(image_bytes))
            embeddings = self._clip_model.encode([query, image], convert_to_tensor=True)

            # Compute cosine similarity
            import torch

            similarity = torch.nn.functional.cosine_similarity(
                embeddings[0:1], embeddings[1:2]
            )
            return float(similarity.item())
        except Exception as e:
            logger.warning("CLIP similarity computation failed: %s", e)
            return 0.0

    def resolve(self, url: str, query: str) -> VisualResult | None:
        """Resolve URL content synchronously."""
        logger.debug("VisualResolver.resolve called for %s", url)

        if not self.is_available():
            return None

        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                import concurrent.futures

                with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
                    result = pool.submit(asyncio.run, self.resolve_async(url, query)).result()
                    return result
            else:
                return loop.run_until_complete(self.resolve_async(url, query))
        except RuntimeError:
            return asyncio.run(self.resolve_async(url, query))

    async def resolve_async(self, url: str, query: str) -> VisualResult | None:
        """Resolve URL content asynchronously using Playwright + CLIP."""
        logger.debug("VisualResolver.resolve_async called for %s", url)

        if not self.is_available():
            return None

        # Capture screenshot
        screenshot = await self._capture_screenshot(url)
        if screenshot is None:
            return None

        # Extract text content as fallback
        text_content = await self._extract_text_content(url)

        # Compute CLIP similarity if model is available
        score = 0.0
        if screenshot:
            score = self._compute_similarity(screenshot, query)

        # Use text content if available, otherwise describe the visual content
        content = text_content or f"[Visual content captured from {url}]"

        metadata = {
            "url": url,
            "query": query,
            "has_screenshot": screenshot is not None,
            "has_text": text_content is not None,
            "clip_score": score,
        }

        return VisualResult(
            content=content,
            score=score,
            metadata=metadata,
        )

    async def close(self) -> None:
        """Clean up resources."""
        if self._browser:
            await self._browser.close()
            self._browser = None
        if self._playwright:
            await self._playwright.stop()
            self._playwright = None
