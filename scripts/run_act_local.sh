#!/usr/bin/env bash
# Optional helper to run GitHub Actions locally via nektos/act.
# This script is intentionally opt-in and never blocks quality gates.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

readonly DEFAULT_WORKFLOW_FILE=".github/workflows/ci.yml"
readonly DEFAULT_EVENT="pull_request"

if ! command -v act >/dev/null 2>&1; then
    echo "act is not installed."
    echo "Install: https://nektosact.com/installation/"
    echo "Then run: ./scripts/run_act_local.sh"
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required by act but was not found in PATH."
    exit 1
fi

ACT_WORKFLOW_FILE="${ACT_WORKFLOW_FILE:-$DEFAULT_WORKFLOW_FILE}"
ACT_EVENT="${ACT_EVENT:-$DEFAULT_EVENT}"
ACT_JOB="${ACT_JOB:-}"
ACT_PLATFORM="${ACT_PLATFORM:-ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest}"

if [[ ! -f "$ACT_WORKFLOW_FILE" ]]; then
    echo "Workflow file not found: $ACT_WORKFLOW_FILE"
    exit 1
fi

echo "Running act with:"
echo "  workflow: $ACT_WORKFLOW_FILE"
echo "  event:    $ACT_EVENT"
echo "  platform: $ACT_PLATFORM"

if [[ -n "$ACT_JOB" ]]; then
    echo "  job:      $ACT_JOB"
    act "$ACT_EVENT" -W "$ACT_WORKFLOW_FILE" -j "$ACT_JOB" -P "$ACT_PLATFORM" "$@"
else
    act "$ACT_EVENT" -W "$ACT_WORKFLOW_FILE" -P "$ACT_PLATFORM" "$@"
fi
