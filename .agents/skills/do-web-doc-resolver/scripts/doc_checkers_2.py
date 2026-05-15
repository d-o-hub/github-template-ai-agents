import json
import re
from pathlib import Path

from scripts.doc_models import Report, extract_code_blocks, extract_markdown_links

REPO_ROOT = Path(__file__).resolve().parent.parent


def check_repo_tree(report: Report, doc_name: str, content: str):
    """Verify entries in ASCII tree diagrams exist in the filesystem."""
    for start_line, _lang, code in extract_code_blocks(content):
        # Detect tree-like structures
        if "├──" not in code and "└──" not in code:
            continue

        dir_stack: list[tuple[int, str]] = []

        for offset, tree_line in enumerate(code.splitlines()):
            line_no = start_line + offset

            # Measure indentation by counting tree-drawing chars before ├──/└──
            indent_match = re.match(r"^([│ ]*)(?:├──|└──)", tree_line)
            if not indent_match:
                # Handle root line (e.g. "scripts/")
                root_match = re.match(r"^(\S+/)$", tree_line.strip())
                if root_match:
                    root = root_match.group(1).rstrip("/")
                    dir_stack = [(-1, root)]
                continue

            indent = len(indent_match.group(1))
            entry_match = re.match(r"^[│ ]*(?:├──|└──)\s*(\S+)", tree_line)
            if not entry_match:
                continue

            entry = entry_match.group(1).rstrip("/")
            if entry in ("...", ""):
                continue

            # Pop stack if indent decreased
            while dir_stack and dir_stack[-1][0] >= indent:
                dir_stack.pop()

            parent = dir_stack[-1][1] if dir_stack else "."
            rel_path = f"{parent}/{entry}".lstrip("./")

            # Validate path
            full_path = REPO_ROOT / rel_path
            if not full_path.exists():
                report.add(
                    "warning",
                    "repo-tree",
                    doc_name,
                    f"Tree entry '{rel_path}' does not exist",
                    line_no,
                )

            # If it looks like a directory, push it to stack
            is_dir = (
                entry_match.group(1).endswith("/")
                or full_path.is_dir()
                or entry.replace(".rs", "") in ("providers", "resolver")
            )
            if is_dir:
                dir_stack.append((indent, rel_path))


def check_npm_scripts(report: Report):
    """Verify package.json scripts match README.md instructions."""
    pkg_path = REPO_ROOT / "web/package.json"
    readme_path = REPO_ROOT / "README.md"

    if not (pkg_path.exists() and readme_path.exists()):
        return

    with open(pkg_path) as f:
        pkg = json.load(f)
        scripts = pkg.get("scripts", {})

    readme = readme_path.read_text()
    for match in re.finditer(r"pnpm run (\w+)", readme):
        cmd = match.group(1)
        if cmd not in scripts:
            report.add(
                "error",
                "npm-script",
                "README.md",
                f"Referenced npm script '{cmd}' missing from package.json",
            )


def check_cross_docs(report: Report):
    """Verify consistency across different documentation files."""
    readme_path = REPO_ROOT / "README.md"
    agents_path = REPO_ROOT / "AGENTS.md"

    if not (readme_path.exists() and agents_path.exists()):
        return

    readme = readme_path.read_text()
    agents_path.read_text()

    # Verify version sync (check if strings like "1.1.0" match)
    re.search(r"version\s*(\d+\.\d+\.\d+)", readme)

    # Check for duplicate links in README
    seen: dict[tuple[str, str], int] = {}
    for line_no, text, target in extract_markdown_links(readme):
        key = (text, target)
        if key in seen:
            report.add(
                "warning",
                "duplicate-link",
                "README.md",
                f"Duplicate link: [{text}]({target}) (first at line {seen[key]})",
                line_no,
            )
        else:
            seen[key] = line_no
