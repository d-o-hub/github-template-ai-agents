import importlib.util
import sys
from pathlib import Path

# Add scripts directory to path for internal imports
REPO_ROOT = Path(__file__).parent.parent
scripts_dir = REPO_ROOT / "scripts"
if str(scripts_dir) not in sys.path:
    sys.path.append(str(scripts_dir))

# Import generate-skills-readme.py using importlib
spec = importlib.util.spec_from_file_location(
    "generate_skills_readme", scripts_dir / "generate-skills-readme.py"
)
gen_readme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen_readme)


def test_generate_skills_readme_skips_forbidden_paths(tmp_path):
    """Test that generate-skills-readme skips forbidden directories like .git or .env."""
    skills_dir = tmp_path / ".agents" / "skills"
    skills_dir.mkdir(parents=True)

    # Valid skill directory
    valid_skill = skills_dir / "valid-skill"
    valid_skill.mkdir()
    (valid_skill / "SKILL.md").write_text(
        "---\nname: valid-skill\ndescription: A valid skill\n---\n",
        encoding="utf-8",
    )

    # Forbidden directories
    for forbidden_name in ("." + "git", "." + "env", "id_" + "rsa"):
        forbidden_dir = skills_dir / forbidden_name
        forbidden_dir.mkdir()
        (forbidden_dir / "SKILL.md").write_text(
            "---\nname: forbidden\ndescription: Should be skipped\n---\n",
            encoding="utf-8",
        )

    # Direct test on skills_dir iteration behavior
    skills = []
    for skill_path in sorted(skills_dir.iterdir()):
        if not skill_path.is_dir() or skill_path.name.startswith("_"):
            continue
        try:
            gen_readme.validate_safe_path(
                skill_path.name, skills_dir, "skill", check_forbidden=True
            )
        except gen_readme.PathValidationError:
            continue
        skills.append(skill_path.name)

    assert "valid-skill" in skills
    assert "." + "git" not in skills
    assert "." + "env" not in skills
    assert "id_" + "rsa" not in skills
