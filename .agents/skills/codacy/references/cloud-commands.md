# Command reference

### Account & repositories

```bash

# Authenticated user and organizations

codacy info

# List repositories in an organization

codacy repositories <provider> <org>
codacy repositories gh my-org --search my-repo

# Repository dashboard (metrics, PRs, issues overview)

codacy repository gh my-org my-repo
codacy repository gh my-org my-repo --add       # add to Codacy

codacy repository gh my-org my-repo --remove    # remove from Codacy

codacy repository gh my-org my-repo --follow    # follow repository

codacy repository gh my-org my-repo --unfollow  # unfollow repository

codacy repository gh my-org my-repo --reanalyze            # trigger reanalysis (fire-and-forget)

codacy repository gh my-org my-repo --reanalyze-and-wait   # trigger and wait for completion with delta report

codacy repository gh my-org my-repo --link-standard <id>   # link a coding standard

codacy repository gh my-org my-repo --unlink-standard <id> # unlink a coding standard

```

### Issues (code quality)

```bash

# List issues with optional filters

codacy issues gh my-org my-repo
codacy issues gh my-org my-repo --branch main --severities Critical,High
codacy issues gh my-org my-repo --categories Security
codacy issues gh my-org my-repo --tools eslint,semgrep        # filter by detecting tool

codacy issues gh my-org my-repo --limit 500                    # fetch up to N results (default 100, max 1000)

# Overview: totals grouped by category/severity/language

codacy issues gh my-org my-repo --overview                     # short flag: -O

codacy issues gh my-org my-repo -O -o json                     # JSON — includes per-pattern issue counts and false positive counts

```

The `--overview` output includes:
- **False positive counts** per pattern — labeled as "Not a False Positive" / "Potential False Positive"
- **Suggested actions to reduce noise** — identifies patterns accounting for 10%+ of all issues or 3x the average per-pattern count, and generates ready-to-run `codacy pattern` disable commands for each. If a pattern is enforced by a coding standard or uses a config file, the suggestion adapts accordingly (e.g., suggests editing the coding standard or the config file instead)

```bash

# Full details for a single issue

codacy issue gh my-org my-repo <issueId>

# Ignore / unignore an issue

codacy issue gh my-org my-repo <issueId> --ignore
codacy issue gh my-org my-repo <issueId> --ignore --ignore-reason FalsePositive --ignore-comment "Not applicable here"
codacy issue gh my-org my-repo <issueId> --unignore

# Bulk-ignore all issues matching filters

codacy issues gh my-org my-repo --severities Minor --categories CodeStyle --ignore

```

Filters: `--branch`, `--patterns`, `--severities` (Critical,High,Medium,Minor), `--categories`, `--languages`, `--tools`, `--tags`, `--authors`

Ignore reasons: `AcceptedUse` (default) | `FalsePositive` | `NotExploitable` | `TestCode` | `ExternalCode`

### Security findings

```bash

# List findings

codacy findings gh my-org my-repo
codacy findings gh my-org                       # org-wide

codacy findings gh my-org my-repo --severities Critical,High
codacy findings gh my-org my-repo --statuses Overdue,DueSoon
codacy findings gh my-org my-repo --limit 500   # fetch up to N results (default 100, max 1000)

# Full details for a single finding (includes CVE data)

codacy finding gh my-org my-repo <findingId>

# Ignore / unignore a finding

codacy finding gh my-org my-repo <findingId> --ignore
codacy finding gh my-org my-repo <findingId> --ignore --ignore-reason FalsePositive --ignore-comment "Verified safe"
codacy finding gh my-org my-repo <findingId> --unignore

```

Filters: `--search`, `--severities` (Critical,High,Medium,Low), `--statuses` (Overdue,OnTrack,DueSoon,ClosedOnTime,ClosedLate,Ignored), `--categories`, `--scan-types`, `--dast-targets`

Ignore reasons: `AcceptedUse` (default) | `FalsePositive` | `NotExploitable` | `TestCode` | `ExternalCode`

### Pull requests

```bash

# PR summary (status, issues, coverage, changed files)

codacy pull-request gh my-org my-repo <prNumber>

# Annotated git diff with coverage and inline issues

codacy pull-request gh my-org my-repo <prNumber> --diff

# Full details for a specific issue within the PR

codacy pull-request gh my-org my-repo <prNumber> --issue <issueId>

# Ignore a specific issue in the PR

codacy pull-request gh my-org my-repo <prNumber> --ignore-issue <issueId>
codacy pull-request gh my-org my-repo <prNumber> --ignore-issue <issueId> --ignore-reason FalsePositive
codacy pull-request gh my-org my-repo <prNumber> --unignore-issue <issueId>

# Ignore all potential false positive issues in the PR at once

codacy pull-request gh my-org my-repo <prNumber> --ignore-all-false-positives

# Trigger reanalysis of PR HEAD commit

codacy pull-request gh my-org my-repo <prNumber> --reanalyze
codacy pull-request gh my-org my-repo <prNumber> --reanalyze-and-wait   # trigger and wait for completion

```

### Tools & patterns

```bash

# List all tools (enabled/disabled)

codacy tools gh my-org my-repo

# Enable or disable a tool

codacy tool gh my-org my-repo eslint --enable
codacy tool gh my-org my-repo eslint --disable
codacy tool gh my-org my-repo eslint --configuration-file true

# List patterns for a tool

codacy patterns gh my-org my-repo eslint
codacy patterns gh my-org my-repo eslint --enabled --categories Security
codacy patterns gh my-org my-repo pylint --search W0123

# Full details for a specific pattern (description, parameters, severity, category)

codacy pattern gh my-org my-repo eslint no-unused-vars

# Enable, disable, or configure a pattern

codacy pattern gh my-org my-repo eslint no-unused-vars --enable
codacy pattern gh my-org my-repo eslint no-unused-vars --disable
codacy pattern gh my-org my-repo eslint max-len --parameter max=120

# Enable or disable all patterns matching specific filters

codacy patterns gh my-org my-repo eslint --categories Security --severities Critical,High --enable-all
codacy patterns gh my-org my-repo pylint --categories CodeStyle --severities Minor --disable-all

```

**Configuration file and coding standard awareness:**
- When a tool uses a local configuration file (`--configuration-file true`), `codacy patterns` skips fetching managed patterns (they don't apply)
- When a pattern is enforced by a coding standard, `--enable`/`--disable` will refuse the operation with a message indicating which standard enforces it. Update the coding standard at the organization level instead, or unlink the standard from the repository first (`codacy repository ... --unlink-standard <id>`)

Pattern search tip: Codacy pattern IDs combine tool prefix and original ID. Use `--search` with the original ID to find them:

```bash
codacy patterns gh my-org my-repo semgrep --search HttpGetHTTPRequest
codacy patterns gh my-org my-repo pylint --search W0123

```

### Importing configuration

```bash

# Import tool and pattern configuration from a local config file

codacy tools gh my-org my-repo --import                          # imports from .codacy/codacy.config.json (default path)

codacy tools gh my-org my-repo --import ./custom-config.json     # imports from a custom path

codacy tools gh my-org my-repo --import -y                       # skip confirmation prompt

codacy tools gh my-org my-repo --import --force -y               # unlink coding standard first, then import

```

The `--import` flag reads a local `.codacy/codacy.config.json` (or a specified path) and applies the tool and pattern configuration to the Codacy Cloud repository. Use `-y` (`--skip-approval`) to skip the interactive confirmation. Use `--force` to unlink the repository from its Coding Standard before importing — this is required when org-level standards block pattern changes.

**Import behavior:**
- Preserves cloud-only tools during import — only tools supported locally are modified; cloud-only tools (e.g., SonarSharp, Codacy ScalaMeta Pro) keep their existing enabled/disabled state
- Handles config-file mode correctly — when a tool uses a local configuration file, the import skips resetting its managed patterns (they don't apply)
- Surfaces structured API error details on import failures, including which tools/patterns conflicted and why

**Note:** The `.codacy/codacy.config.json` file is for local analysis only. Committing it to the repository does NOT affect Codacy Cloud. The `--import` command is the only way to sync local config to Cloud.
