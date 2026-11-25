import os
import subprocess

import pytest

CLI_PATH = "./cli/target/release/do-wdr"

pytestmark = [
    pytest.mark.integration,
    pytest.mark.skipif(
        not os.path.exists(CLI_PATH),
        reason=f"CLI binary not found at {CLI_PATH}.",
    ),
]


@pytest.mark.integration
def test_cli_direct_fetch_latex():
    """Test that direct_fetch correctly extracts LaTeX from img alt tags on Wikipedia."""
    url = "https://en.wikipedia.org/wiki/Quadratic_formula"

    result = subprocess.run(
        [CLI_PATH, "resolve", url, "--provider", "direct_fetch"],
        capture_output=True,
        text=True,
        check=True,
    )

    content = result.stdout
    # Wikipedia uses {\displaystyle ...} in alt tags
    assert "{\\displaystyle" in content
    assert "ax^{2}+bx+c=0" in content


@pytest.mark.integration
def test_cli_direct_fetch_code_lang():
    """Test that direct_fetch extracts language hints and handles nested code blocks."""
    # Using a site known to have <pre class="language-..."> or similar
    url = "https://react.dev"

    result = subprocess.run(
        [CLI_PATH, "resolve", url, "--provider", "direct_fetch"],
        capture_output=True,
        text=True,
        check=True,
    )

    content = result.stdout
    # Check for fenced code blocks (we expect ``` without necessarily a lang if it's not in class)
    # But react.dev usually has them.
    assert "```" in content
    # Ensure we don't have the double backtick bug ` ` `
    assert "` ` `" not in content
    assert "function" in content
