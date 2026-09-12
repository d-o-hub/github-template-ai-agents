#!/usr/bin/env bash
# detect-duplicate-prs.sh - Detect and defuse duplicate open PRs (ADR-035 guard).
#
# Motivation: automation spawned ~20 redundant PRs in one month (5 byte-identical
# codeql pin PRs, 10 overlapping paths.py PRs, 9 subshell-perf PRs). Behavior:
#   - EXACT duplicates (byte-identical diffs): comment + close all but the
#     newest PR in the group.
#   - SUBSET duplicates (older PR's meaningful files strictly contained in a
#     newer PR's file set with byte-identical per-file patches): comment +
#     close the older PR.
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
Closing as an exact duplicate: byte-identical diff to PR #$survivor (kept as the newest). See ADR-035 and .github/workflows/duplicate-pr-guard.yml."
  CLOSED_SET["$pr"]=1
  CLOSED_COUNT=$((CLOSED_COUNT + 1))
  printf 'Closed duplicate PR #%s (exact match, survivor #%s)\n' "$pr" "$survivor"
}

close_subset_duplicate() {
  local pr="$1" survivor="$2"
  if is_dry; then
    printf '[DRY RUN] would close subset duplicate PR #%s (every changed file patch is byte-identical in survivor #%s)\n' "$pr" "$survivor"
    return 0
  fi
  gh pr close "$pr" \
    --comment "$MARKER
Closing as a subset duplicate: every changed file in this PR has a byte-identical patch in PR #$survivor (kept as the newest), so nothing is lost. See ADR-035 and .github/workflows/duplicate-pr-guard.yml."
  CLOSED_SET["$pr"]=1
  CLOSED_COUNT=$((CLOSED_COUNT + 1))
  printf 'Closed subset duplicate PR #%s (contained in survivor #%s)\n' "$pr" "$survivor"
}

flag_superseded() {
  local pr="$1" newer="$2" comment_reason="$3" log_reason="$4"
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
Possible duplicate: $comment_reason. If #$newer covers the same change, close this one; otherwise close #$newer. Labeled \`$LABEL\` for triage. See ADR-035."
  if ! gh pr edit "$pr" --add-label "$LABEL" >/dev/null 2>&1; then
    # A missing repo label makes --add-label fail; flags would stay comment-only
    # and invisible to label-based triage. Create the label once and retry.
    gh label create "$LABEL" \
      --description "Open PR sharing most meaningful files with a newer PR; close the stale one (ADR-035)" \
      --color d4c5f9 >/dev/null 2>&1 || true
    gh pr edit "$pr" --add-label "$LABEL" >/dev/null 2>&1 ||
      printf 'Warning: PR #%s flagged but not labeled (%s missing/unavailable)\n' "$pr" "$LABEL" >&2
  fi
  FLAGGED_COUNT=$((FLAGGED_COUNT + 1))
  printf 'Flagged PR #%s as superseded-candidate (%s)\n' "$pr" "$log_reason"
}

file_sections() {
  # Reads a unified diff; emits "<patch-sha256>\t<file>" per diff section.
  # A section spans from its `diff --git` header to the next (or EOF).
  local path="" section=""
  while IFS= read -r line; do
    if [[ "$line" == 'diff --git '* ]]; then
      if [[ -n "$path" ]]; then
        printf '%s\t%s\n' "$(printf '%s' "$section" | sha256sum | cut -d' ' -f1)" "$path"
      fi
      path="${line#diff --git a/}"
      path="${path%% b/*}"
      section=""
    elif [[ -n "$path" ]]; then
      section+="$line"$'\n'
    fi
  done
  if [[ -n "$path" ]]; then
    printf '%s\t%s\n' "$(printf '%s' "$section" | sha256sum | cut -d' ' -f1)" "$path"
  fi
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
  local -A pr_patch_hash=()
  local -A pr_task=()
  local -A CLOSED_SET=()
  local num created diff_text sections ph fpath body head_ref task_id
  while IFS=$'\t' read -r num created; do
    [[ "$num" =~ ^[0-9]+$ ]] || continue
    pr_created["$num"]="$created"
    # Single fetch per PR: whole-diff hash, per-file patch hashes, and the
    # meaningful-file list all derive from the same payload (ADR-035).
    diff_text="$(gh pr diff "$num" 2>/dev/null || true)"
    pr_hash["$num"]="$(printf '%s' "$diff_text" | sha256sum | cut -d' ' -f1)"
    sections="$(file_sections <<< "$diff_text")"
    pr_files["$num"]="$(cut -f2 <<< "$sections" | grep -vE "$NOISE_REGEX" | sort -u || true)"
    while IFS=$'\t' read -r ph fpath; do
      [[ -n "$fpath" ]] && pr_patch_hash["$num:$fpath"]="$ph"
    done <<< "$sections"
    # Jules task id: task URL in the body first, branch-name id as fallback.
    body="$(gh pr view "$num" --json body --jq '.body' 2>/dev/null || true)"
    task_id="$(printf '%s' "$body" | grep -oE 'jules\.google\.com/task/[0-9]+' | head -1 | grep -oE '[0-9]+$' || true)"
    if [[ -z "$task_id" ]]; then
      head_ref="$(gh pr view "$num" --json headRefName --jq '.headRefName' 2>/dev/null || true)"
      task_id="$(printf '%s' "$head_ref" | grep -oE '(^|-)[0-9]{15,}(-|$)' | head -1 | tr -d '-' || true)"
    fi
    pr_task["$num"]="$task_id"
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

  # --- Order PRs oldest -> newest (shared by the subset and near tiers). ---
  local -a ordered=()
  for num in "${!pr_created[@]}"; do
    ordered+=("$num")
  done
  mapfile -t ordered < <(for n in "${ordered[@]}"; do printf '%s\t%s\n' "${pr_created[$n]}" "$n"; done | sort | cut -f2)

  # --- SUBSET duplicates: older PR's files strictly contained in a newer PR's
  # file set with byte-identical patches on every shared file; close the older.
  local i j a b fname a_hash b_hash contained total=${#ordered[@]}
  for ((i = 0; i < total; i++)); do
    for ((j = i + 1; j < total; j++)); do
      a="${ordered[$i]}"
      b="${ordered[$j]}"
      [[ -z "${CLOSED_SET[$a]:-}" && -z "${CLOSED_SET[$b]:-}" ]] || continue
      # a's file set must be a proper subset of b's file set.
      [[ $(grep -c . <<< "${pr_files[$a]}") -lt $(grep -c . <<< "${pr_files[$b]}") ]] || continue
      [[ -z "$(comm -13 <(printf '%s\n' "${pr_files[$b]}") <(printf '%s\n' "${pr_files[$a]}"))" ]] || continue
      contained=1
      while IFS= read -r fname; do
        [[ -n "$fname" ]] || continue
        a_hash="${pr_patch_hash["$a:$fname"]:-}"
        b_hash="${pr_patch_hash["$b:$fname"]:-}"
        if [[ -z "$a_hash" || -z "$b_hash" || "$a_hash" != "$b_hash" ]]; then
          contained=0
          break
        fi
      done <<< "${pr_files[$a]}"
      (( contained )) || continue
      close_subset_duplicate "$a" "$b"
    done
  done

  # --- NEAR duplicates: pairwise meaningful-file overlap, flag the older. ---
  local -a files_a=() files_b=()
  local overlap smaller
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
        flag_superseded "$a" "$b" \
          "this PR shares most of its meaningful files with newer PR #$b" \
          "overlaps #$b"
      fi
    done
  done

  # --- TASK SIBLINGS: several open PRs created by the same Jules task ---
  # (matched via the task URL in the PR body, else the numeric task id embedded
  # in the branch name). One task yields one PR; re-runs supersede earlier
  # attempts even when file overlap is below the near-duplicate threshold.
  # Flag-only: a semantic signal, never proof of change containment.
  local -A task_survivor=()
  local task_id
  for ((i = total - 1; i >= 0; i--)); do
    a="${ordered[$i]}"
    [[ -z "${CLOSED_SET[$a]:-}" ]] || continue
    task_id="${pr_task[$a]:-}"
    [[ -n "$task_id" ]] || continue
    if [[ -n "${task_survivor[$task_id]:-}" ]]; then
      flag_superseded "$a" "${task_survivor[$task_id]}" \
        "this PR was created by the same Jules task as newer PR #${task_survivor[$task_id]}" \
        "same Jules task as #${task_survivor[$task_id]}"
    else
      task_survivor["$task_id"]="$a"
    fi
  done

  printf 'Done. closed=%d flagged=%d (DRY_RUN=%s)\n' "$CLOSED_COUNT" "$FLAGGED_COUNT" "$DRY_RUN"
}

main "$@"
