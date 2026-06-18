#!/usr/bin/env python3
"""Initialize a new agent skill with full directory structure and templates."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


SKILL_MD_TEMPLATE = """---
name: {skill_name}
description: {description}
version: "0.1.0"
category: general
---

# {skill_name_title}

Brief overview of skill purpose and scope.

## When to Use

- Scenario 1: Specific situation where this skill applies
- Scenario 2: Specific situation where this skill applies
- Scenario 3: Specific situation where this skill applies

## Process

### Step 1: [Action]

Clear instructions for this step.

### Step 2: [Action]

Clear instructions for this step.

## Examples

### Example 1: [Name]

```
Example workflow or code
```

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Excuse 1" | Why this excuse is wrong. |
| "Excuse 2" | Why this excuse is wrong. |

## Red Flags

- [ ] Red flag 1 to watch for
- [ ] Red flag 2 to watch for

## Reference Files

- `references/guide.md` - Additional documentation
"""

EVALS_TEMPLATE = {
    "skill_name": "{skill_name}",
    "evals": [
        {
            "id": 1,
            "prompt": "User asks about {description_lower}",
            "expected_output": "Description of expected behavior for this test case",
            "files": [],
            "assertions": [
                "The output includes guidance on the topic",
                "The output provides actionable steps",
            ],
        },
        {
            "id": 2,
            "prompt": "I need help with a specific problem related to {description_lower}",
            "expected_output": "Agent provides detailed step-by-step solution",
            "files": [],
            "assertions": [
                "The output addresses the specific problem",
                "The output includes concrete steps",
            ],
        },
        {
            "id": 3,
            "prompt": "Explain how to handle edge cases in {description_lower}",
            "expected_output": "Agent mentions edge cases and how to handle them",
            "files": [],
            "assertions": [
                "The output discusses at least one edge case",
                "The output provides handling strategies",
            ],
        },
    ],
}

EXAMPLE_SCRIPT = """#!/usr/bin/env python3
\"\"\"Example helper script for {skill_name} skill.\"\"\"
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Example script for {skill_name}")
    parser.add_argument("path", type=str, help="Path to a directory to list")
    args = parser.parse_args()

    target_path = Path(args.path)
    if not target_path.exists():
        print(f"Error: Path '{target_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    print(f"Contents of '{target_path.absolute()}':")
    for item in target_path.iterdir():
        type_str = "DIR" if item.is_dir() else "FILE"
        print(f"  [{type_str}] {item.name}")


if __name__ == "__main__":
    main()
"""

GUIDE_TEMPLATE = """# {skill_name_title} Reference Guide

Additional documentation for the {skill_name} skill.

## Overview

Brief description of what this reference covers.

## Common Patterns

### Pattern 1

Description and usage guidance.

### Pattern 2

Description and usage guidance.

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Issue description | Root cause | How to resolve |
"""


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Initialize a new agent skill with full directory structure"
    )
    parser.add_argument("--skill-name", "-n", type=str, required=True,
                        help="Name of the skill (lowercase, hyphens only)")
    parser.add_argument("--description", "-d", type=str, required=True,
                        help="Description of the skill (1024 chars max)")
    parser.add_argument("--base-path", "-p", type=str, default=".",
                        help="Base path for the new skill (default: current dir)")
    args = parser.parse_args()

    skill_name = args.skill_name
    description = args.description
    description_lower = description.lower().split(".")[0] if "." in description else description.lower()
    if len(description_lower) > 60:
        description_lower = description_lower[:57] + "..."

    skill_path = Path(args.base_path) / skill_name

    # Validate skill name format
    if not skill_name.replace("-", "").isalnum():
        print("Error: skill name must be lowercase with hyphens only (e.g., 'my-skill')",
              file=sys.stderr)
        sys.exit(1)

    if skill_path.exists():
        print(f"Error: directory already exists: {skill_path}", file=sys.stderr)
        sys.exit(1)

    # Create directory structure
    dirs = [
        skill_path,
        skill_path / "scripts",
        skill_path / "references",
        skill_path / "evals",
        skill_path / "assets",
        skill_path / "agents",
    ]
    for d in dirs:
        d.mkdir(parents=True, exist_ok=True)

    # Write SKILL.md
    skill_md_path = skill_path / "SKILL.md"
    skill_md_path.write_text(
        SKILL_MD_TEMPLATE.format(
            skill_name=skill_name,
            skill_name_title=skill_name.replace("-", " ").title(),
            description=description,
        ),
        encoding="utf-8",
    )
    print(f"Created: {skill_md_path}")

    # Write evals/evals.json
    evals_json = json.dumps(
        EVALS_TEMPLATE,
        indent=2,
        ensure_ascii=False,
    ).replace("{skill_name}", skill_name).replace("{description_lower}", description_lower)

    evals_path = skill_path / "evals" / "evals.json"
    evals_path.write_text(evals_json, encoding="utf-8")
    print(f"Created: {evals_path}")

    # Write scripts/example.py
    example_path = skill_path / "scripts" / "example.py"
    example_path.write_text(
        EXAMPLE_SCRIPT.format(skill_name=skill_name),
        encoding="utf-8",
    )
    example_path.chmod(0o755)
    print(f"Created: {example_path}")

    # Write references/guide.md
    guide_path = skill_path / "references" / "guide.md"
    guide_path.write_text(
        GUIDE_TEMPLATE.format(
            skill_name=skill_name,
            skill_name_title=skill_name.replace("-", " ").title(),
        ),
        encoding="utf-8",
    )
    print(f"Created: {guide_path}")

    # Write .gitkeep in empty dirs
    for empty_dir in [skill_path / "assets", skill_path / "agents"]:
        gitkeep = empty_dir / ".gitkeep"
        gitkeep.write_text("", encoding="utf-8")

    print(f"\nSkill '{skill_name}' initialized at {skill_path.absolute()}")
    print("\nNext steps:")
    print(f"  1. Edit {skill_md_path} with real instructions and examples")
    print(f"  2. Update {evals_path} with realistic test cases")
    print(f"  3. Run validation: python -m scripts.package_skill {skill_path}")


if __name__ == "__main__":
    main()
