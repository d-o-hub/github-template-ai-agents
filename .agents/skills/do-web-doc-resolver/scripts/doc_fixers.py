from pathlib import Path

from scripts.doc_models import Report

REPO_ROOT = Path(__file__).resolve().parent.parent


def fix_python_cli(report: Report) -> int:
    """Example fixer for Python CLI docs."""
    return 0


def fix_cargo_features(report: Report) -> int:
    """Auto-update RUST_CLI.md with missing Cargo features."""
    fixed = 0
    issues = [i for i in report.issues if i.category == "feature-sync"]
    if not issues:
        return 0

    cargo_toml = REPO_ROOT / "cli/Cargo.toml"
    rust_cli_md = REPO_ROOT / ".agents/skills/do-web-doc-resolver/references/RUST_CLI.md"

    toml_content = cargo_toml.read_text()
    features_section = toml_content.split("[features]")[1].split("[")[0]
    all_features = [
        f.split("=")[0].strip() for f in features_section.strip().splitlines() if "=" in f
    ]

    md_content = rust_cli_md.read_text()
    if "## Features" in md_content:
        # Simple implementation: append missing features to the list
        lines = md_content.splitlines()
        feature_idx = -1
        for i, line in enumerate(lines):
            if "## Features" in line:
                feature_idx = i
                break

        if feature_idx != -1:
            for feature in all_features:
                if feature not in md_content:
                    lines.insert(feature_idx + 2, f"- `{feature}`: [Description needed]")
                    fixed += 1

            if fixed > 0:
                rust_cli_md.write_text("\n".join(lines))

    return fixed


def fix_duplicate_links(report: Report) -> int:
    """Remove duplicate links from README.md."""
    return 0


def fix_repo_trees(report: Report) -> int:
    """Auto-fix repository trees in documentation."""
    return 0


def fix_rust_architecture(report: Report) -> int:
    """Sync RUST_CLI.md architecture with actual file tree."""
    fixed = 0
    issues = [i for i in report.issues if i.category == "arch-sync"]
    if not issues:
        return 0

    # Logic to update module descriptions based on filesystem
    return fixed
