with open(".agents/skills/do-web-doc-resolver/tests/test_resolve.py", "r") as f:
    content = f.read()

import re

# Fix test_resolve_respects_max_chars
content = re.sub(
    r'assert len\(result\["content"\]\) <= 8000  # Allow some tolerance',
    r'assert len(result["content"]) <= small_max + 100  # Allow some tolerance',
    content
)

with open(".agents/skills/do-web-doc-resolver/tests/test_resolve.py", "w") as f:
    f.write(content)
