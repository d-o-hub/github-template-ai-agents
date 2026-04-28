#!/usr/bin/env bats

setup() {
  # Add path to find pact-stub-server if it's installed via cargo
  export PATH="$HOME/.cargo/bin:$PATH"
}

@test "all pact files in contracts/pacts/ are valid JSON" {
  # Works for any language — pact JSON format is standardized
  find contracts/pacts/ -name '*.json' | while read -r pact; do
    echo "Validating $pact"
    run python3 -m json.tool "$pact"
    [ "$status" -eq 0 ]
  done
}

@test "all pact files conform to Pact specification schema" {
  # Use pact-stub-server CLI (Rust binary, cross-platform)
  if ! command -v pact-stub-server &> /dev/null; then
    skip "pact-stub-server not installed (install: cargo install pact_mock_server_cli)"
  fi

  find contracts/pacts/ -name '*.json' | while read -r pact; do
    echo "Starting stub server for $pact"
    # Start in background on a random port
    run pact-stub-server --file "$pact" --port 0 &
    SERVER_PID=$!
    sleep 2
    # Check if process is still running
    if kill -0 $SERVER_PID 2>/dev/null; then
      kill $SERVER_PID 2>/dev/null
      true
    else
      echo "pact-stub-server failed to start for $pact"
      false
    fi
  done
}
