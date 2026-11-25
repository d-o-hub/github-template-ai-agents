"""Content cleaning utilities for token-efficient LLM output.

Priority:
  1. trafilatura — best article extraction, handles most doc/blog pages
  2. readability-lxml — fallback for pages trafilatura returns None on
  3. raw HTML strip — last resort, strips tags with regex
"""

import logging
import re

logger = logging.getLogger(__name__)

_STRIP_RE = re.compile(r"<[^>]+>")
_SPACE_RE = re.compile(r"\s+")


def _strip_html_tags(html: str) -> str:
    """Minimal fallback: strip all HTML tags."""
    text = _STRIP_RE.sub(" ", html)
    return _SPACE_RE.sub(" ", text).strip()


def clean_content(
    html: str,
    url: str = "",
    max_chars: int = 32_000,
    favor_recall: bool = False,
) -> str:
    """Extract main content from HTML, removing boilerplate for LLM efficiency.

    Args:
        html: Raw HTML string from the fetch provider.
        url: Source URL (improves trafilatura heuristics).
        max_chars: Hard limit on returned character count.
        favor_recall: If True, use trafilatura include_tables/include_links=True.

    Returns:
        Cleaned plain-text or light markdown string, capped at max_chars.
    """
    if not html or not html.strip():
        return ""

    try:
        import trafilatura

        result = trafilatura.extract(
            html,
            url=url or None,
            include_tables=favor_recall,
            include_links=favor_recall,
            include_images=False,
            favor_precision=not favor_recall,
            output_format="txt",
            deduplicate=True,
        )
        if result and len(result.strip()) > 200:
            logger.debug("content_clean: trafilatura succeeded (%d chars)", len(result))
            return result[:max_chars]
    except ImportError:
        logger.debug("content_clean: trafilatura not installed, trying readability")
    except Exception as e:
        logger.debug("content_clean: trafilatura failed: %s", e)

    try:
        from readability import Document  # type: ignore[import]

        doc = Document(html)
        summary_html = doc.summary()
        text = _strip_html_tags(summary_html)
        if text and len(text.strip()) > 200:
            logger.debug("content_clean: readability succeeded (%d chars)", len(text))
            return text[:max_chars]
    except ImportError:
        logger.debug("content_clean: readability-lxml not installed, using fallback")
    except Exception as e:
        logger.debug("content_clean: readability failed: %s", e)

    logger.debug("content_clean: using raw strip fallback")
    return _strip_html_tags(html)[:max_chars]
