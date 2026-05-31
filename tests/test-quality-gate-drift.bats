#!/usr/bin/env bats
# BATS tests for quality_gate.sh drift detection behavior
# Tests for:
# 1. Exits with 0 and prints warning when drift is detected during pull_request event
# 2. Exits with 1 when drift detected on main branch

# Global setup
setup_file() {
    export REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

# Per-test setup
setup() {
    cd "$REPO_ROOT" || exit 1
}

@test "quality_gate.sh exits with 0 and warns on drift during pull_request event" {
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/.git"
    mkdir -p "$TEMP_DIR/scripts"
    mkdir -p "$TEMP_DIR/.agents/skills"
    
    # Copy necessary scripts
    cp scripts/quality_gate.sh "$TEMP_DIR/scripts/"
    cp scripts/generate-llms-txt.sh "$TEMP_DIR/scripts/"
    chmod +x "$TEMP_DIR/scripts/"*.sh
    
    # Create minimal required files
    touch "$TEMP_DIR/README.md"
    touch "$TEMP_DIR/VERSION"
    touch "$TEMP_DIR/AGENTS.md"
    
    # Create out-of-date llms.txt
    echo "old content" > "$TEMP_DIR/llms.txt"
    echo "old full content" > "$TEMP_DIR/llms-full.txt"
    
    cd "$TEMP_DIR" || exit 1
    
    # Run quality gate with pull_request event
    run env GITHUB_EVENT=pull_request ./scripts/quality_gate.sh
    
    # Should exit with 0 (not 2) during pull_request
    [ "$status" -eq 0 ]
    
    # Should contain warning about drift
    [[ "$output" == *"llms.txt is out of date"* ]] || [[ "$output" == *"drift"* ]] || [[ "$output" == *"warning"* ]]
    
    # Cleanup
    cd "$REPO_ROOT" || exit 1
    rm -rf "$TEMP_DIR"
}

@test "quality_gate.sh exits with 1 on drift detected on main branch" {
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/.git"
    mkdir -p "$TEMP_DIR/scripts"
    mkdir -p "$TEMP_DIR/.agents/skills"
    
    # Copy necessary scripts
    cp scripts/quality_gate.sh "$TEMP_DIR/scripts/"
    cp scripts/generate-llms-txt.sh "$TEMP_DIR/scripts/"
    chmod +x "$TEMP_DIR/scripts/"*.sh
    
    # Create minimal required files
    touch "$TEMP_DIR/README.md"
    touch "$TEMP_DIR/VERSION"
    touch "$TEMP_DIR/AGENTS.md"
    
    # Create out-of-date llms.txt
    echo "old content" > "$TEMP_DIR/llms.txt"
    echo "old full content" > "$TEMP_DIR/llms-full.txt"
    
    cd "$TEMP_DIR" || exit 1
    
    # Run quality gate on main branch (GITHUB_REF=refs/heads/main)
    run env GITHUB_REF=refs/heads/main GITHUB_EVENT=push ./scripts/quality_gate.sh
    
    # Should exit with 1 when drift detected on main
    [ "$status" -eq 1 ]
    
    # Cleanup
    cd "$REPO_ROOT" || exit 1
    rm -rf "$TEMP_DIR"
}

@test "quality_gate.sh exits with 0 on main branch when no drift" {
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$TEMP_DIR/.git"
    mkdir -p "$TEMP_DIR/scripts"
    mkdir -p "$TEMP_DIR/.agents/skills"
    
    # Copy necessary scripts
    cp scripts/quality_gate.sh "$TEMP_DIR/scripts/"
    cp scripts/generate-llms-txt.sh "$TEMP_DIR/scripts/"
    chmod +x "$TEMP_DIR/scripts/"*.sh
    
    # Create minimal required files
    cat > "$TEMP_DIR/README.md" <<'EOF'
# Test Project
> Test description
EOF
    touch "$TEMP_DIR/VERSION"
    touch "$TEMP_DIR/AGENTS.md"
    
    cd "$TEMP_DIR" || exit 1
    
    # Generate current llms.txt files
    ./scripts/generate-llms-txt.sh > /dev/null 2>&1
    
    # Run quality gate on main branch (should pass)
    run env GITHUB_REF=refs/heads/main GITHUB_EVENT=push ./scripts/quality_gate.sh
    
    # Should exit with 0 when no drift
    [ "$status" -eq 0 ]
    
    # Cleanup
    cd "$REPO_ROOT" || exit 1
    rm -rf "$TEMP_DIR"
}
