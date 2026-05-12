import sys
import json
from scripts.resolve import resolve
sys.path.append(".agents/skills/do-web-doc-resolver")
result = resolve("https://docs.python.org/3/library/json.html")
print(json.dumps(result, indent=2))
