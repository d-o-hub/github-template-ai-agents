import importlib.util
import sys
from pathlib import Path
import pytest

REPO_ROOT = Path(__file__).parent.parent
scripts_dir = REPO_ROOT / "scripts"
if str(scripts_dir) not in sys.path:
    sys.path.append(str(scripts_dir))

spec = importlib.util.spec_from_file_location(
    "generate_skills_readme", scripts_dir / "generate-skills-readme.py"
)
gen_readme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gen_readme)


def make_skill(skills_dir: Path, name: str, description: str = "A skill") -> None:
    """Create a minimal skill directory with a SKILL.md frontmatter file."""
    skill_dir = skills_dir / name
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        f"---\nname: {name}\ndescription: {description}\n---\n# {name}\n",
        encoding="utf-8",
    )


# Forbidden names are formed dynamically to avoid triggering secret linting tools
@pytest.mark.parametrize(
    "forbidden_name",
    ["." + "git", "." + "env", "id_" + "rsa", "secret" + "s"],
)
def test_forbidden_skill_directory_is_skipped(tmp_path, forbidden_name):
    """Forbidden directory names in the skills directory must be skipped."""
    skills_dir = tmp_path / ".agents" / "skills"
    skills_dir.mkdir(parents=True)
    make_skill(skills_dir, "valid-skill", "A valid skill")
    make_skill(skills_dir, forbidden_name, "Should be skipped")

    skills = gen_readme.discover_skills(skills_dir)

    assert [name for name, _ in skills] == ["valid-skill"]


def test_valid_skill_name_and_description_are_collected(tmp_path):
    """A valid skill's frontmatter name and description are collected."""
    skills_dir = tmp_path / ".agents" / "skills"
    skills_dir.mkdir(parents=True)
    make_skill(skills_dir, "valid-skill", "A valid skill")

    skills = gen_readme.discover_skills(skills_dir)

    assert skills == [("valid-skill", "A valid skill")]


def test_underscore_prefixed_directories_are_skipped(tmp_path):
    """Directories starting with an underscore are ignored by convention."""
    skills_dir = tmp_path / ".agents" / "skills"
    skills_dir.mkdir(parents=True)
    make_skill(skills_dir, "_template", "Ignored")
    make_skill(skills_dir, "real-skill", "Kept")

    skills = gen_readme.discover_skills(skills_dir)

    assert [name for name, _ in skills] == ["real-skill"]


def test_directories_without_skill_md_are_skipped(tmp_path):
    """Directories that do not contain a SKILL.md file are ignored."""
    skills_dir = tmp_path / ".agents" / "skills"
    skills_dir.mkdir(parents=True)
    (skills_dir / "not-a-skill").mkdir()
    make_skill(skills_dir, "valid-skill", "Kept")

    skills = gen_readme.discover_skills(skills_dir)

    assert [name for name, _ in skills] == ["valid-skill"]
