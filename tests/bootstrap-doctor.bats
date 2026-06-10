#!/usr/bin/env bats
# Tests for scripts/bootstrap.sh and scripts/doctor.sh

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    cd "$REPO_ROOT"
}

# ---------- bootstrap.sh ----------

@test "bootstrap.sh exists and is executable" {
    [ -x "./scripts/bootstrap.sh" ]
}

@test "bootstrap.sh has bash shebang" {
    head -1 ./scripts/bootstrap.sh | grep -q "^#!/usr/bin/env bash$"
}

@test "bootstrap.sh passes shellcheck" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    run shellcheck ./scripts/bootstrap.sh
    [ "$status" -eq 0 ]
}

@test "bootstrap.sh has set -euo pipefail" {
    grep -q '^set -euo pipefail$' ./scripts/bootstrap.sh
}

@test "bootstrap.sh references doctor.sh on failure" {
    grep -q 'doctor.sh' ./scripts/bootstrap.sh
}

@test "bootstrap.sh uses REPO_ROOT detection pattern" {
    grep -q 'REPO_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE\[0\]}")/.." && pwd)"' \
        ./scripts/bootstrap.sh
}

# ---------- doctor.sh ----------

@test "doctor.sh exists and is executable" {
    [ -x "./scripts/doctor.sh" ]
}

@test "doctor.sh has bash shebang" {
    head -1 ./scripts/doctor.sh | grep -q "^#!/usr/bin/env bash$"
}

@test "doctor.sh passes shellcheck" {
    if ! command -v shellcheck >/dev/null 2>&1; then
        skip "shellcheck not installed"
    fi
    run shellcheck ./scripts/doctor.sh
    [ "$status" -eq 0 ]
}

@test "doctor.sh uses REPO_ROOT detection pattern" {
    grep -q 'REPO_ROOT="\$(cd "\$(dirname "\${BASH_SOURCE\[0\]}")/.." && pwd)"' \
        ./scripts/doctor.sh
}

@test "doctor.sh checks for required tools" {
    grep -q 'Required tools' ./scripts/doctor.sh
    grep -q 'for cmd in git bash' ./scripts/doctor.sh
}

@test "doctor.sh checks symlink support" {
    grep -q 'Symlink support' ./scripts/doctor.sh
}

@test "doctor.sh checks for .agents/skills directory" {
    grep -q '.agents/skills' ./scripts/doctor.sh
}

@test "doctor.sh checks for pre-commit hook" {
    grep -q 'git config core.hooksPath' ./scripts/doctor.sh
}

@test "doctor.sh detects missing pre-commit hook with non-zero exit" {
    HOOKS_DIR=$(git config core.hooksPath || echo ".git/hooks")
    HOOK="$HOOKS_DIR/pre-commit"
    BACKUP=""
    if [ -f "$HOOK" ]; then
        BACKUP="$(mktemp)"
        cp "$HOOK" "$BACKUP"
        rm -f "$HOOK"
    fi

    run ./scripts/doctor.sh

    if [ -n "$BACKUP" ]; then
        cp "$BACKUP" "$HOOK"
        chmod +x "$HOOK"
        rm -f "$BACKUP"
    fi

    [ "$status" -ne 0 ]
}

@test "doctor.sh prints structured pass/fail messages" {
    run ./scripts/doctor.sh
    # Either pass or fail, output should include section headers
    echo "$output" | grep -q '==>'
}

@test "setup-skills.sh falls back when realpath lacks --relative-to" {
    fake_bin="$(mktemp -d)"
    cat >"$fake_bin/realpath" <<'EOF_REALPATH'
#!/usr/bin/env bash
for arg in "$@"; do
    case "$arg" in
        --relative-to|--relative-to=*)
            printf 'realpath: unsupported option: %s\n' "$arg" >&2
            exit 1
            ;;
    esac
done
if [ -x /usr/bin/realpath ]; then
    exec /usr/bin/realpath "$@"
fi
printf '%s\n' "${@: -1}"
EOF_REALPATH
    chmod +x "$fake_bin/realpath"

    backup_root="$(mktemp -d)"
    claude_backup=""
    qwen_backup=""
    if [ -e .claude/skills ] || [ -L .claude/skills ]; then
        claude_backup="$backup_root/claude-skills"
        mv .claude/skills "$claude_backup"
    fi
    if [ -e .qwen/skills ] || [ -L .qwen/skills ]; then
        qwen_backup="$backup_root/qwen-skills"
        mv .qwen/skills "$qwen_backup"
    fi

    run env PATH="$fake_bin:$PATH" ./scripts/setup-skills.sh

    sample_skill="$(find .agents/skills -mindepth 1 -maxdepth 1 -type d ! -name durable-objects ! -name eu-ai-act-compliance | head -n 1)"
    sample_name="${sample_skill##*/}"
    claude_link=".claude/skills/$sample_name"
    qwen_link=".qwen/skills/$sample_name"
    claude_usable=false
    qwen_usable=false
    [ -L "$claude_link" ] && [ -d "$claude_link" ] && claude_usable=true
    [ -L "$qwen_link" ] && [ -d "$qwen_link" ] && qwen_usable=true

    rm -rf .claude/skills .qwen/skills "$fake_bin"
    if [ -n "$claude_backup" ]; then
        mv "$claude_backup" .claude/skills
    fi
    if [ -n "$qwen_backup" ]; then
        mv "$qwen_backup" .qwen/skills
    fi
    rm -rf "$backup_root"

    [ "$status" -eq 0 ]
    [ "$claude_usable" = true ]
    [ "$qwen_usable" = true ]
}

@test "doctor.sh reports setup-skills fallback when realpath lacks --relative-to" {
    fake_bin="$(mktemp -d)"
    cat >"$fake_bin/realpath" <<'EOF_REALPATH'
#!/usr/bin/env bash
for arg in "$@"; do
    case "$arg" in
        --relative-to|--relative-to=*)
            printf 'realpath: unsupported option: %s\n' "$arg" >&2
            exit 1
            ;;
    esac
done
if [ -x /usr/bin/realpath ]; then
    exec /usr/bin/realpath "$@"
fi
printf '%s\n' "${@: -1}"
EOF_REALPATH
    chmod +x "$fake_bin/realpath"

    run env PATH="$fake_bin:$PATH" ./scripts/doctor.sh
    rm -rf "$fake_bin"

    echo "$output" | grep -q 'Skill symlink path calculation'
    echo "$output" | grep -Eq 'python3 fallback available|absolute symlink targets'
}
