import sys
import os
import json

DEFAULT_JSON_INDENT = 2

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), ".agents", "skills", "do-web-doc-resolver")))
from scripts.resolve import resolve

if __name__ == "__main__":
    result = resolve("https://docs.python.org/3/library/json.html")
    print(json.dumps(result, indent=DEFAULT_JSON_INDENT))
