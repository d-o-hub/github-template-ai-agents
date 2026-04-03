"""do-web-doc-resolver: Resolve URLs and queries into LLM-ready markdown."""
from .scripts.resolve import resolve, resolve_url, resolve_query

__all__ = ["resolve", "resolve_url", "resolve_query"]
