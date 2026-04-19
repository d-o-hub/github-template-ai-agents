#!/usr/bin/env bash
# Discover all commands in markdown files across the repository
# Outputs JSON structure with command text, file locations, and line numbers
# Usage: ./scripts/discover-commands.sh [--output <file>]

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Resolve repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Output file (default to stdout)
OUTPUT_FILE=""
CACHE_DIR="$REPO_ROOT/.cache/command-validations"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--output <file>]"
            echo ""
            echo "Discover all commands in markdown files"
            echo ""
            echo "Options:"
            echo "  --output, -o <file>  Write output to file instead of stdout"
            echo "  --help, -h           Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}" >&2
            exit 1
            ;;
    esac
done

# Function to extract commands from a markdown file
extract_commands() {
    local file="$1"
    local rel_path="${file#$REPO_ROOT/}"
    local line_num=0
    local in_code_block=0
    local code_block_type=""
    local commands=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))
        
        # Check for code block start/end
        if [[ "$line" =~ ^\`\`\`([a-zA-Z]*) ]]; then
            if [[ $in_code_block -eq 0 ]]; then
                # Starting a code block
                in_code_block=1
                code_block_type="${BASH_REMATCH[1]}"
            else
                # Ending a code block
                in_code_block=0
                code_block_type=""
            fi
            continue
        fi
        
        # Extract commands from bash/shell/console code blocks
        if [[ $in_code_block -eq 1 ]] && [[ "$code_block_type" =~ ^(bash|sh|shell|console)$ ]]; then
            # Skip empty lines and comments
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            
            # Extract the command (first word onwards, skip leading whitespace)
            local cmd
            cmd=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
            
            # Skip if empty after trimming
            [[ -z "$cmd" ]] && continue
            
            # Output as JSON-like format
            echo "{\"command\":\"$(echo "$cmd" | sed 's/"/\\"/g')\",\"file\":\"$rel_path\",\"line\":$line_num,\"type\":\"code-block\"}"
        fi
        
        # Extract inline code commands (single backticks)
        # Look for patterns like `npm run build`, `git status`, etc.
        if [[ "$line" =~ \`([a-z]+\ [a-z0-9\-\_\./]+)\` ]]; then
            local inline_cmd="${BASH_REMATCH[1]}"
            
            # Filter for likely commands (start with known command prefixes)
            if [[ "$inline_cmd" =~ ^(npm|yarn|pnpm|git|cargo|python|pip|node|docker|kubectl|make|curl|wget|ls|cat|grep|find|sed|awk|chmod|chown|mkdir|rm|cp|mv|echo|test|bash|sh|bundle|gem|go|rustc|javac|mvn|gradle)[[:space:]] ]]; then
                echo "{\"command\":\"$inline_cmd\",\"file\":\"$rel_path\",\"line\":$line_num,\"type\":\"inline\"}"
            fi
        fi
    done < "$file"
}

# Main discovery function
discover_all() {
    local temp_file
    temp_file=$(mktemp)
    
    # Find all markdown files, excluding common non-doc folders
    find "$REPO_ROOT" -type f -name "*.md" \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/dist/*" \
        -not -path "*/build/*" \
        -not -path "*/target/*" \
        -not -path "*/venv/*" \
        -not -path "*/.venv/*" \
        -not -path "*/__pycache__/*" \
        -not -path "*/.cache/*" \
        -print0 | while IFS= read -r -d '' md_file; do
            
            # Extract commands from this file
            extract_commands "$md_file"
        done > "$temp_file"
    
    # Sort and deduplicate commands
    sort -u "$temp_file"
    
    rm -f "$temp_file"
}

# Generate summary statistics
generate_stats() {
    local commands_json="$1"
    
    local total_commands
    total_commands=$(echo "$commands_json" | wc -l)
    
    local code_block_commands
    code_block_commands=$(echo "$commands_json" | grep -c '"type":"code-block"' || echo 0)
    
    local inline_commands
    inline_commands=$(echo "$commands_json" | grep -c '"type":"inline"' || echo 0)
    
    local unique_commands
    unique_commands=$(echo "$commands_json" | jq -r '.command' 2>/dev/null | sort -u | wc -l || echo "N/A")
    
    local files_with_commands
    files_with_commands=$(echo "$commands_json" | jq -r '.file' 2>/dev/null | sort -u | wc -l || echo "N/A")
    
    echo ""
    echo -e "${GREEN}Command Discovery Summary${NC}"
    echo "─────────────────────────────────────────────────────────────────"
    echo "  Total command occurrences: $total_commands"
    echo "  Code block commands:       $code_block_commands"
    echo "  Inline code commands:      $inline_commands"
    echo "  Unique commands:           $unique_commands"
    echo "  Files with commands:       $files_with_commands"
    echo ""
}

# Main execution
main() {
    echo -e "${YELLOW}Discovering commands in markdown files...${NC}"
    echo ""
    
    # Create cache directory if needed
    mkdir -p "$CACHE_DIR"
    
    # Run discovery
    local results
    results=$(discover_all)
    
    # Output results
    if [[ -n "$OUTPUT_FILE" ]]; then
        echo "$results" > "$OUTPUT_FILE"
        echo -e "${GREEN}✓ Commands written to: $OUTPUT_FILE${NC}"
    else
        echo "$results"
    fi
    
    # Generate stats to stderr so it doesn't interfere with JSON output
    generate_stats "$results" >&2
}

main
