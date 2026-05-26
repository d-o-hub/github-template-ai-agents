import json
import os
import sys

def validate_schema():
    schema_path = 'agents-docs/handoff-schema.json'
    if not os.path.exists(schema_path):
        print(f"Error: {schema_path} not found")
        sys.exit(1)

    try:
        from jsonschema import validate, ValidationError
    except ImportError:
        print("jsonschema not found, skipping deep validation. Just checking JSON syntax.")
        try:
            with open(schema_path, 'r') as f:
                json.load(f)
            print("Schema JSON syntax OK")
            return
        except Exception as e:
            print(f"Error: Invalid JSON syntax in schema: {e}")
            sys.exit(1)

    with open(schema_path, 'r') as f:
        schema = json.load(f)

    valid_payload = {
        "version": "1.0.0",
        "timestamp": "2026-05-26T19:00:00Z",
        "sourceAgent": "source-agent",
        "targetAgent": "target-agent",
        "context": {"key": "value"},
        "artifacts": [
            {"path": "file.txt", "type": "created", "summary": "Created file"}
        ],
        "decisions": [
            {"topic": "architecture", "decision": "use-pattern", "rationale": "Better stability"}
        ],
        "nextSteps": ["Verify changes"]
    }

    invalid_payload = {
        "version": "1.0.0"
        # Missing required fields
    }

    try:
        validate(instance=valid_payload, schema=schema)
        print("✓ Valid payload passed validation")
    except ValidationError as e:
        print(f"✗ Error: Valid payload failed validation: {e}")
        sys.exit(1)

    try:
        validate(instance=invalid_payload, schema=schema)
        print("✗ Error: Invalid payload passed validation")
        sys.exit(1)
    except ValidationError:
        print("✓ Invalid payload correctly rejected")

if __name__ == "__main__":
    validate_schema()
