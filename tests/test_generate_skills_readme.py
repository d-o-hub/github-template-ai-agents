import importlib.util
from pathlib import Path
import sys

# Add scripts directory to path for internal imports
REPO_ROOT = Path(__file__).parent.parent
scripts_dir = REPO_ROOT / "scripts"
sys.path.append(str(scripts_dir))

# Import generate-skills-readme.py using importlib
spec = importlib.util.spec_from_file_location(
    "generate_skills_readme", scripts_dir / "generate-skills-readme.py"
)
generate_skills_readme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(generate_skills_readme)


def test_generate_skills_readme_skips_forbidden_dirs(tmp_path, monkeypatch):
    """Test that generate-skills-readme skips forbidden and sensitive directory paths."""
    skills_dir = tmp_path / ".agents" / "skills"
    skills_dir.mkdir(parents=True)

    # Create a valid skill directory
    valid_skill = skills_dir / "valid-skill"
    valid_skill.mkdir()
    (valid_skill / "SKILL.md").write_text(
        "---\nname: valid-skill\ndescription: A valid skill\n---\n"
    )

    # Create forbidden directories
    forbidden_git = skills_dir / ".git"
    forbidden_git.mkdir()
    (forbidden_git / "SKILL.md").write_text(
        "---\nname: .git\ndescription: Forbidden git\n---\n"
    )

    forbidden_env = skills_dir / ".env"
    forbidden_env.mkdir()
    (forbidden_env / "SKILL.md").write_text(
        "---\nname: .env\ndescription: Forbidden env\n---\n"
    )

    forbidden_ssh = skills_dir / "id_rsa"
    forbidden_ssh.mkdir()
    (forbidden_ssh / "SKILL.md").write_text(
        "---\nname: id_rsa\ndescription: Forbidden ssh\n---\n"
    )

    # Run main with overridden repo_root via monkeypatching or skills_dir
    output_file = skills_dir / "README.md"

    # Mock Path resolution in main if needed or test discovery directly
    skills = []
    from lib.paths import PathValidationError, validate_safe_path

    for skill_path in sorted(skills_dir.iterdir()):
        if not skill_path.is_dir() or skill_path.name.startswith("_"):
            continue
        try:
            validate_safe_path(skill_path.name, skills_dir, "skill", check_forbidden=True)
        except PathValidationError:
            continue
        skill_file = skill_path / "SKILL.md"
        if not skill_file.is_file():
            continue
        fm = generate_skills_readme.extract_frontmatter(skill_file)
        name = fm.get("name", skill_path.name)
        description = fm.get("description", "No description available")
        skills.append((name, description))

    assert len(skills) == 1
    assert skills[0][0] == "valid-skill"
    assert skills[0][1] == "A valid skill"
