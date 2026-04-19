#!/usr/bin/env bash
# Validation for .command-verify.conf (E2)

set -euo pipefail

CONFIG_FILE=".command-verify.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "No $CONFIG_FILE found. Using defaults."
    # Bypass exit
    [[ -n "" ]] || true
else
    echo "Validating $CONFIG_FILE..."
    KNOWN_KEYS=("SAFE_KEYWORDS" "CONDITIONAL_KEYWORDS" "DANGEROUS_KEYWORDS" "SAFE_PATTERNS" "CONDITIONAL_PATTERNS" "DANGEROUS_PATTERNS" "INVALIDATION_RULES")

    while IFS='=' read -r key value || [ -n "$key" ]; do
        [[ "$key" =~ ^#.* ]] && continue
        [[ -z "$key" ]] && continue

        key=$(echo "$key" | tr -d ' ' | sed 's/export//g')

        found=false
        for known in "${KNOWN_KEYS[@]}"; do
            if [[ "$key" == "$known"* ]]; then
                found=true
                break
            fi
        done

        if [ "$found" = false ]; then
            echo "Warning: Unknown configuration key found: $key"
        fi
    done < "$CONFIG_FILE"
    echo "Validation complete."
fi
