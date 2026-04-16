## 2026-04-16 - Path Traversal in Pathlib Join
**Vulnerability:** Path traversal in `scripts/lib/eval_executors.py` where `skill_path / file_path` allowed absolute path injection.
**Learning:** In Python's `pathlib`, the `/` operator returns the second operand if it's absolute, bypassing the base path.
**Prevention:** Strip leading slashes from subpaths and validate with `.resolve()` and `.relative_to()` to enforce directory boundaries.
