#!/usr/bin/env python3
import os
import sys

try:
    import tomllib  # Python 3.11+
except ModuleNotFoundError:  # pragma: no cover - Python < 3.11
    try:
        import tomli as tomllib  # type: ignore
    except ModuleNotFoundError:
        print(
            "Error: need Python 3.11+ (tomllib) or the 'tomli' package to validate Gemini TOML",
            file=sys.stderr,
        )
        sys.exit(2)

# tomllib / tomli decode errors
try:
    TOMLDecodeError = tomllib.TOMLDecodeError  # type: ignore[attr-defined]
except AttributeError:  # pragma: no cover
    TOMLDecodeError = ValueError


def validate_gemini_toml(filepath, required_fields):
    """Robust TOML validator for Gemini CLI files using tomllib/tomli."""
    try:
        with open(filepath, "rb") as f:
            data = tomllib.load(f)

        for field in required_fields:
            if field not in data:
                print(f"Error: {filepath} is missing '{field}' field")
                return False
            if not isinstance(data[field], (str, list)):
                print(f"Error: {filepath} '{field}' must be a string or list")
                return False

        return True
    except TOMLDecodeError as e:
        print(f"Error: {filepath} has invalid TOML syntax: {e}")
        return False
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return False


def _validate_dir(dirname, required_fields):
    """Validate all TOML files in a directory. Returns (all_valid, count)."""
    if not os.path.exists(dirname):
        return True, 0
    toml_files = [f for f in os.listdir(dirname) if f.endswith(".toml")]
    all_valid = True
    count = 0
    for filename in toml_files:
        filepath = os.path.join(dirname, filename)
        if not validate_gemini_toml(filepath, required_fields):
            all_valid = False
        else:
            count += 1
    return all_valid, count


def main() -> int:
    commands_ok, commands_count = _validate_dir(".gemini/commands", ['description', 'prompt'])
    agents_ok, agents_count = _validate_dir(".gemini/agents", ['name', 'description', 'prompt'])
    success = commands_ok and agents_ok
    total_validated = commands_count + agents_count

    if not success:
        sys.exit(1)

    if total_validated > 0:
        print(f"✓ {total_validated} Gemini TOML files valid")
    else:
        print("No Gemini TOML files found to validate.")

    return 0

if __name__ == "__main__":
    sys.exit(main())
