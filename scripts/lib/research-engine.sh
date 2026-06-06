#!/usr/bin/env bash
# lib/research-engine.sh - Web research and resolution functions
# Source this file from scripts that need web research capabilities.

resolve_with_optimization() {
    local query_or_url="$1"
    local output_file="$2"
    local context="${3:-general}"
    local resolver_dir="${4:-.agents/skills/do-web-doc-resolver}"
    local profile="${WEB_RESOLVER_PROFILE:-quality}"

    local resolve_args=(
        "--profile" "$profile"
        "--max-chars" "${WEB_RESOLVER_MAX_CHARS:-8000}"
        "--trace"
        "--json"
    )

    case "$context" in
        "api-docs")
            resolve_args+=("--validate-links" "--quality-threshold" "0.8")
            ;;
        "tutorial")
            resolve_args+=("--check-completeness")
            ;;
        "reference")
            resolve_args+=("--profile" "quality" "--validate-all")
            ;;
        *)
            ;;
    esac

    local result
    result=$(cd "$resolver_dir" && \
        python3 -m scripts.resolve "${resolve_args[@]}" -- "$query_or_url" 2>/dev/null || \
        printf "%s\n" '{"source": "error", "content": "Resolution failed", "score": 0}')

    # Safe JSON generation using Python to avoid shell injection and malformed output
    python3 -c '
import json, sys, datetime
query, context, profile, result_str = sys.argv[1:]
try:
    result = json.loads(result_str)
except Exception:
    result = {"source": "error", "content": "Invalid JSON", "score": 0}

output = {
    "query": query,
    "context": context,
    "profile": profile,
    "timestamp": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "result": result
}
print(json.dumps(output, indent=2))
' "$query_or_url" "$context" "$profile" "$result" > "$output_file"

    local score
    score=$(printf "%s\n" "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('score', 0))" 2>/dev/null || printf "%s\n" "0")

    # Security: Use python3 for floating-point comparison to improve portability and safety (replaces bc)
    if python3 -c "import sys; sys.exit(0 if float(sys.argv[1]) > 0.7 else 1)" "$score" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

generate_research_queries() {
    local topic="$1"
    local output_file="$2"

    # Security: Use printf instead of unquoted heredoc to prevent unintended shell expansion
    printf "# Research Queries for: %s\n# Format: query|context\n\n%s best practices|api-docs\n%s official documentation|reference\n%s getting started tutorial|tutorial\n%s implementation examples|tutorial\n%s common patterns|reference\n%s security considerations|api-docs\n%s performance optimization|reference\n" \
        "$topic" "$topic" "$topic" "$topic" "$topic" "$topic" "$topic" "$topic" > "$output_file"
}
