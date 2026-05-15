#!/usr/bin/env python3
"""
Validate that documentation stays in sync with the codebase.
"""

import argparse
import json
import sys
from pathlib import Path

# Add project root to sys.path
sys.path.append(str(Path(__file__).resolve().parent.parent))

from scripts.doc_checkers_1 import (
    check_cargo_features,
    check_file_references,
    check_python_cli,
    check_rust_architecture,
    check_rust_cli_flags,
    check_shell_commands,
)
from scripts.doc_checkers_2 import (
    check_cross_docs,
    check_npm_scripts,
    check_repo_tree,
)
from scripts.doc_fixers import (
    fix_cargo_features,
    fix_duplicate_links,
    fix_python_cli,
    fix_repo_trees,
    fix_rust_architecture,
)
from scripts.doc_models import Report, read_file

REPO_ROOT = Path(__file__).resolve().parent.parent


def run_all_checks() -> Report:
    """Run all documentation validation checks."""
    report = Report()

    docs = [
        "README.md",
        "AGENTS.md",
        "CONTRIBUTING.md",
        ".agents/skills/do-web-doc-resolver/SKILL.md",
        ".agents/skills/do-web-doc-resolver/references/CASCADE.md",
        ".agents/skills/do-web-doc-resolver/references/CLI.md",
        ".agents/skills/do-web-doc-resolver/references/CONFIG.md",
        ".agents/skills/do-web-doc-resolver/references/PROVIDERS.md",
        ".agents/skills/do-web-doc-resolver/references/RUST_CLI.md",
        ".agents/skills/do-web-doc-resolver/references/TESTING.md",
    ]

    for doc in docs:
        path = REPO_ROOT / doc
        if not path.exists():
            continue

        content = read_file(path)
        check_file_references(report, doc, content)
        check_shell_commands(report, doc, content)
        check_repo_tree(report, doc, content)

    check_python_cli(report)
    check_rust_cli_flags(report)
    check_cargo_features(report)
    check_rust_architecture(report)
    check_npm_scripts(report)
    check_cross_docs(report)

    return report


def run_fixers(report: Report) -> int:
    """Run fixers for common issues."""
    fixed_count = 0
    fixed_count += fix_python_cli(report)
    fixed_count += fix_cargo_features(report)
    fixed_count += fix_duplicate_links(report)
    fixed_count += fix_repo_trees(report)
    fixed_count += fix_rust_architecture(report)
    return fixed_count


def main():
    parser = argparse.ArgumentParser(description="Validate documentation")
    parser.add_argument("--strict", action="store_true", help="Exit 1 on warnings")
    parser.add_argument("--json", action="store_true", help="Output JSON report")
    parser.add_argument("--fix", action="store_true", help="Auto-fix issues")
    args = parser.parse_args()

    report = run_all_checks()

    if args.fix:
        fixed = run_fixers(report)
        if fixed > 0:
            print(f"Fixed {fixed} issues. Re-validating...")
            report = run_all_checks()

    if args.json:
        print(json.dumps(report.to_dict(), indent=2))
    else:
        for issue in report.issues:
            print(issue)

        counts = report.counts
        print(f"\nSummary: {counts['error']} errors, {counts['warning']} warnings")

    if report.counts["error"] > 0:
        sys.exit(1)
    if args.strict and report.counts["warning"] > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
