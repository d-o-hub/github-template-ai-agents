# /resume

Resume a previous session by loading state from `plans/_status.json` and the specified handover reference.

## Description

This command allows an agent to quickly re-orient itself by reading the current planning state, loading the last handover notes, and identifying the active plan and its current phase.

## Usage

```bash
/resume
```

## Logic

1. **Read `plans/_status.json`**:
   - Identify the `active_plan` (if any).
   - Read the `phases` array to determine completed vs. in-progress steps.
   - Extract the `handover_ref` path.

2. **Load Handover**:
   - If `handover_ref` exists and points to a valid file (e.g., `plans/handovers/session-XYZ.md`), read its content.
   - Handover files should contain critical context, pending blockers, and immediate next steps not captured in the GOAP plan.

3. **Synchronize State**:
   - Load `plans/GOAP_STATE.md` (or the `active_plan` file) and determine the last `✅ Complete` phase.
   - Cross-check against the `_status.json.phases` array.
   - If they diverge, prefer `GOAP_STATE.md` as source of truth and flag the discrepancy.
   - Extract the current "todo" state and the next pending phase.

## Example Output

```markdown
🔄 Resuming Session...

📂 Status:
- Active Plan: plans/GOAP_STATE.md
- Current Phase: 3 (EXECUTE)
- Handover Ref: plans/handovers/session-2026-06-06.md

📝 Handover Context:
> "Finished Wave 2; Wave 3 docs normalization pending. CI is green on #504."

🎯 Next Steps:
1. Complete Phase 3 task: Normalize setup docs
2. Run quality gate
3. Finalize PR
```

## Related Files

- `plans/_status.json`
- `plans/handovers/`
- `plans/GOAP_STATE.md`
