#!/usr/bin/env bash
# lib/common.sh - Shared helpers for the Git-GitHub workflow skill: colors,
# error codes, and logging functions. Sourced by ../../run.sh.
# shellcheck disable=SC2034
# The readonly error-code constants below are consumed by the sourcing run.sh
# and the other scripts/lib/ phase modules; that cross-file use is invisible
# here, so the "appears unused" check is suppressed with this documented reason.
# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' CYAN='' MAGENTA='' NC=''
fi

# Error codes
readonly E_SUCCESS=0
readonly E_COMMIT_FAILED=2
readonly E_QUALITY_GATE=3
readonly E_ISSUES_BLOCKING=4
readonly E_PR_FAILED=5
readonly E_CHECKS_FAILED=6
readonly E_MAX_RETRIES=7
readonly E_MERGE_FAILED=8
readonly E_POST_MERGE_FAILED=9

# Logging
log() { echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $*"; }
info() { echo -e "${CYAN}[$(date +%H:%M:%S)] INFO:${NC} $*"; }
error() { echo -e "${RED}[$(date +%H:%M:%S)] ERROR:${NC} $*" >&2; }
success() { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $*"; }
warn() { echo -e "${YELLOW}[$(date +%H:%M:%S)] WARNING:${NC} $*"; }
agent() { echo -e "${MAGENTA}[$(date +%H:%M:%S)] AGENT:${NC} $*"; }
