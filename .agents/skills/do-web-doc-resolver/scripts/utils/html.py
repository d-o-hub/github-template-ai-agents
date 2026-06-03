"""
HTML utilities for the Web Doc Resolver.
"""

import re
from html.parser import HTMLParser

_RE_SPACES = re.compile(r"[ \t]+")
_RE_NEWLINES = re.compile(r"\n{3,}")


class EnhancedHTMLParser(HTMLParser):
    _block_tags = {
        "p",
        "div",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "li",
        "tr",
        "article",
        "section",
        "header",
        "footer",
        "nav",
        "aside",
        "blockquote",
        "ul",
        "ol",
        "table",
        "hr",
    }

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.result: list[str] = []
        self._skip_depth = 0
        self._in_pre = 0

    def handle_starttag(self, tag, attrs):
        tag_lower = tag.lower()
        if tag_lower in ("script", "style"):
            self._skip_depth += 1
        elif self._skip_depth == 0:
            if tag_lower == "pre":
                self._in_pre += 1
                self.result.append("\n\n```\n")
            elif tag_lower == "br":
                self.result.append("\n")
            elif tag_lower == "hr":
                self.result.append("\n\n---\n\n")
            elif tag_lower in (
                "p",
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "h6",
                "blockquote",
                "ul",
                "ol",
                "table",
            ):
                self.result.append("\n\n")
            elif tag_lower in self._block_tags:
                self.result.append("\n")

            if tag_lower == "code":
                self.result.append("`")

    def handle_endtag(self, tag):
        tag_lower = tag.lower()
        if tag_lower in ("script", "style") and self._skip_depth > 0:
            self._skip_depth -= 1
        elif self._skip_depth == 0:
            if tag_lower == "pre":
                self._in_pre = max(0, self._in_pre - 1)
                self.result.append("\n```\n\n")
            elif tag_lower == "code":
                self.result.append("`")
            elif tag_lower in (
                "p",
                "h1",
                "h2",
                "h3",
                "h4",
                "h5",
                "h6",
                "blockquote",
                "ul",
                "ol",
                "table",
            ):
                self.result.append("\n\n")
            elif tag_lower in self._block_tags:
                self.result.append("\n")

    def handle_data(self, data):
        if self._skip_depth == 0:
            if self._in_pre > 0:
                self.result.append(data)
            else:
                # Fast path: only sub if multiple spaces or tabs present
                if "\t" in data or "  " in data:
                    normalized = _RE_SPACES.sub(" ", data)
                else:
                    normalized = data

                if normalized:
                    # Prevent double spaces across chunks
                    if normalized.startswith(" ") and self.result and self.result[-1].endswith(" "):
                        normalized = normalized[1:]
                    if normalized:
                        self.result.append(normalized)


def extract_text_from_html(html: str, base_url: str = "") -> str:
    stripper = EnhancedHTMLParser()
    stripper.feed(html)
    text = "".join(stripper.result)
    # Normalize word joiner and other problematic characters
    if "\u2060" in text:
        text = text.replace("\u2060", "")
    # Note: _RE_SPACES is handled per-chunk in handle_data to preserve code blocks.
    if "\n\n\n" in text:
        text = _RE_NEWLINES.sub("\n\n", text)
    return text.strip()


def compact_content(content: str, max_chars: int) -> str:
    lines = content.splitlines()
    unique_lines = set()
    compacted = []
    for line in lines:
        trimmed = line.strip()
        if not trimmed:
            compacted.append("")
            continue
        if trimmed not in unique_lines:
            compacted.append(trimmed)
            unique_lines.add(trimmed)
    return "\n".join(compacted)[:max_chars]
