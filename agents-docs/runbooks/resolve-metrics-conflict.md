# Runbook: Resolving .agents/metrics.jsonl Conflicts

If you encounter a merge conflict in `.agents/metrics.jsonl`, follow these steps to resolve it manually. Note that a CI bot typically handles this automatically for PRs.

## Conflict Pattern

Git flags adjacent-line additions in append-only files. The conflict markers will look like this:

```
<<<<<<< HEAD
{"timestamp": "2026-06-09T15:49:47Z", "agent": "gpt-5.5-codex", ...}
=======
{"timestamp": "2026-06-09T15:58:04Z", "agent": "codex-gpt-5.5", ...}
>>>>>>> main
```

## Manual Resolution

To resolve the conflict while keeping all entries and maintaining chronological order:

1. **Rebase or Merge Main**:
   ```bash
   git fetch origin main
   git rebase origin/main
   # or
   git merge origin/main
   ```

2. **Extract all entries**:
   If conflict markers appear, run this command to keep all unique lines and remove markers:
   ```bash
   grep -v -E '^(<<<<<<<|=======|>>>>>>>|)' .agents/metrics.jsonl \
     | sort -u -t'"' -k4 \
     > .agents/metrics.jsonl.resolved
   mv .agents/metrics.jsonl.resolved .agents/metrics.jsonl
   ```

3. **Verify and Commit**:
   ```bash
   # Validate JSON and timestamp format
   ./scripts/quality_gate.sh

   git add .agents/metrics.jsonl
   git rebase --continue # if rebasing
   # or
   git commit -m "fix(metrics): resolve merge conflict"
   ```

## Prevention

The repository uses `.gitattributes` with `merge=union` to handle these conflicts automatically in most local Git environments. Ensure your local Git is up to date.
