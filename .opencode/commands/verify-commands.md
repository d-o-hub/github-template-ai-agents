# /verify-commands

Verify all commands in markdown documentation with intelligent caching.

## Description

This command discovers all shell commands in markdown files, validates them using git diff-based cache invalidation, and ensures documentation accuracy with zero token cost after initial setup.

## Usage

```bash
/scripts/verify-commands.sh [OPTIONS]
```

## Options

| Option | Description |
|--------|-------------|
| `--force` | Force full validation, bypass cache entirely |
| `--stats` | Show detailed statistics and cache performance metrics |
| `--json` | Output results as JSON for programmatic processing |
| `--quick` | Quick check using cache only (no new validations) |
| `--silent` | Suppress output except errors |
| `--help` | Show help message |

## Slash Commands

### `/verify`

Quick verification with intelligent caching.

**What it does:**
- Discovers all commands in markdown files
- Uses git diff-based cache invalidation
- Only revalidates commands affected by recent changes
- Provides cache hit rate statistics

**Example output:**

```
📚 PHASE 1: Command Discovery
✓ Found 267 markdown files
✓ Discovered 847 unique commands

🔄 PHASE 2: Cache Check
✓ Cache hit rate: 94.2% (798/847 from cache)
⚡ Validating 49 new/changed commands...

📊 Results:
  Safe commands: 623 (73.6%)
  Conditional: 178 (21.0%)
  Dangerous: 46 (5.4%) - Review required

✅ All commands validated successfully
```

### `/verify-force`

Force full command verification, bypassing the cache entirely.

**What it does:**
- Clears the validation cache
- Revalidates ALL commands from scratch
- Establishes fresh baseline

**Use when:**
- Cache may be corrupted or stale
- After bulk documentation updates
- Debugging cache invalidation issues
- Need to verify validation logic changes

### `/verify-stats`

Show detailed verification statistics and cache performance metrics.

**What it provides:**
- **Cache Performance:** Hit rates, last validation commit, cache size
- **Command Distribution:** Breakdown by category (safe/conditional/dangerous)
- **System Availability:** Which commands are installed vs unavailable
- **Invalidation Analysis:** Files changed, commands affected by changes

**Example insights:**

```
Cache Performance:
- 847 cached commands
- 94.2% hit rate
- Cache size: 156KB
- Last validation: abc123def

Command Distribution:
- Safe: 623 (73.6%)
- Conditional: 178 (21.0%)
- Dangerous: 46 (5.4%)

Files Changed Since Last Validation: 12
Commands Affected: 49
```

## How It Works

### 1. Command Discovery

Scans all `.md` files for code blocks with language identifiers:

- ```bash

- ```sh

- ```shell

- ```console

Extracts:
- Command text
- File location
- Line number
- Code block type

### 2. Git Diff-Based Caching

```
First Run:
├── Discover all commands
├── Categorize each command (safe/conditional/dangerous)
├── Store results + current commit hash
└── Cache location: .cache/command-validations/

Subsequent Runs:
├── Read last validation commit
├── git diff --name-only <last-commit> HEAD
├── Identify changed files
├── Apply invalidation rules:
│   ├── package.json → npm/yarn/pnpm commands
│   ├── Cargo.toml → cargo/rustc commands
│   ├── *.md → commands in that file
│   └── src/** → test-related commands
├── Only validate affected commands
└── Update cache
```

### 3. Smart Invalidation

| File Changed | Commands Revalidated |
|--------------|---------------------|
| `package.json` | All npm/yarn/pnpm/npx commands |
| `Cargo.toml` | All cargo/rustc commands |
| `requirements.txt` | All pip/python commands |
| `pyproject.toml` | All python/pip commands |
| `go.mod` | All go commands |
| `Gemfile` | All bundle/gem commands |
| `*.md` | Commands in that specific file |
| `src/**` | Test-related commands |

### 4. Command Categorization

Commands are classified into three safety categories:

**Safe** - No side effects:
- `cargo build`, `npm run build`
- `npm test`, `pytest`, `cargo test`
- `npm run lint`, `ruff check`
- `git status`, `git log`
- `ls`, `cat`, `grep`, `find`

**Conditional** - May modify files:
- `npm install`, `pip install`
- `cargo clean`, `npm run clean`
- `black .`, `prettier --write`
- `git add`, `git commit`

**Dangerous** - Potentially destructive:
- `rm -rf`, `del /F /S`
- `git push --force`, `git reset --hard`
- `DROP TABLE`, `DELETE FROM`
- `chmod 777`, `chown -R`

## Integration

### Pre-commit Hook

Add to your `scripts/pre-commit-hook.sh`:

```bash
# Quick command verification (cache-only)
./scripts/verify-commands.sh --quick --silent || true
```

### CI/CD Pipeline

**GitHub Actions:**

```yaml
- name: Verify Documentation Commands
  run: ./scripts/verify-commands.sh --stats
```

**GitLab CI:**

```yaml
verify-docs:
  script:
    - ./scripts/verify-commands.sh --stats
```

### Quality Gate

Integrate with your main quality gate:

```bash
# In scripts/quality_gate.sh
echo "Verifying documentation commands..."
if ! ./scripts/verify-commands.sh; then
    FAILED=1
fi
```

## Configuration

Edit `.command-verify.conf` to customize:

```bash
# Command keywords by category
SAFE_KEYWORDS="build:test:lint:check:status:list:help:version"
CONDITIONAL_KEYWORDS="install:clean:format:migrate:update:init"
DANGEROUS_KEYWORDS="rm:delete:drop:force:destroy:purge:reset:hard"

# Fail on dangerous commands?
FAIL_ON_DANGEROUS=false

# Cache TTL in days (0 = forever)
CACHE_TTL_DAYS=30
```

## Troubleshooting

### "Not a git repository"

The system works best in git repositories. For non-git repos:
- Cache will be disabled
- All commands validated on every run
- Consider initializing git: `git init`

### High number of dangerous commands

Review your `.command-verify.conf`:
- Adjust `DANGEROUS_KEYWORDS` if needed
- Set `FAIL_ON_DANGEROUS=false` for warnings only

### Slow first run

First run validates all commands (no cache). Subsequent runs use git diff and are much faster (<1s typical).

### Commands not detected

Check code block language identifiers:
- ✅ ```bash
- ✅ ```sh
- ✅ ```shell
- ✅ ```console
- ❌ ```javascript (not scanned for commands)

## Files

- `scripts/discover-commands.sh` - Command discovery
- `scripts/verify-commands.sh` - Main verification
- `scripts/lib/command-categories.sh` - Safety classification
- `scripts/lib/command-cache.sh` - Cache management
- `scripts/lib/command-invalidation.sh` - Git diff logic
- `.cache/command-validations/` - Cache directory
- `.command-verify.conf` - Configuration

## Examples

### Basic verification

```bash
./scripts/verify-commands.sh
```

### Force full validation

```bash
./scripts/verify-commands.sh --force
```

### View statistics

```bash
./scripts/verify-commands.sh --stats
```

### JSON output for CI

```bash
./scripts/verify-commands.sh --json > results.json
```

### Quick cache check

```bash
./scripts/verify-commands.sh --quick
```

## Related Commands

- `/update-docs` - Auto-update all documentation
- `/validate-links` - Validate internal links
- `/generate-skills` - Generate skills documentation

## License

MIT License - See project LICENSE for details.
