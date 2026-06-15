#!/usr/bin/env bash
# bootstrap.sh - Single-command first-time setup for the GitHub AI Agents template.
# Installs skill symlinks, the pre-commit hook, validates skills, runs the quality gate.
# Idempotent: safe to re-run. See: scripts/doctor.sh for diagnostics on failure.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

log()  { printf '==> %s\n' "$*"; return 0; }
ok()   { printf '  \u2713 %s\n' "$*"; return 0; }
warn() { printf '  ! %s\n' "$*"; return 0; }
fail() { printf '\n\u2717 %s\n' "$*" >&2; exit 1; }

# --- pre-flight ---
log "Checking environment"
command -v git >/dev/null 2>&1 || fail "git not found - install git first"
[[ -d .git ]] || fail "Run bootstrap.sh from the repository root"
ok "git present and inside a repository"

# --- symlink support check ---
SYMLINK_TEST="$(mktemp -u)"
if ln -sf /dev/null "$SYMLINK_TEST" 2>/dev/null; then
  rm -f -- "$SYMLINK_TEST"
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
log "Configuring git hooks via .githooks"
if git config core.hooksPath | grep -q '.githooks' >/dev/null 2>&1 && [[ -d ".githooks" ]]; then
  ok "hooks already configured (core.hooksPath = .githooks)"
else
  git config core.hooksPath .githooks
  chmod +x .githooks/* 2>/dev/null || true
  ok "git hooks configured (core.hooksPath = .githooks)"
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
