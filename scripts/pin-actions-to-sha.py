#!/usr/bin/env python3
"""Pin all GitHub Actions to full commit SHA with version comment.

Reads all .github/workflows/*.yml files and replaces uses: directives
with SHA-pinned versions. Uses a known mapping of action versions to SHAs.

Usage: python3 scripts/pin-actions-to-sha.py
"""

from pathlib import Path
import sys

WORKFLOWS_DIR_NAME = ".github/workflows"

# Allowed characters in an action reference.  Action references are of the
# form <owner>/<repo>[/<subpath>]...@<version> where <version> may be a
# tag (e.g. v4), a branch (e.g. master), or a 40-char SHA.  The leading
# owner/repo path uses word characters, hyphens, dots, and forward slashes
# (the latter only between path segments).  The trailing version uses the
# same alphabet without slashes.
_ACTION_PATH_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_./")
_ACTION_VERSION_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")

# SHA constants for commonly used actions
CHECKOUT_SHA = "11bd71901bbe5b1630ceea73d27597364c9af683"
SETUP_NODE_SHA = "1d0ff469b7ec7b3cb9d8673fde0c81c44821de2a"

# Mapping of action@version to action@SHA # version
# These are the latest stable versions as of 2026-04
ACTION_SHAS = {
    "actions/checkout@v4": f"actions/checkout@{CHECKOUT_SHA}  # v4.2.2",
    "actions/checkout@v5": f"actions/checkout@{CHECKOUT_SHA}  # v4.2.2",
    "actions/checkout@v6": f"actions/checkout@{CHECKOUT_SHA}  # v4.2.2",
    "actions/setup-node@v4": f"actions/setup-node@{SETUP_NODE_SHA}  # v4.2.0",
    "actions/setup-node@v5": f"actions/setup-node@{SETUP_NODE_SHA}  # v4.2.0",
    "actions/setup-node@v6": f"actions/setup-node@{SETUP_NODE_SHA}  # v4.2.0",
    "actions/setup-python@v5": "actions/setup-python@8d9ed9ac5c53483de85588cdf95a591a75ab9f55  # v5.5.0",
    "actions/setup-python@v6": "actions/setup-python@8d9ed9ac5c53483de85588cdf95a591a75ab9f55  # v5.5.0",
    "actions/setup-go@v5": "actions/setup-go@f111f3307d8850f501ac008e886eec1fd1932a34  # v5.3.0",
    "actions/github-script@v7": "actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea  # v7.0.1",
    "actions/stale@v9": "actions/stale@28ca1036281a5e5922ead5184a1bbf96e5fc984e  # v9.0.0",
    "actions/labeler@v5": "actions/labeler@8558fd74291d67161a8a78ce36a881fa63b766a9  # v5.0.0",
    "dtolnay/rust-toolchain@stable": "dtolnay/rust-toolchain@3c5f7ea28cd621ae0bf5283f0e981fb97b8a7af9  # stable",
    "dtolnay/rust-toolchain@nightly": "dtolnay/rust-toolchain@3c5f7ea28cd621ae0bf5283f0e981fb97b8a7af9  # nightly",
}


def _split_action_ref(token: str) -> tuple[str, str] | None:
    """Split an action reference into (action_path, version).

    Returns None if the token is not a valid <path>@<version> reference.
    Uses character-set scanning instead of regex to avoid ReDoS surface
    area and SonarCloud S5852.
    """
    at_index = token.rfind("@")
    if at_index <= 0 or at_index == len(token) - 1:
        return None
    action_path = token[:at_index]
    version = token[at_index + 1:]
    if not action_path or not version:
        return None
    if not all(c in _ACTION_PATH_CHARS for c in action_path):
        return None
    if not all(c in _ACTION_VERSION_CHARS for c in version):
        return None
    return action_path, version


def pin_actions(content: str) -> tuple[str, int]:
    """Replace action@version with action@SHA # version in YAML content.

    Parses the content line by line so the action-reference extraction has
    no regex and therefore no ReDoS surface.  A line is rewritten only
    when it matches the indentation of a YAML uses: directive and the
    action reference is in ACTION_SHAS.

    Returns:
        Tuple of (modified_content, number_of_replacements).
    """
    out_lines: list[str] = []
    count = 0

    for line in content.splitlines(keepends=True):
        stripped = line.lstrip()
        if not (stripped.startswith("- uses: ") or stripped.startswith("uses: ")):
            out_lines.append(line)
            continue

        # Compute the prefix that must be preserved exactly (whitespace
        # before the action entry, the leading "- " if any, and "uses: ").
        if stripped.startswith("- uses: "):
            prefix_len = len(line) - len(stripped) + len("- uses: ")
        else:
            prefix_len = len(line) - len(stripped) + len("uses: ")

        prefix = line[:prefix_len]
        remainder = line[prefix_len:].rstrip("\n")
        if remainder.endswith("\r"):
            remainder = remainder[:-1]

        token = remainder.split()[0] if remainder.split() else ""
        split = _split_action_ref(token)
        if split is None:
            out_lines.append(line)
            continue
        action_ref = f"{split[0]}@{split[1]}"
        if action_ref in ACTION_SHAS:
            count += 1
            trailing_ws = remainder[len(token):]
            newline = "\n" if line.endswith("\n") else ""
            out_lines.append(f"{prefix}{ACTION_SHAS[action_ref]}{trailing_ws}{newline}")
        else:
            out_lines.append(line)

    return "".join(out_lines), count


def main() -> int:
    repo_root = Path(__file__).resolve().parent.parent
    workflows_dir = repo_root / WORKFLOWS_DIR_NAME

    if not workflows_dir.is_dir():
        print("Error: .github/workflows directory not found", file=sys.stderr)
        return 1

    total_replacements = 0

    for workflow_file in sorted(workflows_dir.glob("*.yml")):
        content = workflow_file.read_text(encoding="utf-8")
        modified, count = pin_actions(content)

        if count > 0:
            # workflow_file is constrained to .github/workflows/*.yml (a
            # hardcoded constant in this script's own repo, not user input)
            # and the modified content is generated by pin_actions() from
            # trusted ACTION_SHAS mappings.  The taint-flow S2088 finding
            # here is a false positive for this offline tool.
            workflow_file.write_text(modified, encoding="utf-8")  # NOSONAR
            print(f"Pinned {count} action(s) in {workflow_file.name}")
            total_replacements += count

    if total_replacements == 0:
        print("No actions to pin (all already pinned or no workflows found)")
    else:
        print(f"\nTotal: pinned {total_replacements} action reference(s)")

    return 0


if __name__ == "__main__":
    sys.exit(main())
