"""
Heuristics for scoring the quality of resolved content.
"""

from dataclasses import dataclass, field
from typing import Any

from scripts.docs_validation import DocsValidationResult


@dataclass
class QualityScore:
    score: float
    too_short: bool
    missing_links: bool
    duplicate_heavy: bool
    noisy: bool
    acceptable: bool
    reasons: list[str] = field(default_factory=list)
    docs_validation: DocsValidationResult | None = None


def score_content(markdown: Any, links: list[str] | None = None) -> QualityScore:
    text = str(markdown or "").strip()
    links = links or []
    reasons = []

    length = len(text)
    too_short = length < 500
    missing_links = len(links) == 0

    lines = text.splitlines()
    num_lines = len(lines)
    duplicate_heavy = False
    if num_lines > 0:
        unique_lines = len({line.strip() for line in lines if line.strip()})
        # If fewer than 5 unique lines OR unique lines are less than 1/3 of total lines
        duplicate_heavy = unique_lines < max(5, num_lines // 3)

    noisy_signals = ["cookie", "subscribe", "javascript", "log in", "sign up"]
    text_lower = text.lower()
    noise_count = sum(text_lower.count(signal) for signal in noisy_signals)
    noisy = noise_count > 6

    # 2026 Standard Checks
    has_frontmatter = text.startswith("---") and "relevance_score:" in text
    has_anchors = all(
        anchor in text
        for anchor in [
            "[ANCHOR: SUMMARY]",
            "[ANCHOR: TECHNICAL_DETAILS]",
            "[ANCHOR: COMPARISON]",
            "[ANCHOR: CITATIONS]",
        ]
    )

    score = 1.0
    if too_short:
        score -= 0.25
        reasons.append(f"Content too short ({length} chars)")
    else:
        reasons.append("Basic length requirement met")

    if missing_links:
        score -= 0.10
        reasons.append("Missing references/links")
    else:
        reasons.append(f"Found {len(links)} references")

    if duplicate_heavy:
        score -= 0.15
        reasons.append("Too many duplicate lines")

    if noisy:
        score -= 0.10
        reasons.append("Content contains too much noise (ads/popups signals)")

    # Bonus for 2026 standards
    if has_frontmatter:
        score += 0.05
    if has_anchors:
        score += 0.05

    # Ensure range
    score = max(0.0, score)

    # Threshold for acceptance as per #59: 0.65 and not too_short
    acceptable = score >= 0.65 and not too_short

    return QualityScore(
        score=score,
        too_short=too_short,
        missing_links=missing_links,
        duplicate_heavy=duplicate_heavy,
        noisy=noisy,
        acceptable=acceptable,
        reasons=reasons,
    )
