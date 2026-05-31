# /update-docs

Auto-update all documentation with command verification and link validation.

## Description

This command orchestrates a complete documentation update process, including command verification, AGENTS.md synchronization, documentation sync, and link validation.

## Usage

```bash
/scripts/update-all-docs.sh [OPTIONS]
```

## Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be done without making changes |
| `--force` | Force update even if cache is valid |
| `--skip-verify` | Skip command verification step |
| `--skip-links` | Skip link validation step |
| `--verbose` | Show detailed output |
| `--silent` | Suppress output except errors |
| `--help` | Show help message |

## Slash Commands

### `/update-docs`

Run complete documentation update process.

**What it does:**
1. **Command Verification** - Validates all shell commands in markdown files
2. **AGENTS.md Update** - Synchronizes agent configuration documentation
3. **Documentation Sync** - Updates cross-references and generated content
4. **Link Validation** - Checks all internal links for broken references

**Example output:**

```
🔄 Starting Documentation Auto-Update...

📚 PHASE 1: Command Verification
✓ Found 267 markdown files
✓ Discovered 847 unique commands
✓ Cache hit rate: 94.2% (798/847 from cache)
⚡ Validating 49 new/changed commands...
✅ All commands validated successfully

📝 PHASE 2: AGENTS.md Synchronization
✓ Updated skill references
✓ Synchronized command definitions
✓ Refreshed configuration examples

🔗 PHASE 3: Link Validation
✓ Checked 1,234 internal links
⚠️  Found 3 broken links (see report)
✓ Fixed 2 auto-correctable links

📊 Summary:
  Files updated: 12
  Commands verified: 847
  Links checked: 1,234
  Broken links: 3
  Time elapsed: 23s

✅ Documentation update complete!
```

### `/update-docs-dry`

Preview what would be updated without making changes.

**What it shows:**
- Which files would be modified
- Which commands need revalidation
- Which links are broken
- Estimated time for full update

**Example output:**

```
🔍 Dry Run Mode - No changes will be made

Files that would be updated:
- docs/skills/README.md
- docs/api/endpoints.md
- AGENTS.md

Commands needing validation: 49
Broken links to fix: 3

Estimated update time: 23s
```

### `/update-docs-quick`

Quick update using cache only (skips full command validation).

**What it does:**
- Uses cached command validation results
- Updates only file timestamps and cross-references
- Skips link validation
- Much faster than full update

**Use when:**
- Making minor documentation edits
- Need fast iteration during writing
- Confident commands haven't changed

## How It Works

### Phase 1: Command Verification

Runs `/scripts/verify-commands.sh` to:
- Discover all shell commands in markdown code blocks
- Check git diff for changed files
- Apply smart invalidation rules
- Validate affected commands
- Categorize by safety level (safe/conditional/dangerous)

### Phase 2: AGENTS.md Synchronization

Updates the central AGENTS.md file by:
- Scanning `.agents/skills/` directory
- Extracting skill metadata (name, description, commands)
- Generating skill reference table
- Updating command index
- Synchronizing configuration examples

### Phase 3: Documentation Sync

Ensures consistency across documentation:
- Updates cross-references between files
- Regenerates table of contents
- Synchronizes version numbers
- Updates "last updated" timestamps
- Fixes relative path references

### Phase 4: Link Validation

Checks all internal links:
- Markdown links `[text](./path/to/file.md)`
- Anchor links `[text](./file.md#section)`
- Image references `![alt](./images/pic.png)`
- Reports broken links with suggestions
- Auto-fixes common issues (case sensitivity, missing extensions)

## Integration

### Pre-commit Hook

Add to your `scripts/pre-commit-hook.sh`:

```bash
# Quick documentation update check
if [[ "${DOCS_UPDATED:-}" != "true" ]]; then
    echo "Running quick docs update..."
    ./scripts/update-all-docs.sh --dry-run || true
fi
```

### CI/CD Pipeline

**GitHub Actions:**

```yaml
- name: Update Documentation
  run: ./scripts/update-all-docs.sh --verbose

- name: Commit Documentation Updates
  run: |
    git add docs/ AGENTS.md
    git commit -m "docs: auto-update documentation" || true
```

**GitLab CI:**

```yaml
update-docs:
  script:
    - ./scripts/update-all-docs.sh --verbose
  artifacts:
    paths:
      - docs/
      - AGENTS.md
```

### Scheduled Updates

**Cron job example:**

```bash
# Daily documentation update at 2 AM
0 2 * * * cd /path/to/repo && ./scripts/update-all-docs.sh --silent
```

**GitHub Actions scheduled workflow:**

```yaml
name: Daily Docs Update
on:
  schedule:
    - cron: '0 2 * * *'
jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Update Documentation
        run: ./scripts/update-all-docs.sh
      - name: Commit Changes
        run: |
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"
          git add -A
          git commit -m "docs: daily auto-update" || true
          git push
```

## Configuration

Edit `.command-verify.conf` and add documentation update settings:

```bash
# Documentation update settings
DOCS_UPDATE_ENABLED=true
DOCS_UPDATE_SKIP_VERIFY=false
DOCS_UPDATE_SKIP_LINKS=false
DOCS_UPDATE_AUTO_COMMIT=false

# Link validation settings
LINK_CHECK_EXTERNAL=false  # Don't check external links
LINK_CHECK_IGNORE="node_modules,.git,dist,build"
LINK_FIX_AUTO=true  # Auto-fix common issues

# AGENTS.md settings
AGENTS_MD_AUTO_GENERATE=true
AGENTS_MD_SKILLS_DIR=".agents/skills"
AGENTS_MD_COMMANDS_DIR=".opencode/commands"
```

## Output Files

The update process may modify:

- `AGENTS.md` - Central agent configuration
- `docs/**/*.md` - Skill and feature documentation
- `.cache/command-validations/` - Command validation cache
- `.cache/link-check-results.json` - Link validation results

## Troubleshooting

### "Too many open files"

Increase file descriptor limit:

```bash
ulimit -n 4096
```

### Link validation too slow

Disable external link checking:

```bash
LINK_CHECK_EXTERNAL=false ./scripts/update-all-docs.sh
```

### AGENTS.md not updating

Check skills directory structure:

```bash
ls -la .agents/skills/
```

Ensure each skill has a README.md with proper metadata.

### Commands failing validation

Review `.command-verify.conf`:
- Adjust keyword categories
- Set `FAIL_ON_DANGEROUS=false` for warnings
- Use `--force` to revalidate all commands

## Performance Tips

1. **Use cache**: Normal runs use git diff caching (90%+ hit rate)
2. **Quick mode**: Use `--skip-verify --skip-links` for fast iterations
3. **Incremental updates**: Only changed files trigger revalidation
4. **Parallel processing**: Link validation runs in parallel where possible

## Files

- `scripts/update-all-docs.sh` - Main orchestrator
- `scripts/verify-commands.sh` - Command verification
- `scripts/lib/command-categories.sh` - Safety classification
- `scripts/lib/command-cache.sh` - Cache management
- `scripts/validate-links.sh` - Link validation
- `scripts/sync-agents-md.sh` - AGENTS.md synchronization
- `.cache/command-validations/` - Command cache
- `.command-verify.conf` - Configuration

## Examples

### Full documentation update

```bash
./scripts/update-all-docs.sh
```

### Dry run (preview changes)

```bash
./scripts/update-all-docs.sh --dry-run
```

### Quick update (cache only)

```bash
./scripts/update-all-docs.sh --skip-verify --skip-links
```

### Verbose output for debugging

```bash
./scripts/update-all-docs.sh --verbose
```

### Update without committing dangerous commands

```bash
FAIL_ON_DANGEROUS=true ./scripts/update-all-docs.sh
```

## Related Commands

- `/verify` - Verify documentation commands only
- `/verify-stats` - Show verification statistics
- `/validate-links` - Validate links only
- `/generate-skills` - Generate skills documentation

## Best Practices

1. **Run before commits**: Always run update before committing documentation
2. **Review changes**: Check generated changes before committing
3. **Use dry-run**: Preview changes with `--dry-run` first
4. **Schedule updates**: Set up daily/weekly automated updates
5. **Monitor broken links**: Fix broken links promptly

## License

MIT License - See project LICENSE for details.
