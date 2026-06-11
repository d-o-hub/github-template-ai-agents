# Step 1: Initialize configuration Details

Choose the init mode based on the repository's situation:

**Repository is in Codacy and you want its exact config:**

```bash

# Requires authentication (login or CODACY_API_TOKEN)

codacy-analysis init --remote <provider> <org> <repo>

# e.g. codacy-analysis init --remote gh my-org my-repo

```

**Repository is in Codacy but you just want sensible defaults:**

```bash

# No token needed — uses the public Codacy API for default patterns

codacy-analysis init --default

```

**Broad auto-tuned initialization (maximum pattern coverage):**

```bash

# Initializes with all patterns matching the given severity/category filter

codacy-analysis init --auto "AllCritical,High,Warning,Minor,AllSecurity,ErrorProne,Performance,BestPractice,UnusedCode,Compatibility,Complexity,Comprehensibility,CodeStyle,Documentation"

```

The `--auto` flag selects patterns broadly based on a comma-separated filter of severities and categories. Use this when you want to start with maximum coverage and then trim noise using analysis data.

**Repository is not in Codacy (local-only analysis):**

```bash

# Detects languages and tools based on local files and config

codacy-analysis init

```

**A specific directory (not the current one):**

```bash
codacy-analysis init /path/to/repo

```

All modes create `.codacy/codacy.config.json` in the repo root (or the file passed to `--config-file`, see [Working with alternative configuration files]). If a `.codacy.yaml` (or `.codacy.yml`) exists, its `exclude_paths` are automatically merged into the config.

When the config was initialized with `--remote` and you want to re-sync with the remote Codacy configuration:

```bash
codacy-analysis update-config

```

This re-fetches the configuration from the same Codacy repository used during init.

**Only use `update-config` with `--remote` configs.** For configs initialized with `--default` or bare `init`, `update-config` re-runs the original init mode, which would overwrite any manual changes you've made to the config file.

By default every command reads and writes `.codacy/codacy.config.json`. Pass `--config-file <path>` to `init`, `analyze`, and `update-config` to use a different file. This lets you keep several configurations side by side and **test them in parallel** without overwriting the main config:

```bash

# Create an alternative, broadly-tuned config in a separate file

codacy-analysis init --auto AllCritical,AllSecurity --config-file .codacy/auto-config.json

# Analyze using that config instead of the default

codacy-analysis analyze --config-file .codacy/auto-config.json --output-format json

# Regenerate it later using its original init mode (the mode is stored in the file)

codacy-analysis update-config --config-file .codacy/auto-config.json

```

`--config-file` is honored by `init` (where to create the config), `analyze` (which config to run with), and `update-config` (which config to regenerate). It defaults to `.codacy/codacy.config.json` everywhere.

The `config` command performs set operations on two config files, combining their tools and patterns. Use it to reconcile experimental configs with a baseline:

```bash

# Merge — union of tools/patterns from source into dest

codacy-analysis config --merge --source .codacy/extra.json

# Intersect — keep only tools/patterns present in BOTH files

codacy-analysis config --intersect --source a.json --dest b.json

# Diff — keep tools/patterns in dest that are NOT in source (dest − source)

codacy-analysis config --diff --source baseline.json --dest .codacy/codacy.config.json

```

- Exactly **one** of `--merge`, `--intersect`, `--diff` is required.
- `--source <path>` is **read-only** (default `.codacy/codacy.config.json`); `--dest <path>` is **overwritten** with the result (default `.codacy/codacy.config.json`).
- At least one of `--source` / `--dest` must be provided — they cannot both fall back to the same default file.

**`--dest` is overwritten in place.** Point it at a throwaway file (or back up the original first) if you need to preserve the destination config.

Use `discover` to auto-detect the repository's languages, frameworks, and libraries before initialization:

```bash
codacy-analysis discover --output-format json --output /tmp/codacy-discover.json

```

The output lists detected languages, frameworks, and the tools that apply. Use this to inform which tools and patterns to enable.

Use `info` to see which tools are available in the local Analysis CLI:

```bash
codacy-analysis info

```

This lists all tools the CLI can run locally. Compare against tools enabled in Codacy Cloud to identify cloud-only tools that the local CLI cannot run.
