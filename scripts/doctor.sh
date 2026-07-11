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
  rm -f -- "$SYMLINK_TEST"
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

# Claude Code uses per-skill symlinks; Qwen/Gemini/OpenCode/Jules read .agents/skills/
if [[ -d .claude/skills ]]; then
  broken_count=0
  while IFS= read -r -d '' link; do
    if [[ ! -e "$link" ]]; then
      broken_count=$((broken_count + 1))
    fi
  done < <(find .claude/skills -maxdepth 1 -type l -print0 2>/dev/null)
  if [[ "$broken_count" -gt 0 ]]; then
    bad ".claude/skills has $broken_count broken symlink(s) (run: ./scripts/setup-skills.sh)"
  elif [[ -n "$(find .claude/skills -maxdepth 1 -type l 2>/dev/null | head -n 1)" ]]; then
    pass ".claude/skills populated with skill symlinks"
  else
    warn ".claude/skills exists but contains no symlinks (run setup-skills.sh)"
  fi
else
  warn ".claude/skills not present (run setup-skills.sh if you use Claude Code)"
fi
if [[ -e .qwen/skills ]]; then
  warn ".qwen/skills present but unused — Qwen reads .agents/skills/ directly (safe to remove)"
fi

# ---- Git hooks ----
sect "Git hooks"
HOOKS_DIR=$(git config core.hooksPath || echo ".git/hooks")
HOOK="$HOOKS_DIR/pre-commit"
if [[ -f "$HOOK" ]]; then
  if [[ -x "$HOOK" ]]; then
    pass "pre-commit hook installed and executable ($HOOK)"
  else
    bad "pre-commit hook exists but is NOT executable (run: chmod +x $HOOK)"
  fi
else
  bad "pre-commit hook missing in $HOOKS_DIR (run: bootstrap.sh)"
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

# ---- CI status freshness ----
sect "CI status freshness"
if [[ -x scripts/check_ci_status_freshness.sh ]]; then
  if ci_status_output="$(scripts/check_ci_status_freshness.sh 2>&1)"; then
    pass "$ci_status_output"
  else
    warn "CI status freshness check reported an issue:"
    printf '%s\n' "$ci_status_output" | sed 's/^/    /'
  fi
else
  warn "scripts/check_ci_status_freshness.sh missing or not executable"
fi

# ---- Final result ----
printf '\n'
if [[ $fail -eq 0 ]]; then
  printf '\u2713 doctor: all checks passed.\n'
  exit 0
else
  printf '\u2717 doctor: one or more checks failed. Fix the issues above, then re-run.\n' >&2
  exit 1
fi
