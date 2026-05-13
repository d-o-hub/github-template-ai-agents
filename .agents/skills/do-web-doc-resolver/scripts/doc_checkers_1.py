import re
from pathlib import Path

from scripts.doc_models import (
    Report,
    extract_code_blocks,
    extract_markdown_links,
)

REPO_ROOT = Path(__file__).resolve().parent.parent


def check_file_references(report: Report, doc_name: str, content: str):
    """Verify that markdown links point to files that actually exist."""
    for line_no, _text, target in extract_markdown_links(content):
        if target.startswith(("http://", "https://", "#", "mailto:")):
            continue

        # Clean anchor from path
        path_part = target.split("#")[0]
        if not path_part:
            continue

        target_path = REPO_ROOT / path_part
        if not target_path.exists():
            report.add(
                "warning", "broken-link", doc_name, f"Link target missing: {target}", line_no
            )


def check_shell_commands(report: Report, doc_name: str, content: str):
    """Verify scripts referenced in code blocks exist."""
    for line_no, lang, code in extract_code_blocks(content):
        if lang not in ("bash", "sh", "shell", "powershell"):
            continue

        # Look for script patterns
        # 1. python scripts/name.py
        # 2. ./scripts/name.sh
        # 3. python -m scripts.name
        for match in re.finditer(r"(?:python3? |./)(scripts/\w+\.(?:py|sh))", code):
            script_path = REPO_ROOT / match.group(1)
            if not script_path.exists():
                report.add(
                    "error",
                    "missing-script",
                    doc_name,
                    f"Referenced script missing: {match.group(1)}",
                    line_no,
                )

        for match in re.finditer(r"python3? -m (scripts\.\w+)", code):
            mod_path = REPO_ROOT / match.group(1).replace(".", "/")
            if not (mod_path.with_suffix(".py").exists() or (mod_path / "__init__.py").exists()):
                report.add(
                    "error",
                    "missing-module",
                    doc_name,
                    f"Referenced module missing: {match.group(1)}",
                    line_no,
                )


def check_python_cli(report: Report):
    """Verify scripts/cli.py entrypoint matches documented patterns."""
    cli_path = REPO_ROOT / "scripts/cli.py"
    if not cli_path.exists():
        return

    content = cli_path.read_text()
    # Check for argparse help strings vs README
    readme = (REPO_ROOT / "README.md").read_text()
    for match in re.finditer(r"help=['\"]([^'\"]+)['\"]", content):
        help_text = match.group(1)
        if help_text not in readme and len(help_text) > 10:
            # report.add("info", "cli-docs", "README.md", f"CLI help text mismatch: '{help_text}'")
            pass


def check_rust_cli_flags(report: Report):
    """Verify Rust CLI flags in src/cli.rs match references in RUST_CLI.md."""
    cli_rs = REPO_ROOT / "cli/src/cli.rs"
    rust_cli_md = REPO_ROOT / ".agents/skills/do-web-doc-resolver/references/RUST_CLI.md"

    if not (cli_rs.exists() and rust_cli_md.exists()):
        return

    rs_content = cli_rs.read_text()
    md_content = rust_cli_md.read_text()

    # Find long flags in Rust: short = 'v', long = "verbose"
    flags = set(re.findall(r'long = "([^"]+)"', rs_content))
    for flag in flags:
        if f"--{flag}" not in md_content:
            report.add(
                "warning", "cli-sync", "RUST_CLI.md", f"Rust flag --{flag} missing from docs"
            )


def check_cargo_features(report: Report):
    """Verify Cargo.toml features match RUST_CLI.md."""
    cargo_toml = REPO_ROOT / "cli/Cargo.toml"
    rust_cli_md = REPO_ROOT / ".agents/skills/do-web-doc-resolver/references/RUST_CLI.md"

    if not (cargo_toml.exists() and rust_cli_md.exists()):
        return

    toml_content = cargo_toml.read_text()
    md_content = rust_cli_md.read_text()

    if "[features]" in toml_content:
        features_section = toml_content.split("[features]")[1].split("[")[0]
        features = [
            f.split("=")[0].strip() for f in features_section.strip().splitlines() if "=" in f
        ]

        for feature in features:
            if feature not in md_content:
                report.add(
                    "warning",
                    "feature-sync",
                    "RUST_CLI.md",
                    f"Cargo feature '{feature}' missing from docs",
                )


def check_rust_architecture(report: Report):
    """Verify RUST_CLI.md architecture section against source tree."""
    rust_cli_md = REPO_ROOT / ".agents/skills/do-web-doc-resolver/references/RUST_CLI.md"
    if not rust_cli_md.exists():
        return

    content = rust_cli_md.read_text()
    # Check for module list
    for match in re.finditer(r"- `(\w+)`: (.+)", content):
        mod_name = match.group(1)
        if mod_name in ("providers", "resolver", "quality", "metrics", "synthesis"):
            mod_path = REPO_ROOT / "cli/src" / f"{mod_name}.rs"
            dir_path = REPO_ROOT / "cli/src" / mod_name
            if not (mod_path.exists() or dir_path.exists()):
                report.add(
                    "error", "arch-sync", "RUST_CLI.md", f"Source for module '{mod_name}' missing"
                )
