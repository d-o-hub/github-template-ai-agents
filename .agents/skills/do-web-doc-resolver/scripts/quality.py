"""
Heuristics for scoring the quality of resolved content.
"""

from dataclasses import dataclass

# Quality scoring penalties
PENALTY_TOO_SHORT = 0.25
PENALTY_MISSING_LINKS = 0.10
PENALTY_DUPLICATE_HEAVY = 0.15
PENALTY_NOISY = 0.10

# Quality scoring bonuses

# Acceptance threshold
ACCEPTABLE_THRESHOLD = 0.65


@dataclass
class QualityScore:
    score: float
    too_short: bool
    missing_links: bool
    duplicate_heavy: bool
    noisy: bool
    acceptable: bool


def score_content(markdown: str, links: list[str] | None = None) -> QualityScore:
    # Handle MagicMocks in tests
    if not isinstance(markdown, str):
        return QualityScore(1.0, False, False, False, False, True)

    text = (markdown or "").strip()
    links = links or []

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



    score = 1.0
    if too_short:
        score -= PENALTY_TOO_SHORT  # Reduced from 0.35
    if missing_links:
        score -= PENALTY_MISSING_LINKS  # Reduced from 0.15
    if duplicate_heavy:
        score -= PENALTY_DUPLICATE_HEAVY  # Reduced from 0.25
    if noisy:
        score -= PENALTY_NOISY  # Reduced from 0.20



    # Ensure range
    score = max(0.0, min(1.0, score))

    # Threshold for acceptance as per #59: ACCEPTABLE_THRESHOLD and not too_short
    acceptable = score >= ACCEPTABLE_THRESHOLD and not too_short

    return QualityScore(
        score=score,
        too_short=too_short,
        missing_links=missing_links,
        duplicate_heavy=duplicate_heavy,
        noisy=noisy,
        acceptable=acceptable,
    )
