# Status Schema

Documentation for the `plans/_status.json` file schema used for session tracking and continuity.

## File Structure

```json
{
  "nextAvailable": {
    "plan": "string (3-digit index)",
    "adr": "string (adr-XXX)"
  },
  "active_plan": "string (path/to/plan.md)",
  "phases": [
    {
      "id": "string|number",
      "name": "string",
      "status": "pending|active|complete",
      "agent": "string (agent-id)",
      "updated_by": "string (agent-id)",
      "timestamp": "ISO-8601 string"
    }
  ],
  "handover_ref": "string (path/to/handover.md) | null",
  "entries": {
    "adr-XXX.md": {
      "status": "proposed|accepted|rejected",
      "date": "YYYY-MM-DD"
    }
  }
}
```

## Field Definitions

### `active_plan`

The path to the currently active GOAP plan or ADR-based plan. Used by `/resume` to identify the starting point.

### `phases`

An array of objects representing the status of individual plan phases.
- **`id`**: Unique identifier for the phase.
- **`name`**: Descriptive name of the phase.
- **`status`**: Current state of the phase.
- **`agent`**: The agent assigned to execute this phase.
- **`updated_by`**: The agent who last updated this phase's status (for swarm safety).
- **`timestamp`**: Last update time in ISO-8601 format.

### `handover_ref`

Path to a markdown file in `plans/handovers/` containing cross-session context and next steps.
