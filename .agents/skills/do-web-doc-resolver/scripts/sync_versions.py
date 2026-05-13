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


def read_version(entry: dict[str, str]) -> str | None:
    """Extract version string from a file using its regex pattern."""
    filepath = ROOT / entry["path"]
    if not filepath.exists():
        return None
    text = filepath.read_text()
    for line in text.splitlines():
        m = re.search(entry["pattern"], line)
        if m:
            return m.group(1)
    return None


def write_version_toml(filepath: Path, new_version: str) -> None:
    """Update the first `version = "..."` line in a TOML file."""
    lines = filepath.read_text().splitlines(keepends=True)
    replaced = False
    for i, line in enumerate(lines):
        if not replaced and re.match(r'^version\s*=\s*"', line):
            lines[i] = f'version = "{new_version}"\n'
            replaced = True
            break
    filepath.write_text("".join(lines))


def write_version_json(filepath: Path, new_version: str) -> None:
    """Update version in a JSON file (preserves formatting)."""
    text = filepath.read_text()
    updated = re.sub(
        r'("version"\s*:\s*)"[^"]+"',
        rf'\1"{new_version}"',
        text,
        count=1,
    )
    filepath.write_text(updated)


def write_version_rs(filepath: Path, new_version: str) -> None:
    """Update #[command(version = "...")] in a Rust source file."""
    text = filepath.read_text()
    updated = re.sub(
        r'#\[command\(version\s*=\s*"[^"]+"\)\]',
        f'#[command(version = "{new_version}")]',
        text,
        count=1,
    )
    filepath.write_text(updated)


def write_version(entry: dict[str, str], new_version: str) -> None:
    """Write version to the appropriate file type."""
    filepath = ROOT / entry["path"]
    if entry["path"].endswith(".json"):
        write_version_json(filepath, new_version)
    elif entry["path"].endswith(".rs"):
        write_version_rs(filepath, new_version)
    else:
        write_version_toml(filepath, new_version)


def check_versions() -> tuple[dict[str, str | None], bool]:
    """Read all versions and check if they match the source of truth."""
    versions: dict[str, str | None] = {}
    for entry in VERSION_FILES:
        versions[entry["label"]] = read_version(entry)

    source_label = VERSION_FILES[SOURCE_INDEX]["label"]
    source_version = versions[source_label]
    if source_version is None:
        print(f"❌ Cannot read source of truth: {source_label}")
        return versions, False

    all_match = True
    for label, ver in versions.items():
        if ver is None:
            print(f"⚠️  {label}: file not found")
            all_match = False
        elif ver == source_version:
            print(f"✅ {label}: {ver}")
        else:
            print(f"❌ {label}: {ver} (expected {source_version})")
            all_match = False

    return versions, all_match


def fix_versions(target_version: str | None = None) -> bool:
    """Sync all files to the source version or a specified version."""
    if target_version is None:
        target_version = read_version(VERSION_FILES[SOURCE_INDEX])

    if not target_version:
        print("❌ Cannot determine version from source of truth")
        return False

    print(f"Setting all versions to: {target_version}")
    for entry in VERSION_FILES:
        filepath = ROOT / entry["path"]
        if not filepath.exists():
            print(f"⚠️  {entry['label']}: file not found, skipping")
            continue
        current = read_version(entry)
        if current == target_version:
            print(f"  ✅ {entry['label']}: already {target_version}")
        else:
            write_version(entry, target_version)
            print(f"  🔧 {entry['label']}: {current} → {target_version}")

    return True


def main() -> None:
    """CLI entrypoint."""
    args = sys.argv[1:]

    if "--set" in args:
        idx = args.index("--set")
        if idx + 1 >= len(args):
            print("Usage: sync_versions.py --set <version>")
            sys.exit(1)
        version = args[idx + 1]
        if not re.match(r"^\d+\.\d+\.\d+", version):
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
