#!/usr/bin/env python3
"""Validate that skill symlinks in .blackbox/skills/, .claude/skills/, .opencode/skills/ point to .agents/skills/."""

import sys
from pathlib import Path


def validate_skill_symlinks():
    """Ensure all skill directory symlinks point to .agents/skills/."""
    root_dir = Path(__file__).parent.parent
    canonical_skills = root_dir / ".agents" / "skills"

    if not canonical_skills.exists():
        print(f"❌ Canonical skills directory does not exist: {canonical_skills}")
        sys.exit(1)

    symlink_dirs = [".blackbox", ".claude", ".opencode"]
    all_valid = True
    total_checked = 0

    for symlink_dir_name in symlink_dirs:
        skills_dir = root_dir / symlink_dir_name / "skills"
        name = f"{symlink_dir_name}/skills"

        if not skills_dir.exists() and not skills_dir.is_symlink():
            print(f"⚠️  {name}: Not found at {skills_dir}")
            continue

        if not skills_dir.is_symlink():
            print(f"❌ {name}: Not a symlink (should be symlink to .agents/skills/)")
            all_valid = False
            total_checked += 1
            continue

        resolved_target = skills_dir.resolve()
        resolved_expected = canonical_skills.resolve()

        if resolved_target != resolved_expected:
            print(f"❌ {name}: Points to wrong target")
            print(f"   Expected: {resolved_expected}")
            print(f"   Got:      {resolved_target}")
            all_valid = False
        else:
            print(f"✅ {name}: Valid → {resolved_target}")

        total_checked += 1

    print()
    if all_valid:
        print(f"✅ PASS: All {total_checked} skill directory symlinks are valid")
        return True
    else:
        print("❌ FAIL: Some skill symlinks are invalid")
        sys.exit(1)


if __name__ == "__main__":
    validate_skill_symlinks()
