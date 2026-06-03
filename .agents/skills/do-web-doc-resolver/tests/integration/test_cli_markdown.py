import os
import subprocess

import pytest

CLI_PATH = "./cli/target/release/do-wdr"

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(
        not os.path.exists(CLI_PATH),
        reason=f"CLI binary not found at {CLI_PATH}. Run 'cd cli && cargo build --release' first.",
    ),
]


def check(condition, message="Assertion failed"):
    """Security-compliant assertion helper that won't be removed by optimization."""
    if not condition:
        raise AssertionError(message)


@pytest.mark.integration
def test_cli_output_markdown_code_blocks():
    """Test that the CLI correctly outputs Markdown with code blocks from a documentation site."""
    url = "https://docs.rs/tokio/latest/tokio/"

    result = subprocess.run(
        [CLI_PATH, "resolve", url, "--provider", "jina"],
        capture_output=True,
        text=True,
        check=True,
    )

    content = result.stdout
    check(len(content) > 500, "Content too short")
    # Check for presence of code blocks
    check("```" in content, "Missing code blocks")
    # Ensure no common 'unparsed' indicators
    check("<pre" not in content, "Found unparsed <pre> tag")
    check("<code>" not in content, "Found unparsed <code> tag")


@pytest.mark.integration
def test_cli_output_markdown_latex():
    """Test that the CLI correctly outputs Markdown with LaTeX from a math-heavy site."""
    url = "https://en.wikipedia.org/wiki/Quadratic_formula"

    result = subprocess.run(
        [CLI_PATH, "resolve", url, "--provider", "jina"],
        capture_output=True,
        text=True,
        check=True,
    )

    content = result.stdout
    check(len(content) > 500, "Content too short")

    # Check for LaTeX patterns
    # Wikipedia Jina output often uses $ or \( \) or images with alt text
    # Let's check for common LaTeX symbols or markers
    latex_indicators = ["\\pm", "\\sqrt", "b^2", "2a", "$"]
    found = any(ind in content for ind in latex_indicators)

    check(found, f"No LaTeX indicators found in output: {content[:500]}...")


@pytest.mark.integration
def test_cli_javascript_heavy_site():
    """Test CLI's ability to handle a JS-heavy site."""
    # React.dev is very JS heavy
    url = "https://react.dev/learn"

    result = subprocess.run(
        [CLI_PATH, "resolve", url, "--provider", "jina"],
        capture_output=True,
        text=True,
        check=True,
    )

    content = result.stdout
    check(len(content) > 500, "Content too short")
    # Should have meaningful content, not just a 'loading' or 'enable JS' message
    check("React" in content, "Missing 'React' keyword")
    check(
        "Components" in content or "Hooks" in content or "Learn" in content,
        "Missing React learning keywords",
    )


@pytest.mark.integration
def test_cli_llm_ready_markdown():
    """Test that the CLI output follows 2026 LLM-ready standards."""
    url = "https://docs.rs/tokio/latest/tokio/"

    # Enable synthesis to see LLM-ready output (frontmatter + anchors)
    result = subprocess.run(
        [CLI_PATH, "resolve", url, "--provider", "jina", "--synthesize"],
        capture_output=True,
        text=True,
        check=True,
        env={**os.environ, "MISTRAL_API_KEY": "test_key"},
    )

    content = result.stdout

    # Check for YAML frontmatter
    check(content.startswith("---"), "Missing YAML frontmatter start")
    check("relevance_score:" in content, "Missing relevance_score in frontmatter")
    check("intent_category:" in content, "Missing intent_category in frontmatter")
    check("token_estimate:" in content, "Missing token_estimate in frontmatter")
    check("last_updated:" in content, "Missing last_updated in frontmatter")

    # Check for Structural Anchors
    check("[ANCHOR: SUMMARY]" in content, "Missing [ANCHOR: SUMMARY]")
    check("[ANCHOR: TECHNICAL_DETAILS]" in content, "Missing [ANCHOR: TECHNICAL_DETAILS]")
    check("[ANCHOR: CITATIONS]" in content, "Missing [ANCHOR: CITATIONS]")

    # Ensure citations are present at the end
    check("[1]" in content, "Missing citation marker [1]")
    check(url in content, f"Missing source URL {url}")
