"""
Data models and Enums for the Web Doc Resolver.
"""

from dataclasses import asdict, dataclass, field
from enum import Enum
from typing import Any, Protocol, runtime_checkable


class ErrorType(Enum):
    """Types of errors that can occur during resolution."""

    RATE_LIMIT = "rate_limit"
    AUTH_ERROR = "auth_error"
    QUOTA_EXHAUSTED = "quota_exhausted"
    NETWORK_ERROR = "network_error"
    NOT_FOUND = "not_found"
    INVALID_URL = "invalid_url"
    TIMEOUT = "timeout"
    INVALID_RESPONSE = "invalid_response"
    SSRF_BLOCKED = "ssrf_blocked"
    CONTENT_TOO_LARGE = "content_too_large"
    BOT_CHALLENGE = "bot_challenge"
    UNKNOWN = "unknown"


class Profile(Enum):
    """Execution profiles for resource management."""

    FREE = "free"
    BALANCED = "balanced"
    FAST = "fast"
    QUALITY = "quality"

    def is_provider_allowed(self, provider: "ProviderType") -> bool:
        if self == Profile.FREE:
            return not provider.is_paid()
        if self == Profile.FAST:
            return provider.is_fast()
        return True

    def max_hops(self) -> int:
        if self == Profile.FREE:
            return 3
        if self == Profile.FAST:
            return 2
        if self == Profile.BALANCED:
            return 6
        if self == Profile.QUALITY:
            return 8
        return 4


class FetchTier(int, Enum):
    """Escalation cost tier for fetch providers.
    Lower = cheaper, always tried first."""

    FREE_STATIC = 0  # llms_txt: static text file, zero cost
    FREE_DIRECT = 1  # direct_fetch: plain httpx, zero cost
    FREE_SEARCH = 2  # duckduckgo: free web search
    PAID_LITE = 3  # jina, firecrawl: paid but cheap per-call
    STEALTH = 4  # anti-bot bypass tier
    PAID_BROWSER = 5  # mistral_browser: paid + JS execution


class ProviderType(Enum):
    """Available providers for resolution."""

    # URL providers
    LLMS_TXT = "llms_txt"
    JINA = "jina"
    FIRECRAWL = "firecrawl"
    DIRECT_FETCH = "direct_fetch"
    MISTRAL_BROWSER = "mistral_browser"

    # Query providers
    EXA_MCP = "exa_mcp"
    EXA = "exa"
    TAVILY = "tavily"
    SERPER = "serper"
    DUCKDUCKGO = "duckduckgo"
    MISTRAL_WEBSEARCH = "mistral_websearch"

    # New providers
    DOCLING = "docling"
    OCR = "ocr"
    VISUAL_CLIP = "visual_clip"

    def is_paid(self) -> bool:
        return self in (
            ProviderType.EXA,
            ProviderType.TAVILY,
            ProviderType.SERPER,
            ProviderType.FIRECRAWL,
            ProviderType.MISTRAL_WEBSEARCH,
            ProviderType.MISTRAL_BROWSER,
            ProviderType.VISUAL_CLIP,
        )

    def is_fast(self) -> bool:
        return self in (
            ProviderType.EXA_MCP,
            ProviderType.DUCKDUCKGO,
            ProviderType.LLMS_TXT,
            ProviderType.JINA,
            ProviderType.DIRECT_FETCH,
        )


@dataclass
class ValidationResult:
    """Result of URL validation."""

    is_valid: bool
    status_code: int | None = None
    content_type: str | None = None
    final_url: str | None = None
    error: str | None = None
    redirect_chain: list[str] = field(default_factory=list)


@dataclass
class ProviderMetric:
    """Metrics for a single provider call."""

    provider: str
    latency_ms: int
    success: bool
    paid: bool


@dataclass
class ResolveMetrics:
    """Aggregated metrics for a resolution request."""

    total_latency_ms: int = 0
    provider_metrics: list[ProviderMetric] = field(default_factory=list)
    cascade_depth: int = 0
    paid_usage: bool = False
    cache_hit: bool = False
    quality_gate: dict[str, Any] = field(default_factory=dict)

    def record_provider(self, provider: "ProviderType", latency_ms: int, success: bool):
        paid = provider.is_paid()
        if paid and success:
            self.paid_usage = True
        self.provider_metrics.append(
            ProviderMetric(
                provider=provider.value,
                latency_ms=latency_ms,
                success=success,
                paid=paid,
            )
        )
        self.total_latency_ms += latency_ms


@dataclass
class ResolvedResult:
    """Result of a successful resolution."""

    source: str
    content: str
    url: str | None = None
    query: str | None = None
    score: float = 0.0
    validated_links: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)
    metrics: ResolveMetrics | None = None

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return asdict(self)


@runtime_checkable
class ReadonlyResolverProtocol(Protocol):
    """Protocol for resolver provider callables used in cascade_map.

    In the cascade, providers are wrapped as zero-argument lambdas that capture
    url/query and max_chars in their closure. The cascade calls them via
    asyncio.to_thread(func) with no arguments.

    A resolver MUST:
    - Be callable with no arguments (captures context via closure)
    - Return ResolvedResult, str, or None on completion
    - Never write to disk, mutate global state, or open files
    - Be safe to call concurrently (no shared mutable state)

    A resolver MUST NOT:
    - Write files or modify environment variables
    - Spawn subprocesses with side effects
    - Access databases except via the semantic cache interface
    """

    def __call__(self) -> ResolvedResult | str | None: ...


__all__ = [
    "ErrorType",
    "Profile",
    "ProviderType",
    "ValidationResult",
    "ProviderMetric",
    "ResolveMetrics",
    "ResolvedResult",
    "ReadonlyResolverProtocol",
]
