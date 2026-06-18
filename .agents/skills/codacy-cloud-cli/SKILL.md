---
name: codacy-cloud-cli
version: "1.5.0"
category: code-quality
description: Use the Codacy Cloud CLI to query Codacy Cloud remotely — repositories, issues, security findings, pull requests, tools, patterns, and reanalysis. Use when the user wants to check code quality metrics on Codacy Cloud, inspect remote PR analysis results, browse vulnerabilities, enable/disable tools, or search patterns — even if they don't say "Codacy CLI" explicitly. This is the CLOUD API skill — NOT for local CLI analysis (use codacy for local runs).
license: MIT
metadata:
  author: Codacy
---

> **Glossary:** See [glossary.md](references/glossary.md) for shared definitions of Codacy concepts (issues, findings, severity, coverage, tools, patterns, etc.).

The Codacy Cloud CLI (`codacy`) is the command-line interface for Codacy Cloud. Use it whenever the user wants to interact with remote Codacy data. This is a different tool from the Codacy Analysis CLI (`codacy-analysis`), which runs static analysis locally.

## Setup

```bash
# Install
npm install -g @codacy/codacy-cloud-cli

# Authenticate — 3 options:
# 1. Set the `CODACY_API_TOKEN` environment variable
export CODACY_API_TOKEN=<token>

# 2. Use the `codacy login` command (interactive login)
codacy login

# 3. Use the `codacy login` command (with token input)
codacy login --token <token>

# Obtain tokens: Codacy > My Account > Access Management > Account API Tokens
# Verify
codacy info
```

**Shared session:** The Cloud CLI and the Analysis CLI (`codacy-analysis`) share the same credentials at `~/.codacy/credentials`. Logging in or out with either CLI applies to both — there is no need to authenticate separately.

## Getting help

The CLI is the authoritative source of truth. Always use `--help` to discover available commands, options, and current behavior:

```bash
codacy --help
codacy <command> --help
# e.g. codacy issues --help
```

Use `--output json` on any command for machine-readable output.

## Provider values

See the [Provider section in the glossary](references/glossary.md#provider) for the full table of CLI values (`gh`, `gl`, `bb`).

## Auto-detection of repository parameters

The CLI auto-detects the `provider`, `organization`, and `repository` from the git remote origin URL when run inside a repository. This means most commands work without specifying these parameters explicitly:

```bash
# Auto-detected (run inside the repo)
codacy issues
codacy repository
codacy pull-request 42

# Equivalent explicit form
codacy issues gh my-org my-repo
codacy repository gh my-org my-repo
codacy pull-request gh my-org my-repo 42
```

Auto-detection supports GitHub, GitLab, and Bitbucket remote URLs. If the remote cannot be parsed (e.g., non-standard hosting), pass the parameters explicitly. All examples in this document use the explicit form for clarity, but the short form is preferred when running inside a repo.

## How Codacy data works

- **Data reflects the HEAD commit** — issue lists, coverage, and security findings always show the state of the latest analyzed commit on the branch or pull request. There is no per-file or per-line historical view.
- **Configuration changes are not instant** — enabling/disabling tools or patterns, changing parameters, and ignoring issues only take effect after the next analysis. That means either triggering a reanalysis via `--reanalyze` or waiting for the next commit to be pushed.
- **Organization standards are enforced and cannot be overridden at repository level** — if a pattern is enforced by a Coding Standard at the organization level, its enabled/disabled state and parameters cannot be changed per-repository. To change it, the standard must be updated at the organization level.

### Reanalysis

Use `--reanalyze-and-wait` (`-w`) on the `repository` or `pull-request` commands to trigger reanalysis and block until it completes. The CLI captures a baseline, triggers reanalysis, polls every 10 seconds (up to 20 minutes), and reports issue deltas by pattern, severity, and category with timing information. Supports `--output json` for machine-readable delta reports.

```bash
# Trigger reanalysis and wait for results (preferred)
codacy repository gh my-org my-repo --reanalyze-and-wait
codacy repository gh my-org my-repo -w -o json    # JSON delta report

# Fire-and-forget reanalysis (no waiting)
codacy repository gh my-org my-repo --reanalyze
```

When using `--reanalyze` without `--and-wait`, check progress manually by re-running the command without `--reanalyze`:
- **Table output:** look at the "Analysis" field — `"Reanalysis in progress..."` means it is still running; `"Finished X ago"` means it is done
- **JSON output:** compare the `startedAnalysis` and `endedAnalysis` timestamps — complete when `startedAnalysis` > trigger time AND `endedAnalysis` > `startedAnalysis`

## Command reference

See [references/cloud-commands.md](references/cloud-commands.md) for details.

## Common workflows

See [references/cloud-workflows.md](references/cloud-workflows.md) for details.

## Rationalizations

| Challenge | Rationale |
|-----------|-----------|
| "I'll check it later" | Remote data changes on every push; check now while context is fresh. |
| "The CLI is too verbose" | Use `--output json` and `jq` for precise extraction. |
| "I can just check the dashboard" | CLI is faster for automation and scripting than navigating a UI. |

## Red Flags

- [ ] Suppressing findings without verifying they are actual false positives.
- [ ] Using the issue `hash` for CLI suppressions (requires numeric `resultDataId` or `issueId`).
- [ ] Assuming configuration changes take effect immediately without reanalysis.
