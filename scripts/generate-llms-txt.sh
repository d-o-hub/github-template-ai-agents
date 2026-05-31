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
# Using sed to extract title and blockquote description
PROJECT_NAME=$(grep -m 1 "^# " README.md | sed 's/^# //' || echo "Unnamed Project")
PROJECT_DESC=$(sed -n '/^> /,/^$/p' README.md | sed 's/^> //' | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//' || echo "No description available.")

# Fallback for empty description
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

    # Use globbing instead of find to avoid process forking overhead
    # Compatible with Bash 3.2
    shopt -s nullglob
    for skill_dir in .agents/skills/*/; do
        skill_file="${skill_dir}SKILL.md"
        if [[ -f "$skill_file" ]]; then
            # Extract name and description from frontmatter
            s_name=$(sed -n 's/^name: *//p' "$skill_file" | head -n 1 | sed 's/^["'\'']//;s/["'\'']$//')
            s_desc=$(sed -n 's/^description: *//p' "$skill_file" | head -n 1 | sed 's/^["'\'']//;s/["'\'']$//')

            # Fallback if frontmatter name is missing
            if [[ -z "$s_name" ]]; then
                s_name=$(basename "$skill_dir")
            fi

            printf -- "- [%s](%s): %s\n" "$s_name" "$skill_file" "${s_desc:-No description available.}"
        fi
    done
    shopt -u nullglob
} > "$LLMS_FULL_TXT"

# Verify size of llms.txt
size=$(wc -c < "$LLMS_TXT")
if [[ $size -gt 4096 ]]; then
    printf "%bWarning: %s exceeds 4KB (%d bytes). Consider reducing content.%b\n" "$YELLOW" "$LLMS_TXT" "$size" "$NC"
else
    printf "%bSuccess: %s is %d bytes.%b\n" "$GREEN" "$LLMS_TXT" "$size" "$NC"
fi

printf "Generated %s and %s successfully.\n" "$LLMS_TXT" "$LLMS_FULL_TXT"
