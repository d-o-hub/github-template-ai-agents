# Common workflows

### Quick scan of a repository not in Codacy

```bash
codacy-analysis init
codacy-analysis analyze --install-dependencies --output-format json

```

### Scan only changed files (e.g., before a commit)

```bash

# Staged files only (pre-commit check)

codacy-analysis analyze --staged --output-format json

# All changes on the current branch

codacy-analysis analyze --diff --output-format json

# Changes in a pull request

codacy-analysis analyze --pr --output-format json

```

### Reproduce Codacy remote analysis locally

```bash
codacy-analysis login --token <token>
codacy-analysis init --remote gh my-org my-repo
codacy-analysis analyze --install-dependencies --output-format json

```

### Check a single file for issues

```bash
codacy-analysis analyze ./src/main.py --output-format json

```

### Re-scan after configuration changes

```bash
codacy-analysis update-config
codacy-analysis analyze --output-format json

```

### Test two configurations side by side

```bash

# Baseline config (default location) plus an experimental, broader config

codacy-analysis init
codacy-analysis init --auto AllCritical,AllSecurity --config-file .codacy/experimental.json

# Run each independently and compare the results

codacy-analysis analyze --output-format json --output baseline-results.json
codacy-analysis analyze --config-file .codacy/experimental.json --output-format json --output experimental-results.json

# Promote the extra tools/patterns from the experiment into the baseline

codacy-analysis config --merge --source .codacy/experimental.json --dest .codacy/codacy.config.json

```

### Run only security-focused tools

```bash
codacy-analysis analyze --tool Bandit --tool Brakeman --tool Trivy --tool Semgrep --tool Checkov --output-format json

```

### Analyze a Ruby project

```bash
codacy-analysis analyze --tool RuboCop --tool Reek --tool Brakeman --output-format json

```
