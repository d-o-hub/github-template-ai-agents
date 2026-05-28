# Local GitHub Actions Rehearsal with `act`

This guide explains how to use [`nektos/act`](https://github.com/nektos/act) to run GitHub Actions workflows locally. This allows for faster feedback loops and easier debugging of CI/CD pipelines without pushing changes to GitHub.

## Prerequisites

To run workflows locally, you need the following tools installed:

1. **Docker**: `act` requires Docker to run the workflow containers.
    - [Install Docker Desktop](https://www.docker.com/products/docker-desktop/) or [Docker Engine](https://docs.docker.com/engine/install/).
    - Ensure Docker is running before starting `act`.
2. **act**: The local GitHub Actions runner.
    - **macOS (Homebrew)**: `brew install act`
    - **Linux**: `curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash`
    - **Windows (Chocolatey)**: `choco install act-cli`
    - See the [official installation guide](https://nektosact.com/installation/) for other methods.

## Using the Helper Script

The template includes a helper script `./scripts/run_act_local.sh` that provides sensible defaults for this repository.

```bash
./scripts/run_act_local.sh [options] [additional-act-args]
```

### Key Environment Variables

You can control the script's behavior using environment variables:

- `ACT_JOB`: The ID of a specific job to run (e.g., `quality-gate`).
- `ACT_EVENT`: The GitHub event to simulate (default: `pull_request`).
- `ACT_WORKFLOW_FILE`: Path to the workflow file (default: `.github/workflows/ci-and-labels.yml`).

## Common Usage Examples

### Run the Default Workflow

Simulates a `pull_request` event for the main CI workflow.

```bash
./scripts/run_act_local.sh
```

### Run a Specific Job

Run only the `quality-gate` job for faster feedback.

```bash
ACT_JOB=quality-gate ./scripts/run_act_local.sh
```

### Run with Local Secrets

If your workflow requires secrets (e.g., API keys), create a `.secrets` file in the root directory:

```text
# .secrets file content
GITHUB_TOKEN=your_personal_access_token
MY_API_KEY=example_value
```

Then run `act`:

```bash
./scripts/run_act_local.sh --secret-file .secrets
```

> **Warning**: Never commit your `.secrets` file. It is added to `.gitignore` by default in this template.

### Dry Run

See what would be executed without actually running the steps.

```bash
./scripts/run_act_local.sh -n
```

## Repository Configuration (`.actrc`)

This repository includes a `.actrc` file that defines default platform mappings to ensure consistency between local runs and GitHub's runners.

Default mapping:
`-P ubuntu-latest=ghcr.io/catthehacker/ubuntu:act-latest`

## Troubleshooting

### Docker Not Running

If you see an error like `docker daemon is not running`, ensure Docker is started.

### Missing Secrets

If a job fails because a secret is missing, ensure you have provided it via a `.secrets` file or the `--secret` flag.

### Platform Mismatches

If `act` prompts you to choose an image, it means the `.actrc` mapping is missing or ignored. Use the "Medium" image if unsure.
