#!/usr/bin/env bash
# doctor.sh - Environment diagnostics for the GitHub AI Agents template.
# Exits 0 when all hard checks pass; exits 1 when any hard check fails.
# Soft warnings (optional tools missing) do not cause failure.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || { printf 'doctor: cannot cd to repo root: %s\n' "$REPO_ROOT" >&2; exit 1; }

fail=0

pass() { printf '  \u2713 %s\n' "$*"; return 0; }
warn() { printf '  ! %s\n' "$*"; return 0; }
bad()  { printf '  \u2717 %s\n' "$*" >&2; fail=1; return 1; }
sect() { printf '\n==> %s\n' "$*"; return 0; }

# ---- Required commands ----
sect "Required tools"
for cmd in git bash; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd: $(command -v "$cmd")"
  else
    bad "$cmd not found"
  fi
done

# ---- Optional quality tools ----
sect "Optional quality tools (needed for quality_gate.sh)"
for cmd in markdownlint-cli2 shellcheck yamllint; do
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd available"
  else
    warn "$cmd not found - quality gate may warn"
  fi
done

# ---- Repository state ----
sect "Repository"
if [[ -d .git ]]; then
  pass "Inside a git repository"
else
  bad "Not inside a git repository (run from repo root)"
fi

# ---- Symlink support ----
sect "Symlink support"
SYMLINK_TEST="$(mktemp -u)"
if ln -sf /dev/null "$SYMLINK_TEST" 2>/dev/null; then
  rm -f "$SYMLINK_TEST"
  pass "Symlinks supported"
else
  bad "Symlinks not supported - Windows without Developer Mode or WSL2"
fi

# ---- Canonical skills directory ----
sect "Skills"
if [[ -d .agents/skills ]]; then
  pass ".agents/skills directory exists"
else
  bad ".agents/skills missing (run setup-skills.sh)"
fi

# Check expected symlinks
for link in .claude/skills .qwen/skills; do
  if [[ -L "$link" ]]; then
    target="$(readlink "$link")"
    pass "$link -> $target"
  elif [[ -d "$link" ]]; then
    # Directory of symlinks rather than a single symlink is also fine
    if [[ -n "$(find "$link" -maxdepth 1 -type l 2>/dev/null | head -n 1)" ]]; then
      pass "$link populated with skill symlinks"
    else
      warn "$link exists but contains no symlinks (run setup-skills.sh)"
    fi
  elif [[ -e "$link" ]]; then
    bad "$link exists but is NOT a symlink or skills directory"
  else
    warn "$link not present (run setup-skills.sh if you use this tool)"
  fi
done

# ---- Git hooks ----
sect "Git hooks"
HOOK=".git/hooks/pre-commit"
if [[ -f "$HOOK" ]]; then
  if [[ -x "$HOOK" ]]; then
    pass "pre-commit hook installed and executable"
  else
    bad "pre-commit hook exists but is NOT executable (run: chmod +x $HOOK)"
  fi
else
  bad "pre-commit hook missing (run: bootstrap.sh)"
fi

# ---- Core files ----
sect "Core files"
for f in AGENTS.md QUICKSTART.md; do
  if [[ -f "$f" ]]; then
    pass "$f present"
  else
    bad "$f missing"
  fi
done

# ---- Final result ----
printf '\n'
if [[ $fail -eq 0 ]]; then
  printf '\u2713 doctor: all checks passed.\n'
  exit 0
else
  printf '\u2717 doctor: one or more checks failed. Fix the issues above, then re-run.\n' >&2
  exit 1
fi
