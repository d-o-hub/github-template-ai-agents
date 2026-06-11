# Step 4: Run analysis Details

Always use `--output-format json` for agentic workflows.

```bash
codacy-analysis analyze --output-format json

```

```bash

# Single file (positional argument)

codacy-analysis analyze ./src/main.py --output-format json

# Multiple files by path or glob (--files flag)

codacy-analysis analyze --files src/a.py src/b.py --output-format json

# Glob pattern (always quote to prevent shell expansion)

codacy-analysis analyze --files "src/**/*.ts" --output-format json

# Subdirectory

codacy-analysis analyze ./src/api/ --output-format json

```

Tool IDs are **case-sensitive**. See [references/supported-tools.md](references/supported-tools.md) for the full list.

```bash

# Single tool

codacy-analysis analyze --tool Ruff --output-format json

# Multiple tools

codacy-analysis analyze --tool Ruff --tool Bandit --output-format json

# Combine with file targeting

codacy-analysis analyze --tool ESLint9 --files "src/**/*.ts" --output-format json

```

By default `analyze` reads `.codacy/codacy.config.json`. Pass `--config-file <path>` to run with a different config — useful for comparing configurations side by side (see [Working with alternative configuration files]):

```bash
codacy-analysis analyze --config-file .codacy/auto-config.json --output-format json

```

Analyze only the code that changed, instead of the full repository:

```bash

# Only files staged for commit

codacy-analysis analyze --staged --output-format json

# Changes relative to the current branch's merge base (uncommitted + committed)

codacy-analysis analyze --diff --output-format json

# Changes in a pull request (compares against the PR's target branch)

codacy-analysis analyze --pr --output-format json

```

These flags work with `--tool`, `--files`, and all other analyze options. When combined with `--files`, the intersection is used (files that match both the git scope and the file filter).

```bash

# Run up to 4 tools in parallel

codacy-analysis analyze --parallel-tools 4 --output-format json

# Increase timeout for slow tools (default: 600000ms = 10 min)

codacy-analysis analyze --tool-timeout 600000 --output-format json

```

Fail immediately if any configured tool is unavailable (instead of skipping it):

```bash
codacy-analysis analyze --fail-if-missing --output-format json

```

```bash
codacy-analysis analyze --output-format json --output results.json

```

```bash

# Verbose logging to stderr

codacy-analysis analyze --log-level debug --output-format json

# Disable log file writing (e.g., in CI)

codacy-analysis analyze --no-log --output-format json

```
