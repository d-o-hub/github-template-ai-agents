#!/usr/bin/env bash
# Generates llms.txt and llms-full.txt for LLM context.
# Standard: https://llmstxt.org/

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

LLMS_TXT="${LLMS_TXT:-llms.txt}"
LLMS_FULL_TXT="${LLMS_FULL_TXT:-llms-full.txt}"

# Colors for output
if [[ -t 1 ]] && [[ "${FORCE_COLOR:-}" != "0" ]]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    GREEN=''
    YELLOW=''
    NC=''
fi

printf "Generating %s and %s...\n" "$LLMS_TXT" "$LLMS_FULL_TXT"

# Extract Project Info from README.md
# Security: Use -- to prevent option injection
PROJECT_NAME=$(grep -m 1 -- "^# " README.md | sed 's/^# //' || echo "Unnamed Project")
PROJECT_DESC=$(awk -- '
/^>/ {
    gsub(/^>[-+|]*[ ]*/, "")
    if ($0 != "") desc = (desc ? desc " " : "") $0
    in_desc = 1
    next
}
/^[|][-+]?$/ {
    in_desc = 1
    next
}
in_desc && /^[[:space:]]/ && !/^$/ {
    sub(/^[[:space:]]*/, "")
    if ($0 != "") desc = (desc ? desc " " : "") $0
    next
}
in_desc && !/^$/ && !/^>/ && !/^[|][-+]?$/ {
    if ($0 != "") desc = (desc ? desc " " : "") $0
    in_desc = 0
    next
}
in_desc { in_desc = 0 }
END {
    gsub(/^ *| *$/, "", desc)
    if (desc) print desc
}
' README.md)

if [[ -z "${PROJECT_DESC:-}" ]]; then
    PROJECT_DESC="No description available."
fi

# 1. Generate llms.txt (Concise)
{
    printf "# %s\n\n" "$PROJECT_NAME"
    printf "> %s\n\n" "$PROJECT_DESC"

    printf "This repository provides a unified harness for AI coding agents with consistent workflows across multiple tools. It emphasizes quality gates, skill systems, and context discipline.\n\n"

    printf "## Key Files & Directories\n\n"
    printf -- "- [AGENTS.md](AGENTS.md): Single source of truth for all AI coding agents in this repository.\n"
    printf -- "- [.agents/skills/](.agents/skills/): Canonical location for reusable knowledge modules (skills).\n"
    printf -- "- [plans/](plans/): Directory for Architecture Decision Records (ADRs) and GOAP execution plans.\n"
    printf -- "- [agents-docs/](agents-docs/): Comprehensive documentation for the harness, workflows, and skills.\n"
    printf -- "- [scripts/](scripts/): Automation scripts for setup, validation, and maintenance.\n"
    printf -- "- [VERSION](VERSION): Single source of truth for the project version.\n\n"

    printf "## Core Conventions\n\n"
    printf -- "- **Atomic Commits**: Every commit must address exactly one concern and follow Conventional Commits.\n"
    printf -- "- **GOAP Planning**: Goal-Oriented Action Planning is used to decompose tasks into atomic steps.\n"
    printf -- "- **Quality Gates**: Mandatory validation scripts (linting, testing) must pass before any commit.\n"
    printf -- "- **Context Isolation**: Use sub-agents to isolate complex tasks and prevent context rot.\n\n"

    printf "## Essential Skills\n\n"
    printf -- "- [task-decomposition](.agents/skills/task-decomposition/): Break complex tasks into atomic, actionable goals.\n"
    printf -- "- [goap-agent](.agents/skills/goap-agent/): Coordinate complex workflows using goal-oriented planning.\n"
    printf -- "- [self-fix-loop](.agents/skills/self-fix-loop/): Automatically fix CI and linting errors in an iterative loop.\n"
    printf -- "- [shell-script-quality](.agents/skills/shell-script-quality/): Ensure high-quality shell scripts with ShellCheck and BATS.\n\n"

    printf "## Optional\n\n"
    printf -- "- [Full Skill Catalog](agents-docs/AVAILABLE_SKILLS.md): Reference for all available agent skills.\n"
    printf -- "- [Architecture Overview](agents-docs/HARNESS.md): Deep dive into the harness architecture.\n"
    printf -- "- [Workflow Guide](agents-docs/WORKFLOW.md): Detailed explanation of atomic commits and development phases.\n"
} > "$LLMS_TXT"

# 2. Generate llms-full.txt (Extended)
{
    cat "$LLMS_TXT"
    printf "\n---\n\n"
    printf "## Full Skill Index\n\n"

    shopt -s nullglob
    SKILL_DIRS=$(printf "%s\n" .agents/skills/*/ | LC_ALL=C sort)
    for skill_dir in $SKILL_DIRS; do
        skill_file="${skill_dir}SKILL.md"
        if [[ -f "$skill_file" ]]; then
            # Security: Use -- to prevent option injection
            s_name=$(sed -n -- 's/^name: *//p' "$skill_file" | head -n 1 | sed 's/^["'\'']//;s/["'\'']$//')

            s_desc=$(awk -- '
            BEGIN { in_desc=0; desc="" }
            /^description: / {
                in_desc=1
                val = substr($0, index($0, "description: ") + 13)
                gsub(/^[\"'\'']/, "", val)
                gsub(/[\"'\'']$/, "", val)
                
                # Handle block scalar modifiers (|, |-, |+, >, >-, >+)
                # These are YAML block scalar indicators that should be stripped
                if (substr(val, 1, 2) == "|-" || substr(val, 1, 2) == "|+" || 
                    substr(val, 1, 2) == ">-" || substr(val, 1, 2) == ">+") {
                    desc = substr(val, 3)
                    gsub(/^[ \t]+/, "", desc)
                    next
                }
                if (substr(val, 1, 1) == "|" || substr(val, 1, 1) == ">") {
                    desc = substr(val, 2)
                    gsub(/^[ \t]+/, "", desc)
                    next
                }
                desc = val
                in_desc=0
                next
            }
            in_desc && /^[ ]/ {
                gsub(/^[ \t]+/, "", $0)
                if (desc != "") desc = desc " "
                desc = desc $0
                next
            }
            in_desc && !/^[ ]/ {
                in_desc=0
            }
            END {
                gsub(/\n/, " ", desc)
                gsub(/^ *| *$/, "", desc)
                print desc
            }
            ' "$skill_file")

            if [[ -z "$s_name" ]]; then
                s_name=$(basename "$skill_dir")
            fi
            if [[ -z "$s_desc" ]]; then
                s_desc="No description available."
            fi
            printf -- "- [%s](%s): %s\n" "$s_name" "$skill_file" "$s_desc"
        fi
    done
    shopt -u nullglob
} > "$LLMS_FULL_TXT"

size=$(wc -c < "$LLMS_TXT")
if [[ $size -gt 4096 ]]; then
    printf "%bWarning: %s exceeds 4KB (%d bytes). Consider reducing content.%b\n" "$YELLOW" "$LLMS_TXT" "$size" "$NC"
else
    printf "%bSuccess: %s is %d bytes.%b\n" "$GREEN" "$LLMS_TXT" "$size" "$NC"
fi

printf "Generated %s and %s successfully.\n" "$LLMS_TXT" "$LLMS_FULL_TXT"
