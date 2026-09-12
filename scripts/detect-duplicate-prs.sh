#!/usr/bin/env bash
# detect-duplicate-prs.sh - Detect and defuse duplicate open PRs (ADR-034 guard).
#
# Motivation: automation spawned ~20 redundant PRs in one month (5 byte-identical
# codeql pin PRs, 10 overlapping paths.py PRs, 9 subshell-perf PRs). Behavior:
#   - EXACT duplicates (byte-identical diffs): comment + close all but the
#     newest PR in the group.
#   - NEAR duplicates (>=70% of the smaller PR's meaningful files shared with a
#     newer PR; diary/generated files excluded): comment + label
#     'superseded-candidate', never close automatically.
# Comments are idempotent via an HTML marker, so scheduled re-runs never spam.
#
# Env: DRY_RUN=true report only. GH_TOKEN must be set (or use an authenticated gh).
set -euo pipefail

MARKER="<!-- duplicate-pr-guard -->"
NOISE_REGEX='^(\.jules/|plans/|\.agents/skills/README\.md$)'
OVERLAP_THRESHOLD=0.7
DRY_RUN="${DRY_RUN:-false}"
LABEL="superseded-candidate"
CLOSED_COUNT=0
FLAGGED_COUNT=0

is_dry() { [[ "$DRY_RUN" == "true" ]]; }

has_marker() {
  local pr="$1"
  gh pr view "$pr" --json comments --jq '[.comments[].body] | join("\n")' 2>/dev/null \
    | grep -q "duplicate-pr-guard"
}

close_duplicate() {
  local pr="$1" survivor="$2"
  if is_dry; then
    printf '[DRY RUN] would close duplicate PR #%s (byte-identical to survivor #%s)\n' "$pr" "$survivor"
    return 0
  fi
  gh pr close "$pr" \
    --comment "$MARKER
Closing as an exact duplicate: byte-identical diff to PR #$survivor (kept as the newest). See ADR-034 and .github/workflows/duplicate-pr-guard.yml."
  CLOSED_SET["$pr"]=1
  CLOSED_COUNT=$((CLOSED_COUNT + 1))
  printf 'Closed duplicate PR #%s (exact match, survivor #%s)\n' "$pr" "$survivor"
}

flag_superseded() {
  local pr="$1" newer="$2"
  if has_marker "$pr"; then
    printf 'Skipping PR #%s (already flagged by a previous run)\n' "$pr"
    return 0
  fi
  if is_dry; then
    printf '[DRY RUN] would flag PR #%s as superseded by #%s\n' "$pr" "$newer"
    return 0
  fi
  gh pr comment "$pr" \
    --body "$MARKER
Possible duplicate: this PR shares most of its meaningful files with newer PR #$newer. If #$newer covers the same change, close this one; otherwise close #$newer. Labeled \`$LABEL\` for triage. See ADR-034."
  if ! gh pr edit "$pr" --add-label "$LABEL" >/dev/null 2>&1; then
    # A missing repo label makes --add-label fail; flags would stay comment-only
    # and invisible to label-based triage. Create the label once and retry.
    gh label create "$LABEL" \
      --description "Open PR sharing most meaningful files with a newer PR; close the stale one (ADR-034)" \
      --color d4c5f9 >/dev/null 2>&1 || true
    gh pr edit "$pr" --add-label "$LABEL" >/dev/null 2>&1 ||
      printf 'Warning: PR #%s flagged but not labeled (%s missing/unavailable)\n' "$pr" "$LABEL" >&2
  fi
  FLAGGED_COUNT=$((FLAGGED_COUNT + 1))
  printf 'Flagged PR #%s as superseded-candidate (overlaps #%s)\n' "$pr" "$newer"
}

meaningful_files() {
  # Prints the PR's changed files, noise-filtered and sorted.
  local pr="$1"
  gh pr diff "$pr" --name-only 2>/dev/null | grep -vE "$NOISE_REGEX" | sort -u || true
}

main() {
  printf 'Scanning open PRs for duplicates (DRY_RUN=%s)...\n' "$DRY_RUN"

  local pr_rows
  pr_rows="$(gh pr list --state open \
    --json number,createdAt \
    --jq '.[] | "\(.number)\t\(.createdAt)"' 2>/dev/null || true)"
  if [[ -z "$pr_rows" ]]; then
    printf 'No open PRs; nothing to do.\n'
    return 0
  fi

  local -A pr_created=()
  local -A pr_hash=()
  local -A pr_files=()
  local -A CLOSED_SET=()
  local num created hash
  while IFS=$'\t' read -r num created; do
    [[ "$num" =~ ^[0-9]+$ ]] || continue
    pr_created["$num"]="$created"
    hash="$(gh pr diff "$num" 2>/dev/null | sha256sum | cut -d' ' -f1 || true)"
    pr_hash["$num"]="$hash"
    pr_files["$num"]="$(meaningful_files "$num")"
  done < <(printf '%s\n' "$pr_rows")

  # --- EXACT duplicates: identical diff hashes, keep the newest. ---
  local -A exact_group=()
  local survivor
  for num in "${!pr_hash[@]}"; do
    hash="${pr_hash[$num]}"
    [[ -n "$hash" ]] || continue
    exact_group["$hash"]="${exact_group[$hash]:-}${exact_group[$hash]:+ }$num"
  done
  local dupes
  for hash in "${!exact_group[@]}"; do
    dupes="${exact_group[$hash]}"
    mapfile -t dupes < <(for d in $dupes; do printf '%s\t%s\n' "${pr_created[$d]}" "$d"; done | sort | cut -f2)
    (( ${#dupes[@]} > 1 )) || continue
    survivor="${dupes[${#dupes[@]}-1]}"
    printf 'Exact-duplicate group (survivor #%s): %s\n' "$survivor" "${dupes[*]}"
    local member
    for member in "${dupes[@]}"; do
      [[ "$member" == "$survivor" ]] && continue
      close_duplicate "$member" "$survivor"
    done
  done

  # --- NEAR duplicates: pairwise meaningful-file overlap, flag the older. ---
  local -a ordered=()
  for num in "${!pr_created[@]}"; do
    ordered+=("$num")
  done
  mapfile -t ordered < <(for n in "${ordered[@]}"; do printf '%s\t%s\n' "${pr_created[$n]}" "$n"; done | sort | cut -f2)

  local -a files_a=() files_b=()
  local i j a b overlap smaller total=${#ordered[@]}
  for ((i = 0; i < total; i++)); do
    for ((j = i + 1; j < total; j++)); do
      a="${ordered[$i]}"
      b="${ordered[$j]}"
      [[ -z "${CLOSED_SET[$a]:-}" && -z "${CLOSED_SET[$b]:-}" ]] || continue
      mapfile -t files_a < <(printf '%s\n' "${pr_files[$a]}" | grep -v '^$' || true)
      mapfile -t files_b < <(printf '%s\n' "${pr_files[$b]}" | grep -v '^$' || true)
      (( ${#files_a[@]} > 0 && ${#files_b[@]} > 0 )) || continue
      overlap="$(comm -12 <(printf '%s\n' "${files_a[@]}") <(printf '%s\n' "${files_b[@]}") | grep -c . || true)"
      (( overlap > 0 )) || continue
      smaller=$(( ${#files_a[@]} < ${#files_b[@]} ? ${#files_a[@]} : ${#files_b[@]} ))
      if awk -v o="$overlap" -v s="$smaller" -v t="$OVERLAP_THRESHOLD" 'BEGIN { exit !(o / s >= t) }'; then
        flag_superseded "$a" "$b"
      fi
    done
  done

  printf 'Done. closed=%d flagged=%d (DRY_RUN=%s)\n' "$CLOSED_COUNT" "$FLAGGED_COUNT" "$DRY_RUN"
}

main "$@"
