"""Tests for the agent-to-agent handoff JSON schema.

This suite replaces ``tests/test-handoff-schema.py``, a ``validate_schema()`` script that
CI never ran: the hyphenated name keeps pytest's ``test_*.py`` default from collecting it,
and no function inside starts with ``test_`` either, so renaming alone would still have
yielded zero tests. The structural checks below run on stdlib alone; the draft-07
validation checks need ``jsonschema`` and skip when it is absent.
"""

import json
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCHEMA_PATH = REPO_ROOT / "agents-docs" / "handoff-schema.json"

REQUIRED_FIELDS = [
    "version",
    "timestamp",
    "sourceAgent",
    "targetAgent",
    "context",
    "artifacts",
    "decisions",
    "nextSteps",
]

VALID_PAYLOAD = {
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
    "nextSteps": ["Verify changes"],
}


@pytest.fixture(scope="module")
def schema():
    assert SCHEMA_PATH.is_file(), f"{SCHEMA_PATH} is consumed by the handoff protocol"
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def test_schema_parses_and_declares_draft_07(schema):
    assert schema["$schema"].endswith("draft-07/schema#")
    assert schema["type"] == "object"


def test_every_handoff_field_is_required_and_described(schema):
    assert sorted(schema["required"]) == sorted(REQUIRED_FIELDS)
    properties = schema["properties"]
    missing = [name for name in REQUIRED_FIELDS if name not in properties]
    assert not missing, f"required without a property definition: {missing}"
    undocumented = [name for name, spec in properties.items() if "description" not in spec]
    assert not undocumented, f"properties without a description: {undocumented}"


def test_nested_items_carry_their_own_requirements(schema):
    artifacts = schema["properties"]["artifacts"]["items"]
    assert artifacts["type"] == "object"
    assert sorted(artifacts["required"]) == ["path", "summary", "type"]
    assert sorted(artifacts["properties"]["type"]["enum"]) == [
        "created",
        "deleted",
        "modified",
        "reference",
    ]
    decisions = schema["properties"]["decisions"]["items"]
    assert sorted(decisions["required"]) == ["decision", "rationale", "topic"]
    assert schema["properties"]["nextSteps"]["items"]["type"] == "string"


def test_valid_payload_conforms(schema):
    jsonschema = pytest.importorskip("jsonschema")
    jsonschema.validate(instance=VALID_PAYLOAD, schema=schema)


@pytest.mark.parametrize("omitted", REQUIRED_FIELDS)
def test_payload_missing_a_required_field_is_rejected(schema, omitted):
    jsonschema = pytest.importorskip("jsonschema")
    payload = {key: value for key, value in VALID_PAYLOAD.items() if key != omitted}
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=payload, schema=schema)


@pytest.mark.parametrize(
    ("section", "key"),
    [("artifacts", "path"), ("artifacts", "type"), ("artifacts", "summary"),
     ("decisions", "topic"), ("decisions", "decision"), ("decisions", "rationale")],
)
def test_incomplete_nested_item_is_rejected(schema, section, key):
    jsonschema = pytest.importorskip("jsonschema")
    payload = json.loads(json.dumps(VALID_PAYLOAD))
    del payload[section][0][key]
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=payload, schema=schema)


def test_artifact_type_outside_the_enum_is_rejected(schema):
    jsonschema = pytest.importorskip("jsonschema")
    payload = json.loads(json.dumps(VALID_PAYLOAD))
    payload["artifacts"][0]["type"] = "shipped"
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(instance=payload, schema=schema)
