#!/usr/bin/env bash
# ============================================================================
# install-bats.sh — Ensure `bats` (bats-core) is available, portably.
# ============================================================================
#
# The `bats` apt package is not guaranteed on GitHub's ubuntu images, and the
# previous inline install swallowed a failed `apt-get update` inside a
# best-effort retry loop: the loop ended on the `sleep` branch, so the step
# continued to `apt-get install` against a stale index and died with
# "E: Unable to locate package bats" — red-locking the whole CI gate on an
# infrastructure detail (run 45775288595). Adopters on images without the
# package hit the same wall, so this helper tries apt first and then installs
# the pinned upstream release into a per-user prefix.
#
# Usage:
#   ./scripts/install-bats.sh            # apt, else bats-core from source
#   BATS_VERSION=v1.11.1 ./scripts/install-bats.sh
# ============================================================================

set -euo pipefail

BATS_VERSION="${BATS_VERSION:-v1.11.1}"
BATS_PREFIX="${BATS_PREFIX:-${HOME}/.local/bats-core}"

if command -v bats >/dev/null 2>&1; then
    printf 'bats already available: %s\n' "$(bats --version)"
    exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
    have_sudo=false
    if command -v sudo >/dev/null 2>&1; then
        have_sudo=true
    fi
    apt() {
        if [[ "$have_sudo" == "true" ]]; then
            sudo apt-get "$@"
        else
            apt-get "$@"
        fi
    }

    for attempt in 1 2 3; do
        if apt update; then
            break
        fi
        if (( attempt == 3 )); then
            printf 'WARNING: apt-get update failed; trying the source install.\n' >&2
        else
            sleep 5
        fi
    done

    if apt install -y bats; then
        printf 'bats installed from apt.\n'
        exit 0
    fi
    printf 'WARNING: no apt package for bats; installing bats-core %s.\n' \
        "$BATS_VERSION" >&2
fi

git clone --quiet --depth 1 --branch "$BATS_VERSION" \
    https://github.com/bats-core/bats-core.git "$BATS_PREFIX"
export PATH="${BATS_PREFIX}/bin:${PATH}"
bats --version

# GitHub Actions needs the path exported to later steps; a local run only
# needs it for this shell.
if [[ -n "${GITHUB_PATH:-}" ]]; then
    printf '%s\n' "${BATS_PREFIX}/bin" >> "$GITHUB_PATH"
fi
