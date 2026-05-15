with open(".agents/skills/do-web-doc-resolver/tests/test_resolve.py", "r") as f:
    content = f.read()

import re

# Fix test_resolved_content_above_min_chars
def_test_resolved_content_above_min_chars = """    def test_resolved_content_above_min_chars(self, sample_url, max_chars):
        \"\"\"Resolved content should typically be above MIN_CHARS.\"\"\"
        result = resolve(sample_url, max_chars=max_chars)
        assert result and "content" in result
        if result["content"] in ("", "Failed") or "error" in result:
            import pytest
            pytest.skip("Known failure case")
        else:
            assert len(result["content"]) >= MIN_CHARS"""

content = re.sub(
    r'    def test_resolved_content_above_min_chars\(self, sample_url, max_chars\):\n        \"\"\"Resolved content should typically be above MIN_CHARS\.\"\"\"\n        result = resolve\(sample_url, max_chars=max_chars\)\n        if result and "content" in result:\n            # Most successful resolutions should exceed MIN_CHARS\n            assert len\(result\["content"\]\) >= MIN_CHARS or result\["content"\] == "" or result\["content"\] == "Failed" or "error" in result',
    def_test_resolved_content_above_min_chars,
    content,
    flags=re.MULTILINE
)

with open(".agents/skills/do-web-doc-resolver/tests/test_resolve.py", "w") as f:
    f.write(content)
