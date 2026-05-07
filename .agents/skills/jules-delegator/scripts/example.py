import argparse
from pathlib import Path

def main():
    """Main entry point for the example script."""
    parser = argparse.ArgumentParser(description="Example script for jules-delegator")
    parser.add_argument("path", type=str, help="Path to a directory to list")
    args = parser.parse_args()

    target_path = Path(args.path)
    if not target_path.exists():
        print(f"Error: Path '{target_path}' does not exist.")
        return

    print(f"Listing contents of '{target_path.absolute()}':")
    for item in target_path.iterdir():
        type_str = "DIR " if item.is_dir() else "FILE"
        print(f"  [{type_str}] {item.name}")

if __name__ == "__main__":
    main()
