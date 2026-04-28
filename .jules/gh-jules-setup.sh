#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf '[gh-jules-setup] %s\n' "$*"; }
warn() { printf '[gh-jules-setup][warn] %s\n' "$*" >&2; }
die() { printf '[gh-jules-setup][error] %s\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  printf '[gh-jules-setup][error] Failed at line %s with exit code %s\n' "$line_no" "$exit_code" >&2
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  SUDO=""
else
  require_cmd sudo
  SUDO="sudo"
fi

apt_run() {
  if [[ -n "$SUDO" ]]; then
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get "$@"
  else
    DEBIAN_FRONTEND=noninteractive apt-get "$@"
  fi
}

log "Checking base tools"
require_cmd apt-get
require_cmd dpkg

GH_KEYRING="/etc/apt/keyrings/githubcli-archive-keyring.gpg"
GH_LIST="/etc/apt/sources.list.d/github-cli.list"
GH_REPO_LINE="deb [arch=$(dpkg --print-architecture) signed-by=${GH_KEYRING}] https://cli.github.com/packages stable main"

log "Installing prerequisites"
apt_run update -yq
apt_run install -yq ca-certificates curl gpg

log "Ensuring GitHub CLI apt repository is configured"
$SUDO mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | $SUDO tee "$GH_KEYRING" >/dev/null
$SUDO chmod go+r "$GH_KEYRING"
if [[ ! -f "$GH_LIST" ]] || ! grep -Fqx "$GH_REPO_LINE" "$GH_LIST"; then
  printf '%s\n' "$GH_REPO_LINE" | $SUDO tee "$GH_LIST" >/dev/null
fi

if command -v gh >/dev/null 2>&1; then
  log "gh already present: $(gh --version | head -n1)"
else
  log "Installing GitHub CLI"
  apt_run update -yq
  apt_run install -yq gh
fi

require_cmd gh
log "Installed version: $(gh --version | head -n1)"

log "Running gh health checks"
gh --version >/dev/null
gh help >/dev/null 2>&1 || die "gh is installed but not responding correctly"

TOKEN_PRESENT=0
if [[ -n "${GH_TOKEN:-}" || -n "${GITHUB_TOKEN:-}" ]]; then
  TOKEN_PRESENT=1
fi

if [[ "$TOKEN_PRESENT" -eq 1 ]]; then
  log "Token environment variable detected"
  log "In Jules, env-token auth is the expected headless pattern"
  log "Skipping strict 'gh auth status' enforcement because env-token auth can differ from stored-login state"
else
  warn "No GH_TOKEN or GITHUB_TOKEN found during setup"
  warn "Install succeeded, but gh API commands may fail unless the variable is enabled for the Jules task"
fi

log "Recommended verification inside a Jules task session: gh repo view <owner/repo>"
log "Setup complete"
