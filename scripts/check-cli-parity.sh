#!/usr/bin/env bash
# ============================================================================
# check-cli-parity.sh — Cross-CLI drift guard for command and agent names.
#
# The template ships one agent surface through three CLI dialects
# (.claude, .opencode, .gemini), and dialects drift: a command added to
# .opencode/commands never reaches .claude/commands, an agent is folded or
# renamed in one dialect and survives in the other two, and users on the wrong
# CLI are told to invoke something their CLI cannot resolve. discover-commands.sh
# found no comparable check — it inventories commands inside .md code blocks;
# it cannot see whether the *CLI command surfaces themselves* agree.
#
# What is compared: the SET of command names (and agent names) each CLI
# defines — file stems of `*.md`/`*.toml` definitions. Names only; bodies are
# out of scope (each dialect legitimately phrases the same command in its own
# format). Names from nested bundle directories (e.g. `.claude/agents/goap-agent/`)
# do not count — a bundle travels with its identically named definition.
#
# Rule: each CLI's name set is compared against the union of all participating
# CLIs. A name the union contains but one CLI lacks is drift, unless a tracked
# allowlist row sanctions that exclusion:
#     scripts/lib/cli-parity-allowlist.tsv, one row per exclusion:
#         name<TAB>cli<TAB>reason
# The row covers the (name, cli) pair on both surfaces. Reasons are mandatory
# and free text (the rest of the line after the second tab). Empty names,
# missing CLIs, or unknown CLI identifiers in a row are malformed input and
# fail closed. A row that currently excludes nothing (the drifted name has
# returned to every CLI, or never existed) is inert; inert rows are reported
# as warnings so dead config cannot accumulate silently, but do not fail.
#
# Required inputs, fail closed: the allowlist file, and the three command dirs
# (`.claude/commands`, `.opencode/commands`, `.gemini/commands`) — the
# template guarantees them, so a vanished dir is an input disappearance, not
# "drift to zero". Agent dirs participate only when present ("if present"):
# a CLI whose agent dir never existed is exempt from the agent comparison,
# and when no CLI ships an agent dir the agent comparison is skipped visibly.
#
# Exit codes: 0 = no unsanctioned drift | 1 = drift, or fail-closed input.
# ============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ALLOWLIST_PATH="$REPO_ROOT/scripts/lib/cli-parity-allowlist.tsv"

cd "$REPO_ROOT"

readonly -a CLI_IDS=(claude opencode gemini)

declare -A COMMAND_DIRS=() AGENT_DIRS=()
COMMAND_DIRS[claude]=".claude/commands"
COMMAND_DIRS[opencode]=".opencode/commands"
COMMAND_DIRS[gemini]=".gemini/commands"
AGENT_DIRS[claude]=".claude/agents"
AGENT_DIRS[opencode]=".opencode/agents"
AGENT_DIRS[gemini]=".gemini/agents"

fail_input() {
    printf '  ✗ %s\n' "$1" >&2
    printf '    (fail closed: parity cannot be verified without complete inputs)\n' >&2
    exit 1
}

# --- Allowlist ---------------------------------------------------------------

if [[ ! -f "$ALLOWLIST_PATH" ]]; then
    fail_input "CLI parity allowlist missing: scripts/lib/cli-parity-allowlist.tsv"
fi

declare -a ALLOW_NAME=() ALLOW_CLI=() ALLOW_REASON=() ALLOW_USED=()
declare -A ALLOW_INDEX=()
duplicate_rows=0
allow_lineno=0

# `|| [[ -n "$row_name" ]]` handles a final row without a trailing newline:
# read assigns the fields and *then* reports EOF, so a plain `while read` would
# drop the last record (see scripts/AGENTS.md — check-skill-references.sh bug).
while IFS=$'\t' read -r row_name row_cli row_reason || [[ -n "$row_name" ]]; do
    allow_lineno=$((allow_lineno + 1))
    [[ -z "$row_name" || "$row_name" == \#* ]] && continue
    if [[ -z "$row_cli" || -z "${row_reason:-}" ]]; then
        fail_input "malformed allowlist row ${allow_lineno} (need name<TAB>cli<TAB>reason): '${row_name}'"
    fi
    if [[ " ${CLI_IDS[*]} " != *" $row_cli "* ]]; then
        fail_input "allowlist row ${allow_lineno} names unknown CLI '${row_cli}' (known: claude, opencode, gemini)"
    fi
    row_key="${row_name}"$'\t'"${row_cli}"
    if [[ -n "${ALLOW_INDEX[$row_key]:-}" ]]; then
        duplicate_rows=$((duplicate_rows + 1))
        printf '  ⚠ duplicate allowlist row (name=%s cli=%s); the first row wins\n' \
            "$row_name" "$row_cli" >&2
        continue
    fi
    ALLOW_INDEX["$row_key"]=${#ALLOW_NAME[@]}
    ALLOW_NAME+=("$row_name")
    ALLOW_CLI+=("$row_cli")
    ALLOW_REASON+=("$row_reason")
    ALLOW_USED+=(0)
done < "$ALLOWLIST_PATH"

# --- Surface collection ------------------------------------------------------

declare -A HAVE=()          # surface<TAB>cli<TAB>name -> 1
declare -A UNION=()         # surface<TAB>name -> 1
declare -A PARTICIPANTS=()  # surface -> space-separated participating CLIs

# Echo the definition names (file stems of top-level *.md/*.toml) in a dir.
collect_names() {
    local dir="$REPO_ROOT/$1"
    local -a files=()
    local f stem
    shopt -s nullglob
    files=("$dir"/*.md "$dir"/*.toml)
    shopt -u nullglob
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || continue
        stem="${f##*/}"
        printf '%s\n' "${stem%.*}"
    done
}

collect_surface() {
    local surface="$1" required="$2" cli dir name
    for cli in "${CLI_IDS[@]}"; do
        if [[ "$surface" == "commands" ]]; then
            dir="${COMMAND_DIRS[$cli]}"
        else
            dir="${AGENT_DIRS[$cli]}"
        fi
        if [[ ! -d "$REPO_ROOT/$dir" ]]; then
            if [[ "$required" == "required" ]]; then
                fail_input "required command dir missing: ${dir} (a vanished dir is an input disappearance, not drift)"
            fi
            continue
        fi
        PARTICIPANTS[$surface]="${PARTICIPANTS[$surface]:-} ${cli}"
        while IFS= read -r name; do
            [[ -z "$name" ]] && continue
            HAVE["${surface}"$'\t'"${cli}"$'\t'"${name}"]=1
            UNION["${surface}"$'\t'"${name}"]=1
        done < <(collect_names "$dir")
    done
}

collect_surface commands required
collect_surface agents optional

# --- Comparison --------------------------------------------------------------

surface_label() {
    if [[ "$1" == "commands" ]]; then
        printf 'command'
    else
        printf 'agent'
    fi
}

count_owned() {  # count names a CLI owns on a surface
    local surface="$1" cli="$2" name count=0
    for name in "${!UNION[@]}"; do
        [[ "$name" == "${surface}"$'\t'* ]] || continue
        [[ -n "${HAVE[${surface}$'\t'${cli}$'\t'${name#*$'\t'}]:-}" ]] && count=$((count + 1))
    done
    printf '%s' "$count"
}

count_union() {
    local surface="$1" name count=0
    for name in "${!UNION[@]}"; do
        [[ "$name" == "${surface}"$'\t'* ]] && count=$((count + 1))
    done
    printf '%s' "$count"
}

tab=$'\t'
violation_count=0
sanctioned_gap_count=0
declare -a REPORT_LINES=()

for surface in commands agents; do
    [[ -n "${PARTICIPANTS[$surface]:-}" ]] || continue
    # PARTICIPANTS is a space-joined string (claude/opencode/gemini tokens);
    # split it explicitly so the loop needs no unquoted parameter expansion.
    read -r -a surface_participants <<< "${PARTICIPANTS[$surface]# }"
    while IFS= read -r name; do
        missing="" missing_dirs="" defined_in=""
        for cli in "${surface_participants[@]}"; do
            if [[ -n "${HAVE[${surface}${tab}${cli}${tab}${name}]:-}" ]]; then
                defined_in="${defined_in}${defined_in:+, }${cli}"
            else
                row_key="${name}${tab}${cli}"
                row_idx="${ALLOW_INDEX[$row_key]:-}"
                if [[ -n "$row_idx" ]]; then
                    ALLOW_USED[row_idx]=1
                    sanctioned_gap_count=$((sanctioned_gap_count + 1))
                    continue
                fi
                missing="${missing}${missing:+, }${cli}"
                if [[ "$surface" == "commands" ]]; then
                    missing_dirs="${missing_dirs}${missing_dirs:+, }${COMMAND_DIRS[$cli]}"
                else
                    missing_dirs="${missing_dirs}${missing_dirs:+, }${AGENT_DIRS[$cli]}"
                fi
            fi
        done
        if [[ -n "$missing" ]]; then
            REPORT_LINES+=("    ✗ $(surface_label "$surface") '${name}' missing from: ${missing_dirs} (defined in: ${defined_in})")
            violation_count=$((violation_count + 1))
        fi
    done < <(printf '%s\n' "${!UNION[@]}" | grep "^${surface}${tab}" | cut -f2- | LC_ALL=C sort)
done

# --- Report ------------------------------------------------------------------

printf '=== Cross-CLI command/agent parity ===\n'
for surface in commands agents; do
    if [[ -z "${PARTICIPANTS[$surface]:-}" ]]; then
        if [[ "$surface" == "agents" ]]; then
            printf '  agents: - (no agent dirs present; comparison skipped)\n'
        fi
        continue
    fi
    printf '  %s: ' "$surface"
    read -r -a surface_participants <<< "${PARTICIPANTS[$surface]# }"
    for cli in "${surface_participants[@]}"; do
        printf '%s=%s ' "$cli" "$(count_owned "$surface" "$cli")"
    done
    printf '(union=%s)\n' "$(count_union "$surface")"
done
printf '  allowlist: %d sanctioned exclusion row(s), %d currently applied\n' \
    "${#ALLOW_NAME[@]}" "$sanctioned_gap_count"

if (( duplicate_rows > 0 )); then
    printf '  ⚠ %d duplicate allowlist row(s) ignored (first wins)\n' "$duplicate_rows"
fi

for i in "${!ALLOW_NAME[@]}"; do
    if [[ "${ALLOW_USED[$i]}" -eq 0 ]]; then
        printf '  ⚠ stale allowlist row: %s is not missing from %s any more — prune the row\n' \
            "${ALLOW_NAME[$i]}" "${ALLOW_CLI[$i]}"
    fi
done

if (( violation_count > 0 )); then
    printf '%s\n' "${REPORT_LINES[@]}"
    printf '  ✗ cross-CLI drift: %d unsanctioned gap(s)\n' "$violation_count"
    printf '    Port the definition to the missing CLI (bodies differ per dialect;\n'
    printf '    names must agree), or sanction the exclusion with a\n'
    printf '    name<TAB>cli<TAB>reason row in scripts/lib/cli-parity-allowlist.tsv.\n'
    exit 1
fi

printf '  ✓ no unsanctioned drift: every command and agent name in the union is\n'
printf '    defined by every participating CLI or sanctioned by the allowlist\n'
exit 0
