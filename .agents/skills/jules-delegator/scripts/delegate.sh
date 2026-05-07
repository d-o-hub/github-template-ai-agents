#!/usr/bin/env bash
# Jules Delegator - Delegate coding tasks via Jules CLI
# Phases: DETECT → NEW SESSION | LIST SESSIONS | PULL RESULTS

set -euo pipefail

# Configuration
DRY_RUN=false
PROMPT=""
REPO=""
SESSION_ID=""
COMMAND=""

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# Logging
log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ERROR:${NC} $*" >&2; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)] SUCCESS:${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] WARNING:${NC} $*"; }

show_help() {
    cat << 'EOF'
Usage: delegate.sh [COMMAND] [OPTIONS]

Commands:
  new         Start a new Jules session
  list        List active/past sessions
  pull        Pull results from a completed session
  tui         Launch interactive TUI

Options:
  -p, --prompt "MSG"   Prompt for the new session
  -r, --repo "OWNER/R" Repository (auto-detected if omitted)
  -s, --session ID     Session ID for pull/view
  --dry-run           Show command without executing
  -h, --help           Show this help
EOF
}

check_dependency() {
    if ! command -v jules &>/dev/null; then
        error "Jules CLI not found. Install it with: npm install -g @google/jules"
        exit 1
    fi
}

detect_repo() {
    if [[ -n "$REPO" ]]; then
        return 0
    fi

    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        warn "Not inside a git repository. Repository auto-detection failed."
        return 1
    fi

    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || true)

    if [[ -z "$remote_url" ]]; then
        warn "No 'origin' remote found. Repository auto-detection failed."
        return 1
    fi

    # Extract owner/repo from various URL formats
    if [[ "$remote_url" =~ github\.com[:/]([^/]+/[^/.]+)(\.git)? ]]; then
        REPO="${BASH_REMATCH[1]}"
        log "Auto-detected repository: $REPO"
    else
        warn "Could not parse repository from remote URL: $remote_url"
    fi
}

exec_command() {
    local cmd=("$@")
    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Executing: ${cmd[*]}"
    else
        "${cmd[@]}"
    fi
}

# Main script
if [[ $# -lt 1 ]]; then
    show_help
    exit 0
fi

COMMAND="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--prompt) PROMPT="$2"; shift 2 ;;
        -r|--repo) REPO="$2"; shift 2 ;;
        -s|--session) SESSION_ID="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        -h|--help) show_help; exit 0 ;;
        *) error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

check_dependency

case "$COMMAND" in
    new)
        if [[ -z "$PROMPT" ]]; then
            error "Prompt is required for a new session. Use -p or --prompt."
            exit 1
        fi
        detect_repo || true
        args=("--session" "$PROMPT")
        if [[ -n "$REPO" ]]; then
            args+=("--repo" "$REPO")
        fi
        exec_command jules remote new "${args[@]}"
        ;;
    list)
        exec_command jules remote list --session
        ;;
    pull)
        if [[ -z "$SESSION_ID" ]]; then
            error "Session ID is required for pull. Use -s or --session."
            exit 1
        fi
        exec_command jules remote pull --session "$SESSION_ID"
        ;;
    tui)
        exec_command jules
        ;;
    *)
        error "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
