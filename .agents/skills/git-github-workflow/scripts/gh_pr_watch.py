#!/usr/bin/env python3
"""Watch GitHub PR CI and review activity for PR sentinel workflows.

CLI-agnostic: works with any agent that can invoke Python3 + GitHub CLI.
Adapted from https://github.com/openai/codex/blob/main/.codex/skills/babysit-pr/scripts/gh_pr_watch.py
"""

import sys
from pathlib import Path

# Import seam: prefer the pr_watch package that ships beside this entry; the
# explicit path insert keeps `python3 scripts/gh_pr_watch.py` working from any
# working directory and under non-standard invocation forms.
sys.path.insert(0, str(Path(__file__).resolve().parent))

from pr_watch.main import main

if __name__ == "__main__":
    raise SystemExit(main())
