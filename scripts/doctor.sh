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

# ---- Quality gate tools ----
# quality_gate.sh records a skip for each of these when it is missing, and with
# QUALITY_GATE_STRICT_SKIPS=true (what CI sets) it turns that skip into a
# failure. So the same absence is a hard failure here under strict mode, and
# advisory otherwise - doctor must not report health the gate would deny.
sect "Quality gate tools"
STRICT_SKIPS="${QUALITY_GATE_STRICT_SKIPS:-false}"
if [[ "$STRICT_SKIPS" == "true" ]]; then
  printf '  (QUALITY_GATE_STRICT_SKIPS=true: a missing tool fails the gate)\n'
else
  printf '  (a missing tool is a reported skip; set QUALITY_GATE_STRICT_SKIPS=true to require it)\n'
fi
# A tool that exists but cannot run is worse than a missing one: the gate finds
# it with command -v, executes it, and reports an unexplained failure. Probe each
# one so "available" means it actually starts.
_gate_tool_runs() {
  if [[ "$1" == "python3" ]]; then
    "$1" -c 'import json' >/dev/null 2>&1
  else
    "$1" --version >/dev/null 2>&1
  fi
}

while IFS=: read -r cmd why; do
  [[ -n "$cmd" ]] || continue
  if command -v "$cmd" >/dev/null 2>&1; then
    if _gate_tool_runs "$cmd"; then
      pass "$cmd available and runs"
    else
      bad "$cmd at $(command -v "$cmd") exists but does not run - the gate will fail on every check that uses it; reinstall it"
    fi
  elif [[ "$STRICT_SKIPS" == "true" ]]; then
    bad "$cmd not found - needed to $why, and strict skip mode makes that a gate failure"
  else
    warn "$cmd not found - needed to $why; quality_gate.sh will report it as a skip"
  fi
done <<'GATE_TOOLS'
shellcheck:lint shell scripts
markdownlint-cli2:lint Markdown
npx:run secretlint
python3:run the Gemini TOML and metrics checks
GATE_TOOLS

# ---- Other optional tools ----
sect "Other optional tools (advisory only)"
while IFS=: read -r cmd why; do
  [[ -n "$cmd" ]] || continue
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd available"
  else
    warn "$cmd not found - only needed to $why"
  fi
done <<'ADVISORY_TOOLS'
yamllint:lint YAML by hand (CI lints workflows separately)
cargo:build and test Rust projects
ADVISORY_TOOLS

# ---- Repository state ----
sect "Repository"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
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

# Check expected symlinks
for link in .claude/skills .qwen/skills; do
  if [[ -L "$link" ]]; then
    target="$(readlink "$link")"
    pass "$link -> $target"
  elif [[ -d "$link" ]]; then
    # Directory of symlinks rather than a single symlink is also fine
    # perf: replace find subshells and process substitution with native bash globbing and array iteration
    local_shopt=$(shopt -p nullglob dotglob || true)
    shopt -s nullglob dotglob
    symlinks=("$link"/*)
    eval "$local_shopt"

    has_symlinks=0
    for f in "${symlinks[@]}"; do
      if [[ -L "$f" ]]; then
        has_symlinks=1
        break
      fi
    done

    if [[ $has_symlinks -eq 1 ]]; then
      pass "$link populated with skill symlinks"
    else
      warn "$link exists but contains no symlinks (run setup-skills.sh)"
    fi
    # Fail soft on dangling / workspace / orphan skill links
    dangling=0
    for sl in "${symlinks[@]}"; do
      if [[ ! -L "$sl" ]]; then
        continue
      fi
      name="${sl##*/}"
      if [[ "$name" == *-workspace ]]; then
        warn "workspace symlink present (run setup-skills.sh to prune): $sl"
        dangling=$((dangling + 1))
      elif [[ ! -e "$sl" ]]; then
        warn "dangling skill symlink (run setup-skills.sh to prune): $sl"
        dangling=$((dangling + 1))
      elif [[ ! -f ".agents/skills/$name/SKILL.md" ]]; then
        warn "orphan skill symlink (run setup-skills.sh to prune): $sl"
        dangling=$((dangling + 1))
      fi
    done
    if [[ "$dangling" -eq 0 ]]; then
      pass "$link has no dangling/orphan skill links"
    fi
  elif [[ -e "$link" ]]; then
    bad "$link exists but is NOT a symlink or skills directory"
  else
    warn "$link not present (run setup-skills.sh if you use this tool)"
  fi
done

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
