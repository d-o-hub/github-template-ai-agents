#!/usr/bin/env python3
import os
import sys
import tomllib

def validate_toml(filepath):
    """Robust TOML validator for Gemini CLI commands using tomllib."""
    try:
        with open(filepath, 'rb') as f:
            data = tomllib.load(f)

        # Check for description
        if 'description' not in data:
            print(f"Error: {filepath} is missing 'description' field")
            return False

        # Check for prompt
        if 'prompt' not in data:
            print(f"Error: {filepath} is missing 'prompt' field")
            return False

        if not isinstance(data['description'], str):
            print(f"Error: {filepath} 'description' must be a string")
            return False

        if not isinstance(data['prompt'], str):
            print(f"Error: {filepath} 'prompt' must be a string")
            return False

        return True
    except tomllib.TOMLDecodeError as e:
        print(f"Error: {filepath} has invalid TOML syntax: {e}")
        return False
    except Exception as e:
        print(f"Error reading {filepath}: {e}")
        return False

def main():
    commands_dir = ".gemini/commands"
    if not os.path.exists(commands_dir):
        print(f"Directory {commands_dir} not found. Skipping validation.")
        return 0

    success = True
    toml_files = [f for f in os.listdir(commands_dir) if f.endswith(".toml")]

    if not toml_files:
        print(f"No TOML files found in {commands_dir}")
        return 0

    for filename in toml_files:
        filepath = os.path.join(commands_dir, filename)
        if not validate_toml(filepath):
            success = False

    if not success:
        sys.exit(1)

    print(f"✓ {len(toml_files)} Gemini TOML commands valid")
    return 0

if __name__ == "__main__":
    sys.exit(main())
