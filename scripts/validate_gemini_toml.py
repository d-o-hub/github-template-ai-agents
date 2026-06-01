#!/usr/bin/env python3
import os
import sys
import tomllib

def validate_gemini_toml(filepath, required_fields):
    """Robust TOML validator for Gemini CLI files using tomllib."""
    try:
        with open(filepath, 'rb') as f:
            data = tomllib.load(f)

        for field in required_fields:
            if field not in data:
                print(f"Error: {filepath} is missing '{field}' field")
                return False
            if not isinstance(data[field], (str, list)):
                print(f"Error: {filepath} '{field}' must be a string or list")
                return False

        return True
    except tomllib.TOMLDecodeError as e:
        print(f"Error: {filepath} has invalid TOML syntax: {e}")
        return False
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return False

def main() -> int:
    success = True
    total_validated = 0

    # Validate commands
    commands_dir = ".gemini/commands"
    if os.path.exists(commands_dir):
        toml_files = [f for f in os.listdir(commands_dir) if f.endswith(".toml")]
        for filename in toml_files:
            filepath = os.path.join(commands_dir, filename)
            if not validate_gemini_toml(filepath, ['description', 'prompt']):
                success = False
            else:
                total_validated += 1

    # Validate agents
    agents_dir = ".gemini/agents"
    if os.path.exists(agents_dir):
        toml_files = [f for f in os.listdir(agents_dir) if f.endswith(".toml")]
        for filename in toml_files:
            filepath = os.path.join(agents_dir, filename)
            if not validate_gemini_toml(filepath, ['name', 'description', 'prompt']):
                success = False
            else:
                total_validated += 1

    if not success:
        sys.exit(1)

    if total_validated > 0:
        print(f"✓ {total_validated} Gemini TOML files valid")
    else:
        print("No Gemini TOML files found to validate.")

    return 0

if __name__ == "__main__":
    sys.exit(main())
