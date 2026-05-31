# Jules CLI Reference

The Jules CLI (`@google/jules`) is the primary interface for delegating tasks to Jules.

## Installation

```bash
npm install -g @google/jules
```

## Authentication

### `jules login`

Authenticate with your Google account. This is required for all remote operations.

### `jules logout`

Log out and remove local credentials.

## Remote Operations

### `jules remote list --repo`

Lists all repositories that Jules has been connected to.

### `jules remote list --session`

Lists your recent Jules sessions, including their status (running, completed, failed) and session IDs.

### `jules remote new`

Starts a new autonomous coding session.

**Arguments:**
- `--repo <owner/repo>`: The GitHub repository to work on.
- `--session "<prompt>"`: A detailed description of the task for Jules.

**Example:**

```bash
jules remote new --repo google-labs-code/jules --session "Fix the race condition in the task scheduler"
```

### `jules remote pull`

Retrieves the changes from a completed Jules session.

**Arguments:**
- `--session <session_id>`: The ID of the session to pull from.

**Example:**

```bash
jules remote pull --session 12345
```

## Interactive Dashboard

### `jules`

Launches the Terminal User Interface (TUI). The TUI provides:
- A dashboard of all your sessions.
- A visual diff viewer for reviewing Jules' changes.
- A guided workflow for creating new sessions.
- Theme support via `--theme <dark|light>`.

## Shell Integration

### `jules completion <bash|zsh>`

Generates autocompletion scripts for your shell.

**Example for Bash:**

```bash
jules completion bash > /etc/bash_completion.d/jules
```

## Global Flags

- `-h, --help`: Show help message.
- `--version`: Show version information.
- `--theme <dark|light>`: Set the TUI theme.
