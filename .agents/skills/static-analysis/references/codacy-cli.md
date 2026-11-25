> **Skill:** This reference backs the `static-analysis` skill's Codacy sections
> (content absorbed from the folded codacy skill, per ADR-038).

# Codacy CLI Reference (Analysis + Cloud)

Operational reference for the two Codacy CLIs. `static-analysis` uses it for
lint triage, PR-scoped analysis, cloud issue/PR queries, and suppression bookkeeping.

## Division of Labor: Local Analysis vs Cloud Queries

| | Analysis CLI | Cloud CLI |
|---|---|---|
| Binary | `codacy-analysis` | Cloud CLI binary (declared as `$CY` below) |
| Scope | Local static analysis without pushing | Remote Codacy data: repositories, issues, findings, PRs |
| Auth | Optional for local runs; required for `--remote` init | Required (login or `CODACY_API_TOKEN`) |
| Output | JSON `--output-format json`; exit 0/1/2 | `--output json` on any command |
| Severity scale | Error / Warning / Info | Critical / High / Medium / Low / Minor |

Both CLIs share one session: the credentials file described in the layout
section below. Logging in or out with either CLI applies to both. The vendor
token comes from Codacy > My Account > Access Management.

## Setup

```bash
# Analysis CLI (local analysis)
npm i -g @codacy/analysis-cli
# Cloud CLI (remote queries)
npm install -g @codacy/codacy-cloud-cli
# Verify
codacy-analysis --help
```

### Authentication

```bash
# Interactive login (Analysis CLI; Cloud CLI analog: $CY login)
codacy-analysis login
codacy-analysis login --token <api-token>
export CODACY_API_TOKEN=<api-token>   # alternative for both CLIs
```

## Analysis CLI Workflow (local)

Five steps, always with `--output-format json` in agentic flows:

```
1. init configuration -> 2. inspect tool availability -> 3. install deps
-> 4. analyze -> 5. interpret
```

### 1. Init configuration

All modes create the repo config (default path, see layout below); a repo
YAML `exclude_paths` entry list merges automatically.

```bash
codacy-analysis init                                  # local-only: detect languages
codacy-analysis init --default                        # public Codacy defaults
codacy-analysis init --remote gh my-org my-repo       # exact remote config (auth required)
codacy-analysis init --auto AllCritical,AllSecurity   # broad auto-tune, trim later
codacy-analysis init /path/to/repo                     # specific directory
codacy-analysis update-config                          # re-sync a config made with --remote
codacy-analysis discover --output-format json           # detected languages/frameworks
codacy-analysis info                                   # tools this CLI can run locally
```

**Only use `update-config` on configs initialized with `--remote`.** On
`--default`/bare-init configs it re-runs the original init mode and can
overwrite manual edits. `--config-file <path>` (accepted by `init`, `analyze`,
`update-config`) keeps alternative configs side by side; the `config` command
then reconciles them: exactly one of `--merge` (union), `--intersect`,
`--diff` (dest minus source); `--source` is read-only, `--dest` is overwritten in place.

### 2. Inspect tool availability

```bash
codacy-analysis analyze --inspect --output-format json
# ready tools
codacy-analysis analyze --inspect --output-format json | jq '.capability.ready[] | {toolId, version}'
# missing tools + remediation
codacy-analysis analyze --inspect --output-format json | jq '.capability.unavailable[] | {toolId, reason}'
```

### 3. Install missing dependencies

```bash
codacy-analysis analyze --install-dependencies --output-format json
```

### 4. Run analysis

Tool IDs are case-sensitive (`--tool Ruff`, `--tool ESLint9`).

```bash
# Whole repo
codacy-analysis analyze --output-format json
# Pre-commit: staged files only
codacy-analysis analyze --staged --output-format json
# Branch: all uncommitted + committed changes vs merge base
codacy-analysis analyze --diff --output-format json
# PR: changes vs the PR target branch
codacy-analysis analyze --pr --output-format json
# File targeting (intersection with the git scope when combined)
codacy-analysis analyze ./src/main.py --output-format json
codacy-analysis analyze --files "src/**/*.ts" --output-format json
# Tuning
codacy-analysis analyze --tool Ruff --tool Bandit --output-format json
codacy-analysis analyze --parallel-tools 4 --tool-timeout 600000 --output-format json
codacy-analysis analyze --fail-if-missing --output-format json
codacy-analysis analyze --output-format json --output results.json --no-log
```

### 5. Interpret results (jq)

```bash
# Count by severity
codacy-analysis analyze --staged --output-format json | \
  jq '.issues | group_by(.severity) | map({severity: .[0].severity, count: length})'
# Critical/high only
codacy-analysis analyze --staged --output-format json | \
  jq '[.issues[] | select(.severity == "Error" or .severity == "High")]'
# Group by file; per-tool summary; tool errors
codacy-analysis analyze --output-format json | jq '.issues | group_by(.filePath) | map({file: .[0].filePath, count: length})'
codacy-analysis analyze --output-format json | jq '.toolResults | map({toolId, status, issueCount, durationMs})'
codacy-analysis analyze --output-format json | jq '.errors'
```

**Exit codes:** `0` clean, `1` issues found, `2` execution error (tool crash,
missing dependency). Parse `.errors` before trusting an empty issue list.

## Cloud CLI (remote queries)

Single declaration for every cloud example in this file
(absorbed from codacy, the skill this content came from):

```bash
CY=codacy   # Cloud CLI binary (absorbed from codacy skill); every $CY line below is the Cloud CLI
```

Provider codes: `gh` GitHub, `gl` GitLab, `bb` Bitbucket, plus `ghe`/`gle`/`bbe`
enterprise variants. Auto-detect works from a git remote in some shells, but
always pass `<provider> <org> <repo>` explicitly in scripts.

```bash
# Account and repositories
$CY info
$CY repositories gh my-org --search my-repo
$CY repository gh my-org my-repo --reanalyze-and-wait   # trigger + wait (preferred)
$CY repository gh my-org my-repo -w -o json             # JSON delta report

# Issues (Code quality)
$CY issues gh my-org my-repo --branch main --severities Critical,High
$CY issues gh my-org my-repo --overview                  # false-positive counts + noise actions
$CY issue gh my-org my-repo <issueId> --ignore --ignore-reason FalsePositive \
  --ignore-comment "Not applicable here"

# Security findings (CVE data)
$CY findings gh my-org my-repo --severities Critical,High --limit 500
$CY finding gh my-org my-repo <findingId> --ignore

# Pull requests
$CY pull-request gh my-org my-repo 42                    # status, issues, coverage
$CY pull-request gh my-org my-repo 42 --diff             # annotated diff, inline issues
$CY pull-request gh my-org my-repo 42 --output json | jq '.upToStandards'   # quality gate
$CY pull-request gh my-org my-repo 42 --output json | jq '.coverage'         # coverage delta
$CY pull-request gh my-org my-repo 42 --ignore-issue <issueId> \
  --ignore-reason FalsePositive

# Tools and patterns
$CY tools gh my-org my-repo
$CY tool gh my-org my-repo eslint --enable
$CY patterns gh my-org my-repo eslint --search W0123    # search by original rule ID
$CY pattern gh my-org my-repo eslint no-unused-vars --disable

# Import local config to Cloud (only way to sync; commit alone does nothing)
$CY tools gh my-org my-repo --import                     # from repo config's default path
$CY tools gh my-org my-repo --import ./custom-config.json -y
```

Ignore reasons: `AcceptedUse` (default) | `FalsePositive` | `NotExploitable` |
`TestCode` | `ExternalCode`. CLI suppressions need the numeric `resultDataId`;
the string `hash` is for dashboard/commit-matching only. Codacy pattern IDs
combine a tool prefix with the original rule ID; find them with `--search`.

### How cloud data behaves

- Data reflects the **HEAD commit**; issue lists/coverage/findings lag live code.
- **Configuration changes are not instant** — enable/disable takes effect at the
  next analysis. Use `--reanalyze-and-wait` after config edits.
- **Organization coding standards are enforced** — repo-level enable/disable of
  a standard-managed pattern is refused; change the standard or unlink it first
  (`$CY repository gh my-org my-repo --unlink-standard <id>`).

## Configuration and State Layout

Layout summary (absorbed from codacy skill docs): the repo's `.codacy/` directory holds `codacy.config.json` plus `generated/` tool configs (gitignored); the repo YAML `.codacy.yml` (or `.codacy.yaml`) carries exclude paths and engine tuning; and `~/.codacy/` holds machine state — credentials, tool binaries, caches, and JSON-line logs rotated at 10 MB. The analyzed repository is never modified outside its `.codacy/` directory.

Repo YAML essentials:

```yaml
exclude_paths:
  - "node_modules/**"
  - "vendor/**"
engines:
  shellcheck:
    exclude_paths:
      - "scripts/legacy/**"
```

The repo config JSON (default path above) holds tools, patterns, excludes and
metadata; it only affects local analysis. Cloud picks it up solely via the
`$CY tools ... --import` flow. Validate the YAML locally with
`codacy-analysis` (CLI check: run init/analyze dry to confirm it parses).

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Tool `unavailable` in inspect | Start with `--inspect` remedy text, then `--install-dependencies` |
| No results | Config has no tools: re-run `init`, or force with `--tool <id>` |
| Tool timeout on large repo | Raise `--tool-timeout <ms>` (default 600000) |
| Wrong tools detected | Force `--tool <id>`; run `discover` to check language detection |
| Remote init auth error | `codacy-analysis login` or set `CODACY_API_TOKEN` |
| Results differ from the dashboard | `init --remote` to sync config; compare tool versions in inspect output |
| Slow full-repo run | Scope it: `--staged`, `--diff`, or `--pr` |
| Suppression rejected | Use numeric `resultDataId`, never the `hash` string |
| Config no longer matches repo | `update-config` — only for configs created with `--remote` |

Logs: the machine directory's `logs/` subtree (JSON lines). Filter errors with
`jq 'select(.level == "error")'`; use `--log-level debug` on any analyze run.

## Local Limitations

The local CLI cannot run cloud-only tools and depends on local runtimes
(e.g., Java for PMD). `codacy-analysis info` lists what is runnable here;
diffs vs the dashboard come from tool-set or version differences, not drift.
