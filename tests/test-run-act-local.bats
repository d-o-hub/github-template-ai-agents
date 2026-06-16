#!/usr/bin/env bats
# Tests for scripts/run_act_local.sh
# Verifies the opt-in act wrapper handles missing prerequisites gracefully
# and never blocks the quality gate. See agents-docs/ACT.md for usage.
#
# We can only test the early-failure paths here (act missing, docker missing)
# because anything past the docker check would attempt a real Docker run.
# The dispatch path is exercised by hand via ACT_JOB=quality-gate etc.

setup() {
    REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export REPO_ROOT
    SCRIPT="${REPO_ROOT}/scripts/run_act_local.sh"
    [ -f "$SCRIPT" ] || skip "run_act_local.sh not present"
}

# Build a minimal PATH dir that mirrors /usr/bin and /bin but skips the
# named binaries. Used to fake "act is missing" or "docker is missing"
# even on machines where they are installed.
fake_path_without() {
    local skip_pattern="$1"
    local stripped
    stripped="$(mktemp -d)"
    for dir in /usr/bin /bin /usr/local/bin; do
        [ -d "$dir" ] || continue
        for tool in "$dir"/*; do
            [ -x "$tool" ] || continue
            case "$(basename "$tool")" in
                $skip_pattern) continue ;;
            esac
            ln -sf "$tool" "$stripped/$(basename "$tool")" 2>/dev/null || true
        done
    done
    echo "$stripped"
}

@test "run_act_local.sh is executable" {
    [ -x "$SCRIPT" ]
}

@test "run_act_local.sh exits non-zero with a clear 'act missing' message" {
    local stripped
    stripped="$(fake_path_without 'act|act-cli')"

    run env -i HOME="$HOME" PATH="$stripped" bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" =~ act ]]

    rm -rf "$stripped"
}

@test "run_act_local.sh exits non-zero with a clear 'docker missing' message when act is faked" {
    local stripped
    stripped="$(fake_path_without 'docker')"
    cat >"$stripped/act" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$stripped/act"

    run env -i HOME="$HOME" PATH="$stripped" bash "$SCRIPT"

    [ "$status" -eq 1 ]
    [[ "$output" =~ docker ]]

    rm -rf "$stripped"
}
