#!/usr/bin/env bash
# bootstrap.sh - Single-command first-time setup for the GitHub AI Agents template.
# Installs skill symlinks, the pre-commit hook, validates skills, runs the quality gate.
# Idempotent: safe to re-run. See: scripts/doctor.sh for diagnostics on failure.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log()  { printf '==> %s\n' "$*"; }
ok()   { printf '  \u2713 %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*"; }
fail() { printf '\n\u2717 %s\n' "$*" >&2; exit 1; }

# --- pre-flight ---
log "Checking environment"
command -v git >/dev/null 2>&1 || fail "git not found - install git first"
[[ -d .git ]] || fail "Run bootstrap.sh from the repository root"
ok "git present and inside a repository"

# --- symlink support check ---
SYMLINK_TEST="$(mktemp -u)"
if ln -sf /dev/null "$SYMLINK_TEST" 2>/dev/null; then
  rm -f "$SYMLINK_TEST"
  log "Setting up skills"
  if ./scripts/setup-skills.sh; then
    ok "Skills ready"
  else
    fail "setup-skills.sh failed - run ./scripts/doctor.sh for diagnostics"
  fi
else
  warn "Symlinks unavailable. On Windows, enable Developer Mode or run inside WSL2."
  warn "Skills setup will be skipped."
fi

# --- git hook ---
log "Installing pre-commit hook"
HOOK_SRC="scripts/pre-commit-hook.sh"
HOOK_DST=".git/hooks/pre-commit"

if [[ -f "$HOOK_SRC" ]]; then
  cp "$HOOK_SRC" "$HOOK_DST"
  chmod +x "$HOOK_DST"
  ok "pre-commit hook installed"
else
  warn "$HOOK_SRC not found, skipping hook install"
fi

# --- validate ---
log "Validating skills"
if ./scripts/validate-skills.sh >/dev/null 2>&1; then
  ok "Skills valid"
else
  warn "Skills validation reported issues - run ./scripts/doctor.sh for details"
fi

# --- quality gate ---
log "Running quality gate"
if ./scripts/quality_gate.sh; then
  ok "Quality gate passed"
  printf '\nBootstrap complete. Repository is ready for AI agent workflows.\n'
  exit 0
else
  printf '\nBootstrap completed with quality gate issues.\n' >&2
  printf 'Run ./scripts/doctor.sh for environment diagnostics.\n' >&2
  exit 1
fi
