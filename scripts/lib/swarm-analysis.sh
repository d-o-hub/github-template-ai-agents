#!/usr/bin/env bash
# lib/swarm-analysis.sh - Swarm analysis execution functions
# Source this file from scripts that need swarm analysis capabilities.

execute_swarm_analysis() {
    local worktree_path="$1"
    local analysis_topic="$2"
    local analysis_dir="${3:-analysis}"
    local reports_dir="${4:-reports}"
    local profile="${WEB_RESOLVER_PROFILE:-quality}"

    mkdir -p -- "${worktree_path}/${analysis_dir}"
    mkdir -p -- "${worktree_path}/${reports_dir}"

    local queries_file="${worktree_path}/${analysis_dir}/research_queries.txt"
    generate_research_queries "$analysis_topic" "$queries_file"

    local research_output_dir="${worktree_path}/${analysis_dir}/web_research"
    mkdir -p -- "$research_output_dir"

    local context_file="${worktree_path}/${analysis_dir}/swarm_context.md"
    # Security: Use printf instead of unquoted heredoc to prevent unintended shell expansion
    # and use literal newlines for structure control.
    {
        printf -- "# Swarm Analysis Context\n\n"
        printf -- "**Topic**: %s\n" "$analysis_topic"
        printf -- "**Worktree**: %s\n" "$worktree_path"
        printf -- "**Timestamp**: %s\n\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

        printf -- "## Web Research Results\n"
        printf -- "See: %s/_summary.json\n\n" "$research_output_dir"

        printf -- "## Optimization Strategy\n"
        printf -- "- Web resolver profile: %s\n" "$profile"
        printf -- "- Quality threshold: 0.7+\n"
        printf -- "- Full link validation enabled\n\n"

        printf -- "## Swarm Agent Assignments\n\n"

        printf -- "### Agent 1: Deep Researcher\n"
        printf -- "**Focus**: Comprehensive web research and documentation analysis\n"
        printf -- "**Output**: %s/%s/agent1_research.md\n\n" "$worktree_path" "$analysis_dir"

        printf -- "### Agent 2: Quality Validator\n"
        printf -- "**Focus**: Validate all references, links, and citations\n"
        printf -- "**Output**: %s/%s/agent2_validation.md\n\n" "$worktree_path" "$analysis_dir"

        printf -- "### Agent 3: Performance Optimizer\n"
        printf -- "**Focus**: Analyze research efficiency and token optimization\n"
        printf -- "**Output**: %s/%s/agent3_optimization.md\n" "$worktree_path" "$analysis_dir"
    } > "$context_file"

    local synthesis_file="${worktree_path}/${analysis_dir}/SWARM_SYNTHESIS.md"
    cat > "$synthesis_file" << 'EOF'
# Swarm Analysis Synthesis

## Methodology
Multi-agent swarm analysis with optimized web research.

## Research Summary
See: web_research/_summary.json

## Swarm Agent Findings

### Agent 1: Deep Researcher
**Status**: [Pending execution via task tool]

### Agent 2: Quality Validator
**Status**: [Pending execution via task tool]

### Agent 3: Performance Optimizer
**Status**: [Pending execution via task tool]

## Consensus Analysis

### Confirmed Findings
- [ ] Finding 1
- [ ] Finding 2

### Conflicts Requiring Resolution
- Conflict 1: [Description]

## Action Items
1. [Priority 1]
2. [Priority 2]
EOF

    printf "%s\n" "$synthesis_file"
    return 0
}
