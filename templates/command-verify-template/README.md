# Command Verification Template

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Intelligent command verification for documentation.** Discovers all commands in markdown files, validates them using git diff-based cache invalidation, and ensures documentation accuracy with zero token cost after initial setup.

## Features

✅ **Zero-token operation** - Base system uses only git + file operations
✅ **Git diff-based caching** - Only revalidates what actually changed
✅ **Intelligent invalidation** - package.json changed? Revalidate npm commands
✅ **Safe by design** - Never auto-executes dangerous commands
✅ **Fast** - < 1s for typical runs with cache
✅ **Complete** - Finds every command in every .md file
✅ **Cross-platform** - Works on Windows, macOS, and Linux

## Quick Start

### One-Line Installation

```bash
# Clone and install
git clone https://github.com/YOUR_ORG/command-verify-template.git /tmp/cv-template
bash /tmp/cv-template/install.sh
```

### Manual Installation

1. **Copy scripts to your repository:**

```bash
mkdir -p scripts/lib .cache/command-validations .opencode/commands
cp templates/command-verify-template/scripts/*.sh scripts/
cp templates/command-verify-template/scripts/lib/*.sh scripts/lib/
cp templates/command-verify-template/.opencode/commands/*.md .opencode/commands/
chmod +x scripts/*.sh
```

2. **Create configuration file:**

```bash
cp templates/command-verify-template/.command-verify.conf.example .command-verify.conf
```

3. **Run verification:**

```bash
./scripts/verify-commands.sh
```

## Usage

### Basic Commands

```bash
# Verify all commands (uses cache)
./scripts/verify-commands.sh

# Force full validation (bypass cache)
./scripts/verify-commands.sh --force

# Show detailed statistics
./scripts/verify-commands.sh --stats

# Output as JSON
./scripts/verify-commands.sh --json

# Quick check (cache only)
./scripts/verify-commands.sh --quick
```

### Slash Commands (Agents)

If you have Agents configured:

- `/verify` - Quick verification with cache
- `/verify-force` - Full revalidation
- `/verify-stats` - Detailed statistics
- `/update-docs` - Auto-update all documentation

## Configuration

Edit `.command-verify.conf` to customize behavior:

```bash
# Safe command keywords
SAFE_KEYWORDS="build:test:lint:check:status:list:help:version"

# Conditional command keywords
CONDITIONAL_KEYWORDS="install:clean:format:migrate:update:init"

# Dangerous command keywords (will trigger warnings)
DANGEROUS_KEYWORDS="rm:delete:drop:force:destroy:purge:reset:hard"

# Smart invalidation rules
INVALIDATION_RULES=(
    "package.json:npm"
    "package.json:yarn"
    "Cargo.toml:cargo"
    "requirements.txt:pip"
)

# Fail on dangerous commands? (true/false)
FAIL_ON_DANGEROUS=false
```

## How It Works

### 1. Command Discovery

Scans all `.md` files for code blocks:

````markdown
```bash
npm run build
cargo test
python -m pytest
```
````

Extracts commands with file location and line numbers.

### 2. Git Diff-Based Caching

```
First Run:
├── Discover all commands
├── Validate each command
└── Store results + commit hash

Subsequent Runs:
├── Get last validation commit
├── git diff --name-only <last-commit> HEAD
├── Only revalidate commands in changed files
└── Cache hit rate: typically 90%+
```

### 3. Smart Invalidation

| File Changed | Commands Revalidated |
|--------------|---------------------|
| `package.json` | All npm/yarn/pnpm commands |
| `Cargo.toml` | All cargo commands |
| `requirements.txt` | All pip/python commands |
| `*.md` | Commands in that file only |
| `src/**` | Test-related commands |

### 4. Command Categorization

Commands are classified into three categories:

- **Safe**: `build`, `test`, `lint`, `git status` - Can run without side effects
- **Conditional**: `install`, `clean`, `format` - May modify files
- **Dangerous**: `rm -rf`, `git push --force` - Potentially destructive

## Example Output

```
$ ./scripts/verify-commands.sh

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

## Integration

### Pre-commit Hook

Add to your `scripts/pre-commit-hook.sh`:

```bash
# Quick command verification
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

Integrate with your main quality gate script:

```bash
# In scripts/quality_gate.sh
echo "Verifying documentation commands..."
./scripts/verify-commands.sh || FAILED=1
```

## Project Structure

```
your-repo/
├── .cache/
│   └── command-validations/
│       ├── last-commit.txt       # Git commit hash
│       ├── commands/             # Cached validations
│       └── manifest.json         # Command index
│
├── scripts/
│   ├── discover-commands.sh      # Command discovery
│   ├── verify-commands.sh        # Main verification
│   ├── update-all-docs.sh        # Documentation orchestrator
│   └── lib/
│       ├── command-categories.sh # Safety classification
│       ├── command-cache.sh      # Cache management
│       └── command-invalidation.sh # Git diff logic
│
├── .opencode/commands/
│   ├── verify-commands.md        # Verify slash command
│   └── update-docs.md            # Update docs slash command
│
└── .command-verify.conf          # Configuration
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

First run validates all commands (no cache). Subsequent runs use git diff and are much faster.

### Commands not detected

Check code block language identifiers:
- ✅ ```bash
- ✅ ```sh
- ✅ ```shell
- ✅ ```console
- ❌ ```javascript (not scanned for commands)

## License

MIT License - See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `./scripts/verify-commands.sh --force`
5. Submit a pull request

## Acknowledgments

This template is inspired by [d-oit/command-verify](https://github.com/d-oit/command-verify) and adapted for reuse across multiple codebases.
