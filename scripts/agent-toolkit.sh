#!/usr/bin/env bash
# agent-toolkit — Unified CLI for AI agent template operations
# Usage: agent-toolkit <command> [args]
set -euo pipefail

VERSION="0.0.0"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors (disabled when NO_COLOR is set or not a terminal)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''
fi

info()  { printf "${BLUE}ℹ${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
err()   { printf "${RED}✗${NC} %s\n" "$*" >&2; }
die()   { err "$*"; exit 2; }

usage() {
    cat <<EOF
${BOLD}agent-toolkit${NC} v${VERSION} — Unified CLI for AI agent template operations

${BOLD}USAGE${NC}
    agent-toolkit <command> [options]

${BOLD}COMMANDS${NC}
    ${GREEN}setup${NC}              First-time repo setup (skills, hooks, validation)
    ${GREEN}doctor${NC}             Environment diagnostics
    ${GREEN}quality${NC}            Run full quality gate
    ${GREEN}validate${NC} [target]  Validation (all, skills, workflows, links, hooks, config, shas, adr)
    ${GREEN}analyze${NC}            Codebase analysis
    ${GREEN}fix${NC}               Auto-fix CI loop until green
    ${GREEN}eval${NC} [skill]       Run skill evaluations
    ${GREEN}docs${NC} <action>      Documentation (generate, sync)
    ${GREEN}version${NC}            Show version
    ${GREEN}help${NC}               Show this help

${BOLD}OPTIONS${NC}
    -h, --help        Show help for a command
    -v, --verbose     Verbose output
    --no-color        Disable colored output

${BOLD}EXAMPLES${NC}
    agent-toolkit setup
    agent-toolkit validate skills
    agent-toolkit quality --verbose
    agent-toolkit eval codacy
    agent-toolkit docs generate

${BOLD}DOCUMENTATION${NC}
    See AGENTS.md for full project documentation.
    See agents-docs/SCRIPTS.md for script details.
EOF
}

cmd_setup() {
    info "Running first-time setup..."
    bash "$REPO_ROOT/scripts/bootstrap.sh" "$@"
}

cmd_doctor() {
    bash "$REPO_ROOT/scripts/doctor.sh" "$@"
}

cmd_quality() {
    bash "$REPO_ROOT/scripts/quality_gate.sh" "$@"
}

cmd_validate() {
    local target="${1:-all}"
    shift 2>/dev/null || true
    case "$target" in
        all)
            bash "$REPO_ROOT/scripts/validate-skills.sh" "$@"
            bash "$REPO_ROOT/scripts/validate-workflows.sh" "$@"
            bash "$REPO_ROOT/scripts/validate-links.sh" "$@"
            bash "$REPO_ROOT/scripts/validate-git-hooks.sh" "$@"
            bash "$REPO_ROOT/scripts/validate-github-actions-shas.sh" "$@"
            ;;
        skills)     bash "$REPO_ROOT/scripts/validate-skills.sh" "$@" ;;
        workflows)  bash "$REPO_ROOT/scripts/validate-workflows.sh" "$@" ;;
        links)      bash "$REPO_ROOT/scripts/validate-links.sh" "$@" ;;
        hooks)      bash "$REPO_ROOT/scripts/validate-git-hooks.sh" "$@" ;;
        shas)       bash "$REPO_ROOT/scripts/validate-github-actions-shas.sh" "$@" ;;
        config)     bash "$REPO_ROOT/scripts/validate-config.sh" "$@" ;;
        adr)        bash "$REPO_ROOT/scripts/check-adr-compliance.sh" "$@" ;;
        *)          die "Unknown validate target: $target (use: all, skills, workflows, links, hooks, config, shas, adr)" ;;
    esac
}

cmd_analyze() {
    bash "$REPO_ROOT/scripts/analyze-codebase.sh" "$@"
}

cmd_fix() {
    bash "$REPO_ROOT/scripts/self-fix-loop.sh" "$@"
}

cmd_eval() {
    local skill="${1:-}"
    shift 2>/dev/null || true
    if [[ -n "$skill" ]]; then
        python3 "$REPO_ROOT/scripts/run-evals.py" --skill "$skill" "$@"
    else
        python3 "$REPO_ROOT/scripts/run-evals.py" "$@"
    fi
}

cmd_docs() {
    local action="${1:-}"
    shift 2>/dev/null || true
    case "$action" in
        generate)
            bash "$REPO_ROOT/scripts/generate-llms-txt.sh" "$@"
            bash "$REPO_ROOT/scripts/generate-skills-reference.sh" "$@"
            bash "$REPO_ROOT/scripts/generate-available-skills.sh" "$@"
            ;;
        sync)       bash "$REPO_ROOT/scripts/docs-sync.sh" "$@" ;;
        update)     bash "$REPO_ROOT/scripts/update-all-docs.sh" "$@" ;;
        *)          die "Unknown docs action: $action (use: generate, sync, update)" ;;
    esac
}

cmd_version() {
    echo "agent-toolkit v${VERSION}"
}

cmd_help() {
    usage
}

# --- Main dispatch ---

main() {
    local cmd="${1:-help}"
    shift 2>/dev/null || true

    case "$cmd" in
        -h|--help|help)    cmd_help ;;
        -v|--verbose)      set -x; main "$@" ;;
        --no-color)        RED=''; GREEN=''; YELLOW=''; BLUE=''; BOLD=''; NC=''; main "$@" ;;
        --version|-V)      cmd_version ;;
        setup)             cmd_setup "$@" ;;
        doctor)            cmd_doctor "$@" ;;
        quality)           cmd_quality "$@" ;;
        validate)          cmd_validate "$@" ;;
        analyze)           cmd_analyze "$@" ;;
        fix)               cmd_fix "$@" ;;
        eval)              cmd_eval "$@" ;;
        docs)              cmd_docs "$@" ;;
        version)           cmd_version ;;
        *)                 die "Unknown command: $cmd\nRun 'agent-toolkit help' for usage." ;;
    esac
}

main "$@"
