#!/usr/bin/env python3
"""Synchronize version numbers across all project files.

Source of truth: pyproject.toml [project] version.
Targets: cli/Cargo.toml, web/package.json, cli/src/cli.rs.

Usage:
    python scripts/sync_versions.py           # check only (exit 1 if drift)
    python scripts/sync_versions.py --fix     # auto-fix all targets
    python scripts/sync_versions.py --set 1.2.0  # set specific version everywhere
"""

import re
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent

VERSION_FILES: list[dict[str, Any]] = [
    {
        "path": "pyproject.toml",
        "pattern": r'^version\s*=\s*"([^"]+)"',
        "template": 'version = "{version}"',
        "label": "pyproject.toml",
    },
    {
        "path": "cli/Cargo.toml",
        "pattern": r'^version\s*=\s*"([^"]+)"',
        "template": 'version = "{version}"',
        "label": "cli/Cargo.toml",
    },
    {
        "path": "web/package.json",
        "pattern": r'"version"\s*:\s*"([^"]+)"',
        "template": None,
        "label": "web/package.json",
    },
    {
        "path": "cli/src/cli.rs",
        "pattern": r'#\[command\(version\s*=\s*"([^"]+)"\)\]',
        "template": '#[command(version = "{version}")]',
        "label": "cli/src/cli.rs",
    },
]

SOURCE_INDEX = 0  # pyproject.toml is source of truth


def read_version(filepath: Path) -> str:
    """Extract version from TOML file under the [project] section."""
    lines = filepath.read_text().splitlines()
    in_project_section = False

    for line in lines:
        if line.strip().startswith("[project]"):
            in_project_section = True
            continue
        elif in_project_section and line.strip().startswith("[") and line.strip() != "[project]":
            break

        if in_project_section:
            match = re.match(r'^version\s*=\s*"([^"]+)"', line)
            if match:
                return match.group(1)

    print(f"Error: Could not find version in {filepath}")
    sys.exit(1)
        version = args[idx + 1]
        if not re.match(r"^\d+\.\d+\.\d+$", version):
            print(f"Invalid version format: {version}")
            sys.exit(1)
        ok = fix_versions(version)
        sys.exit(0 if ok else 1)

    if "--fix" in args:
        ok = fix_versions()
        sys.exit(0 if ok else 1)

    print("=== Version Sync Check ===")
    _, all_match = check_versions()
    print()
    if all_match:
        print("✅ All versions in sync")
        sys.exit(0)
    else:
        print("❌ Version drift detected — run: python scripts/sync_versions.py --fix")
        sys.exit(1)


if __name__ == "__main__":
    main()
