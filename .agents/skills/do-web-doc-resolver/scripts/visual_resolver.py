import argparse
import asyncio
import atexit
import base64
import io
import json
import logging
import os
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Optional, cast

import numpy as np

logger = logging.getLogger(__name__)


def _import_pil() -> Any:
    try:
        import PIL.Image

        return PIL.Image
    except ImportError as e:
        raise ImportError(
            "Pillow is required for visual resolution. Install with: pip install Pillow"
        ) from e


def _import_playwright() -> Any:
    try:
        from playwright.async_api import async_playwright

        return async_playwright
    except ImportError as e:
        raise ImportError(
            "playwright is required for visual resolution. Install with: pip install playwright"
        ) from e


def _import_sentence_transformers() -> Any:
    try:
        from sentence_transformers import SentenceTransformer

        return SentenceTransformer
    except ImportError as e:
        raise ImportError(
            "sentence-transformers is required for visual resolution. Install with: pip install sentence-transformers"
        ) from e


@dataclass
class VisualConfig:
    clip_threshold: float = 0.22
    viewport_width: int = 1280
    viewport_height: int = 900
    page_timeout_ms: int = 12_000
    scroll_frames: int = 3
    caption_model: str = "qwen/qwen2.5-vl-7b-instruct:free"
    caption_max_tokens: int = 512
    enabled: bool = True
    clip_model_name: str = "clip-ViT-B-32"

    @classmethod
    def from_toml(cls, toml_path: str = "config.toml") -> "VisualConfig":
        config_dict = {}
        if os.path.exists(toml_path):
            try:
                import tomllib

                with open(toml_path, "rb") as f:
                    full_config = tomllib.load(f)
                    config_dict = full_config.get("visual", {})
            except Exception as e:
                logger.debug("Failed to load %s: %s", toml_path, e)

        # Environment overrides
        env_caption = os.getenv("DO_WDR_VISUAL_CAPTION")
        if env_caption == "0":
            config_dict["caption_model"] = ""

        env_threshold = os.getenv("DO_WDR_VISUAL_THRESHOLD")
        if env_threshold:
            try:
                config_dict["clip_threshold"] = float(env_threshold)
            except ValueError:
                logger.warning("Invalid DO_WDR_VISUAL_THRESHOLD: %s", env_threshold)

        res = cls()
        for k, v in config_dict.items():
            if hasattr(res, k):
                setattr(res, k, v)
        return res


class ScreenshotEngine:
    def __init__(self, cfg: VisualConfig):
        self.cfg = cfg
        self.playwright: Any = None
        self.browser: Any = None
        self.context: Any = None

    async def _ensure_browser(self) -> None:
        if self.browser:
            return
        pw = _import_playwright()
        self.playwright = await pw().__aenter__()
        self.browser = await self.playwright.chromium.launch(
            headless=True, args=["--no-sandbox", "--disable-dev-shm-usage"]
        )
        self.context = await self.browser.new_context(
            viewport={"width": self.cfg.viewport_width, "height": self.cfg.viewport_height}
        )

    async def capture(self, url: str) -> list[Any]:
        """Returns cfg.scroll_frames PIL images."""
        PIL_Image = _import_pil()
        try:
            await self._ensure_browser()
            if self.context is None:
                return []
            page = await self.context.new_page()
            frames = []
            try:
                await page.goto(url, timeout=self.cfg.page_timeout_ms, wait_until="networkidle")

                for i in range(self.cfg.scroll_frames):
                    if i > 0:
                        await page.evaluate(f"window.scrollBy(0, {self.cfg.viewport_height})")
                        await asyncio.sleep(0.3)  # settle

                    screenshot_bytes = await page.screenshot(type="png")
                    img = PIL_Image.open(io.BytesIO(screenshot_bytes)).convert("RGB")
                    frames.append(img)
            finally:
                await page.close()
            return frames
        except Exception as e:
            logger.warning("Capture failed for %s: %s", url, e)
            return []

    async def close(self) -> None:
        if self.browser:
            await self.browser.close()
            self.browser = None
        if self.playwright:
            await self.playwright.__aexit__(None, None, None)
            self.playwright = None


class ClipEncoder:
    _instance: Optional["ClipEncoder"] = None

    def __init__(self, model_name: str = "clip-ViT-B-32"):
        SentenceTransformer = _import_sentence_transformers()
        self.model = SentenceTransformer(model_name)

    @classmethod
    def get_instance(cls, model_name: str = "clip-ViT-B-32") -> "ClipEncoder":
        if cls._instance is None:
            cls._instance = cls(model_name)
        return cls._instance

    def encode_image(self, img: Any) -> np.ndarray:
        """Returns L2-normalised 512-d float32 vector."""
        vec: np.ndarray = self.model.encode(img)  # type: ignore[no-any-return]
        if not isinstance(vec, np.ndarray):
            vec = np.array(vec)
        return vec / (np.linalg.norm(vec) + 1e-10)  # type: ignore[no-any-return]

    def encode_text(self, text: str) -> np.ndarray:
        """Returns L2-normalised 512-d float32 vector."""
        vec: np.ndarray = self.model.encode(text)  # type: ignore[no-any-return]
        if not isinstance(vec, np.ndarray):
            vec = np.array(vec)
        return vec / (np.linalg.norm(vec) + 1e-10)  # type: ignore[no-any-return]

    def similarity(self, a: np.ndarray, b: np.ndarray) -> float:
        """Cosine similarity clipped to [0, 1]."""
        sim = float(np.dot(a, b))
        return max(0.0, min(1.0, sim))

    def best_frame(self, frames: list[Any], query_vec: np.ndarray) -> tuple[Any, float]:
        """Returns (highest-similarity frame, its score)."""
        if not frames:
            return None, 0.0

        best_img = frames[0]
        max_sim = -1.0

        for img in frames:
            img_vec = self.encode_image(img)
            sim = self.similarity(img_vec, query_vec)
            if sim > max_sim:
                max_sim = sim
                best_img = img

        return best_img, max_sim


class VlmCaptioner:
    def __init__(self, model: str, max_tokens: int):
        self.model = model
        self.max_tokens = max_tokens
        self.system_prompt = (
            "You are a document analysis assistant. Describe the page content, "
            "focusing on the query context. Output compact GitHub Flavored Markdown."
        )

    def caption(self, img: Any, query: str) -> str:
        """Route: Ollama if OLLAMA_BASE_URL set, OpenRouter if key set, else fallback."""
        if not self.model:
            return self._fallback_caption(img, query)

        if os.getenv("OLLAMA_BASE_URL"):
            try:
                return self._ollama_caption(img, query)
            except Exception as e:
                logger.warning("Ollama caption failed: %s", e)

        if os.getenv("OPENROUTER_API_KEY"):
            try:
                return self._openrouter_caption(img, query)
            except Exception as e:
                logger.warning("OpenRouter caption failed: %s", e)

        return self._fallback_caption(img, query)

    def _image_to_data_url(self, img: Any) -> str:
        """Base64-encode PNG to data:image/png;base64,... URI."""
        buffered = io.BytesIO()
        img.save(buffered, format="PNG")
        img_str = base64.b64encode(buffered.getvalue()).decode()
        return f"data:image/png;base64,{img_str}"

    def _openrouter_caption(self, img: Any, query: str) -> str:
        """POST to https://openrouter.ai/api/v1/chat/completions with vision payload."""
        api_key = os.getenv("OPENROUTER_API_KEY")
        data_url = self._image_to_data_url(img)

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": self.system_prompt},
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": f"Query: {query}"},
                        {"type": "image_url", "image_url": {"url": data_url}},
                    ],
                },
            ],
            "max_tokens": self.max_tokens,
        }

        req = urllib.request.Request(
            "https://openrouter.ai/api/v1/chat/completions",
            data=json.dumps(payload).encode(),
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            method="POST",
        )

        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode())
            return cast(str, res_data["choices"][0]["message"]["content"].strip())

    def _ollama_caption(self, img: Any, query: str) -> str:
        """POST to {OLLAMA_BASE_URL}/api/generate with base64 image."""
        base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
        buffered = io.BytesIO()
        img.save(buffered, format="PNG")
        img_base64 = base64.b64encode(buffered.getvalue()).decode()

        payload = {
            "model": self.model,
            "prompt": f"{self.system_prompt}\n\nQuery: {query}",
            "images": [img_base64],
            "stream": False,
            "options": {"num_predict": self.max_tokens},
        }

        req = urllib.request.Request(
            f"{base_url}/api/generate",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode())
            return cast(str, res_data["response"].strip())

    def _fallback_caption(self, img: Any, query: str) -> str:
        """Returns structured Markdown label with image dimensions and query."""
        width, height = img.size
        return f"### Visual Analysis (Fallback)\n\n- **Dimensions**: {width}x{height}\n- **Query**: {query}\n- **Status**: No VLM captioning available (check DO_WDR_VISUAL_CAPTION or API keys)."


@dataclass
class ProviderResult:
    content: str | None
    score: float
    provider: str
    latency_ms: float = 0.0
    metadata: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "content": self.content,
            "score": self.score,
            "provider": self.provider,
            "latency_ms": self.latency_ms,
            "metadata": self.metadata,
        }


class VisualResolver:
    PROVIDER_NAME = "visual_clip"

    def __init__(self, cfg: VisualConfig | None = None):
        self.cfg = cfg or VisualConfig.from_toml()
        self.engine = ScreenshotEngine(self.cfg)
        self.encoder: ClipEncoder | None = None
        self.captioner = VlmCaptioner(self.cfg.caption_model, self.cfg.caption_max_tokens)

    def is_available(self) -> bool:
        """Returns False if cfg.enabled=False or any required import fails."""
        if not self.cfg.enabled:
            return False
        try:
            _import_pil()
            _import_playwright()
            _import_sentence_transformers()
            return True
        except ImportError:
            return False

    def resolve(self, url: str, query: str) -> ProviderResult | None:
        """Sync wrapper: asyncio.run(_resolve_async)."""
        return asyncio.run(self._resolve_async(url, query))

    async def resolve_async(self, url: str, query: str) -> ProviderResult | None:
        """Async variant for callers already in an async context."""
        return await self._resolve_async(url, query)

    async def _resolve_async(self, url: str, query: str) -> ProviderResult | None:
        """
        Pipeline:
          1. capture(url) -> list[PIL.Image]
          2. encode_text(query) -> query_vec
          3. best_frame(frames, query_vec) -> (best_img, clip_score)
          4. if clip_score < threshold: return ProviderResult(content=None, score=...)
          5. captioner.caption(best_img, query) -> markdown
          6. return ProviderResult(content=markdown, score=clip_score, ...)
        """
        start_time = time.time()
        try:
            if not self.is_available():
                return None

            if self.encoder is None:
                self.encoder = ClipEncoder.get_instance(self.cfg.clip_model_name)

            frames = await self.engine.capture(url)
            if not frames or self.encoder is None:
                return None

            query_vec = self.encoder.encode_text(query)
            best_img, clip_score = self.encoder.best_frame(frames, query_vec)

            metadata = {
                "clip_score": clip_score,
                "frames_captured": len(frames),
                "frame_size": best_img.size if best_img else None,
                "caption_model": self.cfg.caption_model,
                "url": url,
            }

            if clip_score < self.cfg.clip_threshold:
                latency = (time.time() - start_time) * 1000
                return ProviderResult(
                    content=None,
                    score=clip_score,
                    provider=self.PROVIDER_NAME,
                    latency_ms=latency,
                    metadata=metadata,
                )

            content = self.captioner.caption(best_img, query)
            latency = (time.time() - start_time) * 1000

            return ProviderResult(
                content=content,
                score=clip_score,
                provider=self.PROVIDER_NAME,
                latency_ms=latency,
                metadata=metadata,
            )
        except Exception as e:
            logger.error("VisualResolver failed: %s", e)
            return None

    async def close(self) -> None:
        """Release Playwright browser."""
        await self.engine.close()


def main():
    parser = argparse.ArgumentParser(description="Visual Resolver CLI")
    parser.add_argument("url", help="URL to capture")
    parser.add_argument("query", help="Query context for captioning")
    parser.add_argument("--threshold", type=float, help="Override CLIP threshold")
    parser.add_argument("--no-caption", action="store_true", help="Disable captioning")
    parser.add_argument("--json", action="store_true", help="Output in JSON format")

    args = parser.parse_args()

    cfg = VisualConfig.from_toml()
    if args.threshold is not None:
        cfg.clip_threshold = args.threshold
    if args.no_caption:
        cfg.caption_model = ""

    resolver = VisualResolver(cfg)
    if not resolver.is_available():
        print(
            "Error: Dependencies missing (Pillow, playwright, or sentence-transformers).",
            file=sys.stderr,
        )
        sys.exit(1)

    atexit.register(lambda: asyncio.run(resolver.close()))

    result = resolver.resolve(args.url, args.query)

    if result:
        if args.json:
            print(json.dumps(result.to_dict(), indent=2))
        else:
            if result.content:
                print(result.content)
            else:
                print(
                    f"No content found (CLIP score: {result.score:.4f} < threshold: {cfg.clip_threshold})"
                )
    else:
        print("Resolution failed.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
