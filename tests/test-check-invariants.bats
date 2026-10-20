#!/usr/bin/env bats
# ============================================================================
# test-check-invariants.bats — Tests for scripts/check-invariants.sh
# ============================================================================

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    SANDBOX="$(mktemp -d /tmp/invariants-check-XXXXXX)"
    mkdir -p "$SANDBOX/scripts" "$SANDBOX/plans"
    cp "$REPO_ROOT/scripts/check-invariants.sh" "$SANDBOX/scripts/"
    SCRIPT="$SANDBOX/scripts/check-invariants.sh"
    chmod +x "$SCRIPT"

    # Create dummy sensor script inside sandbox
    echo '#!/usr/bin/env bash' > "$SANDBOX/scripts/dummy-sensor.sh"
    chmod +x "$SANDBOX/scripts/dummy-sensor.sh"

    REGISTRY="$SANDBOX/plans/invariants.json"
}

teardown() {
    rm -rf "$SANDBOX"
}

@test "passes with valid invariants registry" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "All skills must be valid.",
      "rationale": "Ensures reliability.",
      "sensor": "scripts/dummy-sensor.sh",
      "category": "architecture"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Validated 1 invariant"* ]]
}

@test "fails when invariants registry file is missing" {
    run "$SCRIPT" "$SANDBOX/plans/nonexistent.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invariants registry not found"* ]]
}

@test "fails on malformed JSON" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [ { "invariant": "Broken JSON"
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid JSON"* ]]
}

@test "fails when required fields are missing" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "Missing fields entry",
      "sensor": "scripts/dummy-sensor.sh"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing or empty 'rationale' field"* ]]
    [[ "$output" == *"missing or empty 'category' field"* ]]
}

@test "fails when category is invalid" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "Invalid category rule",
      "rationale": "Testing category validation",
      "sensor": "scripts/dummy-sensor.sh",
      "category": "unsupported-category"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"invalid category 'unsupported-category'"* ]]
}

@test "fails on duplicate invariant text" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "Duplicate rule text",
      "rationale": "First entry",
      "sensor": "scripts/dummy-sensor.sh",
      "category": "quality"
    },
    {
      "invariant": "Duplicate rule text",
      "rationale": "Second entry",
      "sensor": "scripts/dummy-sensor.sh",
      "category": "quality"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Duplicate invariant text detected"* ]]
}

@test "fails when referenced sensor file does not exist" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "Missing sensor rule",
      "rationale": "Dangling sensor check",
      "sensor": "scripts/missing-sensor.sh",
      "category": "security"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"sensor file does not exist"* ]]
}

@test "fails on path traversal or out-of-root sensor reference" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "Path traversal attempt",
      "rationale": "Security check",
      "sensor": "../../../etc/passwd",
      "category": "security"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"path traversal or absolute path"* ]]
}

@test "handles zero-entry invariants array gracefully" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": []
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Validated 0 invariant"* ]]
}

@test "handles sensor object format correctly" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "Command sensor rule",
      "rationale": "Object sensor test",
      "sensor": {
        "kind": "command",
        "cmd": "bash scripts/dummy-sensor.sh"
      },
      "category": "workflow"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 0 ]
}

@test "fails on unknown sensor object kind" {
    cat > "$REGISTRY" <<EOF
{
  "invariants": [
    {
      "invariant": "Prose sensor rule",
      "rationale": "Arbitrary prose test",
      "sensor": {
        "kind": "prose",
        "description": "just check manually"
      },
      "category": "workflow"
    }
  ]
}
EOF
    run "$SCRIPT" "$REGISTRY"
    [ "$status" -eq 1 ]
    [[ "$output" == *"unsupported sensor kind 'prose'"* ]]
}
