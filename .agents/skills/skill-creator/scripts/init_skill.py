import argparse
from pathlib import Path

# Template for the example script that will be generated for new skills.
# Curly braces for f-strings are escaped with double curly braces to survive .format()
EXAMPLE_SCRIPT = """import argparse
from pathlib import Path

def main():
    \"\"\"Main entry point for the example script.\"\"\"
    parser = argparse.ArgumentParser(description="Example script for {skill_name}")
    parser.add_argument("path", type=str, help="Path to a directory to list")
    args = parser.parse_args()

    target_path = Path(args.path)
    if not target_path.exists():
        print(f"Error: Path '{{target_path}}' does not exist.")
        return

    print(f"Listing contents of '{{target_path.absolute()}}':")
    for item in target_path.iterdir():
        type_str = "DIR " if item.is_dir() else "FILE"
        print(f"  [{{type_str}}] {{item.name}}")

if __name__ == "__main__":
    main()
"""

def main():
    """Main entry point for the skill initialization script."""
    parser = argparse.ArgumentParser(description="Initialize a new agent skill structure")
    parser.add_argument("skill_name", type=str, help="Name of the skill to initialize")
    parser.add_argument("--base-path", type=str, default=".", help="Base path for the new skill")
    args = parser.parse_args()

    skill_name = args.skill_name
    skill_path = Path(args.base_path) / skill_name
    scripts_path = skill_path / "scripts"

    print(f"Initializing skill '{skill_name}' at {skill_path.absolute()}")

    # Create directory structure
    scripts_path.mkdir(parents=True, exist_ok=True)
    (skill_path / "evals").mkdir(exist_ok=True)
    (skill_path / "references").mkdir(exist_ok=True)

    # Create SKILL.md placeholder
    skill_md = skill_path / "SKILL.md"
    if not skill_md.exists():
        skill_md.write_text(f"---\nname: {skill_name}\ndescription: Auto-generated skill\n---\n\n# {skill_name}\n")

    # Write the example script (idempotent)
    example_py = scripts_path / "example.py"
    if not example_py.exists():
        example_py.write_text(EXAMPLE_SCRIPT.format(skill_name=skill_name))
        print(f"✓ Created {example_py}")
    else:
        print(f"  skip (exists): {example_py}")
    print(f"✓ Skill structure initialized successfully.")

if __name__ == "__main__":
    main()
