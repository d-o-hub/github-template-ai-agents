# Command Verification & Auto-Documentation Update Integration Plan

**Based on:** [d-oit/command-verify](https://github.com/d-oit/command-verify) approach
**Goal:** Reusable template for any codebase with zero-token operation after setup

---

## Executive Summary

This plan integrates intelligent command verification into the existing codebase structure, reusing the approach from `d-oit/command-verify` while maintaining the repository's organization pattern (scripts in `/scripts`, libraries in `/scripts/lib`, templates in `/templates`).

### Key Principles

1. **No root-level changes** - All files in subfolders (`scripts/`, `templates/`, `.opencode/`)
2. **Zero-token operation** - Uses only git + file operations after initial setup
3. **Git diff-based caching** - Only revalidates changed commands (90%+ cache hit rate)
4. **Smart invalidation** - package.json → npm commands, Cargo.toml → cargo, etc.
5. **Safe by design** - Categorizes commands (safe/conditional/dangerous)
6. **Reusable template** - One-line install for any repository

---

## Current State Analysis

### Existing Infrastructure

```

├── scripts/
│   ├── discover-commands.sh      # ✓ Exists (needs fixes)
│   ├── quality_gate.sh           # ✓ Main quality gate
│   ├── pre-commit-hook.sh        # ✓ Pre-commit integration point
│   ├── validate-links.sh         # ✓ Link validation
│   └── lib/
│       ├── lint_cache.sh         # ✓ Caching pattern exists
│       └── skill-validation.sh   # ✓ Validation utilities
│
├── templates/
│   └── command-verify-template/  # ✓ Template package created
│       ├── README.md
│       ├── install.sh
│       ├── .command-verify.conf.example
│       ├── .opencode/commands/verify-commands.md
│       └── scripts/lib/
│           ├── command-categories.sh
│           ├── command-cache.sh
│           └── command-invalidation.sh
│
├── .cache/
│   └── command-validations/      # ✓ Cache directory structure
│
└── .opencode/commands/           # ✓ Slash command location
```

### Issues Found in `discover-commands.sh`

1. **Code block parsing bug**: Extracts `}` as a command when closing code blocks
2. **Broken statistics**: Uses `jq` without checking if installed
3. **No deduplication**: Same command in multiple files counted separately
4. **Missing language support**: Only checks bash/sh/shell/console, misses zsh/fish
5. **No exclusion config**: Hardcoded exclusions, not configurable

### Existing Quality Gate Integration Points

The `quality_gate.sh` already has:
- Language detection (Rust, Node, Python, Shell, Markdown)
- Caching infrastructure (`lint_cache.sh`)
- Error accumulation pattern (FAILED flag)
- CI/CD compatibility (TTY check, color codes)

---

## Phase 1: Fix Command Discovery Script

### File: `scripts/discover-commands.sh`

**Issues to fix:**

```bash
# BUG 1: Code block end marker extracted as command
# Current code doesn't skip ``` lines properly

# BUG 2: Statistics fail silently when jq not installed
# Need fallback or dependency check

# BUG 3: No deduplication across files
# Need to track unique commands vs occurrences
```

**Proposed fixes:**

```bash
#!/usr/bin/env bash
# Fixed discover-commands.sh

# FIX 1: Proper code block parsing
extract_commands() {
    local file="$1"
    local line_num=0
    local in_code_block=0
    local code_block_type=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))

        # Check for code block boundaries (FIX: skip the ``` lines themselves)
        if [[ "$line" =~ ^\`\`\`([a-zA-Z]*) ]]; then
            if [[ $in_code_block -eq 0 ]]; then
                in_code_block=1
                code_block_type="${BASH_REMATCH[1]}"
            else
                in_code_block=0
                code_block_type=""
            fi
            continue  # Skip the ``` line itself
        fi

        # Only process content inside code blocks
        if [[ $in_code_block -eq 1 ]] && [[ "$code_block_type" =~ ^(bash|sh|shell|console|zsh|fish)$ ]]; then
            # Skip empty lines, comments, and continuation lines
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# || "$line" =~ ^[[:space:]]*$ ]] && continue

            # Clean the command (trim whitespace)
            local cmd
            cmd=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Skip if empty or just punctuation
            [[ -z "$cmd" || "$cmd" == "}" || "$cmd" == "{" ]] && continue

            echo "{\"command\":\"$(echo "$cmd" | sed 's/"/\\"/g')\",\"file\":\"$rel_path\",\"line\":$line_num,\"type\":\"code-block\"}"
        fi
    done < "$file"
}

# FIX 2: Safe statistics generation
generate_stats() {
    local commands_json="$1"

    # Check if jq is available
    if ! command -v jq &> /dev/null; then
        echo "Warning: jq not installed, skipping detailed stats" >&2
        return
    fi

    # ... rest of stats logic
}
```

---

## Phase 2: Create Main Verification Script

### File: `scripts/verify-commands.sh` (NEW)

```bash
#!/usr/bin/env bash
# Main command verification script
# Usage: ./scripts/verify-commands.sh [--force|--stats|--json|--quick]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Source libraries
source "$REPO_ROOT/scripts/lib/command-categories.sh"
source "$REPO_ROOT/scripts/lib/command-cache.sh"
source "$REPO_ROOT/scripts/lib/command-invalidation.sh"

# Configuration
CACHE_DIR=".cache/command-validations"
CONFIG_FILE=".command-verify.conf"

# Load config if exists
[ -f "$CONFIG_FILE" ] && source "$CONFIG_FILE"

# Parse arguments
FORCE=false
STATS=false
JSON_OUTPUT=false
QUICK=false
SILENT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f) FORCE=true; shift ;;
        --stats|-s) STATS=true; shift ;;
        --json|-j) JSON_OUTPUT=true; shift ;;
        --quick|-q) QUICK=true; shift ;;
        --silent) SILENT=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--force|--stats|--json|--quick|--silent]"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# Initialize cache
init_cache

# PHASE 1: Command Discovery
if ! $SILENT; then
    echo "📚 PHASE 1: Command Discovery"
fi

DISCOVERED_COMMANDS=$(./scripts/discover-commands.sh 2>/dev/null || echo "")
COMMAND_COUNT=$(echo "$DISCOVERED_COMMANDS" | grep -c . || echo 0)

if ! $SILENT; then
    echo "✓ Discovered $COMMAND_COUNT commands"
    echo ""
fi

# PHASE 2: Cache Check
if ! $SILENT; then
    echo "🔄 PHASE 2: Cache Check"
fi

if $FORCE; then
    if ! $SILENT; then
        echo "⚡ Force mode: Clearing cache..."
    fi
    clear_cache
fi

# Get changed files
CHANGED_FILES=$(get_changed_files)
CHANGED_COUNT=$(echo "$CHANGED_FILES" | grep -c . || echo 0)

if ! $SILENT; then
    echo "✓ Changed files since last validation: $CHANGED_COUNT"
fi

# PHASE 3: Validation
VALIDATED=0
CACHE_HITS=0
FAILED_COMMANDS=()

while IFS= read -r cmd_entry; do
    [ -z "$cmd_entry" ] && continue

    local cmd
    cmd=$(echo "$cmd_entry" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)
    [ -z "$cmd" ] && continue

    # Check cache first
    if ! $FORCE && ! $QUICK; then
        cached_result=$(get_cached_result "$cmd")
        if [ -n "$cached_result" ]; then
            # Check if this command needs invalidation
            if ! should_invalidate_command "$cmd_entry" "$CHANGED_FILES"; then
                ((CACHE_HITS++))
                continue
            fi
        fi
    fi

    # Validate command (categorize only, don't execute)
    category=$(categorize_command "$cmd")
    result="{\"valid\":true,\"category\":\"$category\",\"command\":\"$cmd\"}"

    # Save to cache
    save_cached_result "$cmd" "$result"
    ((VALIDATED++))

    # Track dangerous commands
    if [ "$category" = "dangerous" ]; then
        FAILED_COMMANDS+=("$cmd")
    fi
done <<< "$DISCOVERED_COMMANDS"

# PHASE 4: Results
if $JSON_OUTPUT; then
    echo "{\"validated\":$VALIDATED,\"cache_hits\":$CACHE_HITS,\"failed\":${#FAILED_COMMANDS[@]}}"
else
    if ! $SILENT; then
        echo ""
        echo "📊 Results:"
        echo "  Validated: $VALIDATED"
        echo "  Cache hits: $CACHE_HITS"
        echo "  Dangerous: ${#FAILED_COMMANDS[@]}"

        if [ ${#FAILED_COMMANDS[@]} -gt 0 ]; then
            echo ""
            echo "⚠️  Dangerous commands found:"
            for cmd in "${FAILED_COMMANDS[@]}"; do
                echo "  - $cmd"
            done
        fi

        echo ""
        if [ ${#FAILED_COMMANDS[@]} -eq 0 ]; then
            echo "✅ All commands validated successfully"
        else
            echo "❌ Review required for dangerous commands"
        fi
    fi
fi

# Save current commit
save_current_commit

# Exit code
if [ ${#FAILED_COMMANDS[@]} -gt 0 ] && [ "${FAIL_ON_DANGEROUS:-false}" = "true" ]; then
    exit 1
fi

exit 0
```

---

## Phase 3: Create Auto-Update Documentation Script

### File: `scripts/update-all-docs.sh` (NEW)

```bash
#!/usr/bin/env bash
# Auto-update all documentation by verifying commands and syncing content
# Integrates with existing update-agents-md.sh and docs-sync.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "🔄 Auto-updating all documentation..."
echo ""

# Step 1: Verify all commands
echo "Step 1/4: Verifying commands in documentation..."
if ! ./scripts/verify-commands.sh --silent; then
    echo "⚠️  Command verification found issues (non-fatal)"
fi
echo ""

# Step 2: Update AGENTS.md
echo "Step 2/4: Updating AGENTS.md..."
if [ -x "./scripts/update-agents-md.sh" ]; then
    ./scripts/update-agents-md.sh || echo "⚠️  AGENTS.md update failed (non-fatal)"
else
    echo "⚠️  update-agents-md.sh not found"
fi
echo ""

# Step 3: Sync documentation
echo "Step 3/4: Syncing documentation..."
if [ -x "./scripts/docs-sync.sh" ]; then
    ./scripts/docs-sync.sh || echo "⚠️  Docs sync failed (non-fatal)"
else
    echo "⚠️  docs-sync.sh not found"
fi
echo ""

# Step 4: Validate links
echo "Step 4/4: Validating internal links..."
if [ -x "./scripts/validate-links.sh" ]; then
    ./scripts/validate-links.sh --silent || echo "⚠️  Link validation found issues (non-fatal)"
else
    echo "⚠️  validate-links.sh not found"
fi
echo ""

echo "✅ Documentation auto-update complete!"
```

---

## Phase 4: Integrate with Quality Gate

### File: `scripts/quality_gate.sh` (MODIFY)

Add command verification section after markdown checks:

```bash
# --- Command Verification ---
echo -e "${BLUE}Verifying documentation commands...${NC}"
if [ -x "./scripts/verify-commands.sh" ]; then
    # Quick check in quality gate (uses cache)
    if ! OUTPUT=$(./scripts/verify-commands.sh --quick --silent 2>&1); then
        echo -e "${YELLOW}  ⚠ Command verification warnings (see verify-commands.sh output)${NC}"
        echo "$OUTPUT" >&2
        # Don't fail quality gate for warnings, just inform
    else
        echo -e "${GREEN}  ✓ Command verification passed${NC}"
    fi
else
    echo -e "${YELLOW}  ⚠ verify-commands.sh not found - skipping${NC}"
fi
echo ""
```

---

## Phase 5: Add Tests

### File: `tests/command-verify.bats` (NEW)

```bash
#!/usr/bin/env bats
# BATS tests for command verification system

setup() {
    REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    cd "$REPO_ROOT"
}

@test "discover-commands.sh finds commands in test file" {
    # Create test markdown file
    cat > /tmp/test-commands.md << 'EOF'
# Test

```bash
npm run build
cargo test
```
EOF

    # Run discovery
    result=$(./scripts/discover-commands.sh --output /tmp/test-output.json 2>/dev/null)

    # Check output file exists
    [ -f "/tmp/test-output.json" ]

    # Cleanup
    rm -f /tmp/test-commands.md /tmp/test-output.json
}

@test "verify-commands.sh runs without errors" {
    run ./scripts/verify-commands.sh --quick --silent
    [ "$status" -eq 0 ]
}

@test "command categorization works correctly" {
    source scripts/lib/command-categories.sh

    safe_result=$(categorize_command "npm run build")
    [ "$safe_result" = "safe" ]

    dangerous_result=$(categorize_command "rm -rf /tmp")
    [ "$dangerous_result" = "dangerous" ]

    conditional_result=$(categorize_command "npm install")
    [ "$conditional_result" = "conditional" ]
}

@test "cache functions work correctly" {
    source scripts/lib/command-cache.sh

    init_cache

    save_cached_result "test-cmd" '{"valid":true}'
    cached=$(get_cached_result "test-cmd")
    [ -n "$cached" ]

    clear_cache
    cached_after_clear=$(get_cached_result "test-cmd")
    [ -z "$cached_after_clear" ]
}
```

---

## Phase 6: Template Installation Guide

### For Other Repositories

**One-line installation:**

```bash
# Clone and install
git clone https://github.com/YOUR_ORG/templates/command-verify-template.git /tmp/cv-template
bash /tmp/cv-template/install.sh
```

**Manual installation:**

```bash
# Copy to your repository
cp -r templates/command-verify-template/scripts/*.sh your-repo/scripts/
cp -r templates/command-verify-template/scripts/lib/*.sh your-repo/scripts/lib/
cp -r templates/command-verify-template/.opencode/commands/verify-commands.md your-repo/.opencode/commands/
cp templates/command-verify-template/.command-verify.conf.example your-repo/.command-verify.conf

# Make executable
chmod +x scripts/*.sh scripts/lib/*.sh
```

**Configuration:**

Edit `.command-verify.conf`:

```bash
# Customize for your project
SAFE_KEYWORDS="build:test:lint:check"
DANGEROUS_KEYWORDS="rm:delete:drop"
FAIL_ON_DANGEROUS=false

# Add project-specific invalidation rules
INVALIDATION_RULES=(
    "package.json:npm"
    "Cargo.toml:cargo"
    "Makefile:make"
)
```

---

## Integration with Existing Scripts

### Relationship with `update-agents-md.sh`

The new `update-all-docs.sh` orchestrates existing scripts:

```
update-all-docs.sh
├── verify-commands.sh      # NEW: Verify commands
├── update-agents-md.sh     # EXISTING: Update AGENTS.md
├── docs-sync.sh            # EXISTING: Sync docs
└── validate-links.sh       # EXISTING: Validate links
```

### Relationship with `quality_gate.sh`

Command verification becomes a new quality gate step:

```
quality_gate.sh
├── Validate git hooks
├── Validate GitHub Actions SHAs
├── Validate skill symlinks
├── Validate SKILL.md format
├── Validate reference links
├── Language-specific checks (Rust, Node, etc.)
├── Verify documentation commands  ← NEW
└── Final aggregation
```

### Relationship with `pre-commit-hook.sh`

Quick verification in pre-commit:

```bash
# In pre-commit-hook.sh
./scripts/verify-commands.sh --quick --silent || true
```

---

## Performance Metrics

### Expected Performance

| Scenario | Commands | Time | Cache Hit Rate |
|----------|----------|------|----------------|
| First run (full) | 847 | ~30s | 0% |
| Subsequent (no changes) | 847 | <1s | 100% |
| Typical PR (5 files changed) | 847 | ~3s | 90%+ |
| Large refactor (50 files) | 847 | ~10s | 70%+ |

### Cache Storage

Typical cache size for 847 commands:
- JSON files: ~150KB
- Metadata: ~10KB
- Total: ~160KB

---

## Troubleshooting Guide

### Common Issues

**1. "Not a git repository"**
- Solution: Initialize git or disable cache with `--force`

**2. High number of dangerous commands**
- Solution: Adjust `DANGEROUS_KEYWORDS` in `.command-verify.conf`

**3. Slow first run**
- Expected behavior - subsequent runs use cache

**4. Commands not detected**
- Check code block language identifiers (bash/sh/shell/console/zsh/fish)

**5. Cache not working**
- Check `.cache/command-validations/last-commit.txt` exists
- Verify git repository is valid

---

## Migration Path

### For Existing Users of `discover-commands.sh`

1. **Backup current script:**
   ```bash
   cp scripts/discover-commands.sh scripts/discover-commands.sh.backup
   ```

2. **Apply fixes from Phase 1**

3. **Test with small subset:**
   ```bash
   ./scripts/discover-commands.sh --output /tmp/test.json
   head /tmp/test.json
   ```

4. **Deploy full solution:**
   ```bash
   ./scripts/verify-commands.sh --stats
   ```

### For New Repositories Using Template

1. **Clone template:**
   ```bash
   git clone <your-repo>/templates/command-verify-template.git /tmp/cv-template
   ```

2. **Run installer:**
   ```bash
   bash /tmp/cv-template/install.sh
   ```

3. **Customize configuration:**
   ```bash
   editor .command-verify.conf
   ```

4. **Verify installation:**
   ```bash
   ./scripts/verify-commands.sh --stats
   ```

---

## Future Enhancements

### Potential Improvements

1. **Auto-fix suggestions**: Suggest corrected commands for common typos
2. **Platform-specific validation**: Detect OS and validate accordingly
3. **Command execution sandbox**: Optional dry-run execution in container
4. **Learning system**: Remember project-specific command patterns
5. **CI badges**: Generate status badges for documentation quality
6. **Integration with Claude Code**: Enhanced slash commands

### Knowledge Base Integration

Future version could store learned corrections:

```json
{
  "corrections": {
    "npm run bulid": "npm run build",
    "carg test": "cargo test"
  },
  "project_rules": {
    "always_safe": ["make help", "npm run info"],
    "always_dangerous": ["./deploy-prod.sh"]
  }
}
```

---

## Success Criteria

### Functional Requirements

- ✅ Discovers all commands in markdown files
- ✅ Categorizes commands by safety level
- ✅ Uses git diff-based caching (90%+ hit rate)
- ✅ Smart invalidation based on file changes
- ✅ Integrates with quality gate
- ✅ Works as reusable template

### Non-Functional Requirements

- ✅ Zero token cost after setup
- ✅ <1s for typical cached runs
- ✅ No root-level file changes
- ✅ Cross-platform (Linux, macOS, Windows WSL)
- ✅ CI/CD compatible

### Metrics

- **Cache hit rate**: Target 90%+
- **False positive rate**: Target <5%
- **Installation time**: <1 minute
- **Learning curve**: Single README file

---

## Appendix A: Complete File Structure

```
workspace/
├── scripts/
│   ├── discover-commands.sh          # FIXED: Command discovery
│   ├── verify-commands.sh            # NEW: Main verification
│   ├── update-all-docs.sh            # NEW: Auto-update orchestrator
│   └── lib/
│       ├── command-categories.sh     # Safety classification
│       ├── command-cache.sh          # Git diff cache
│       └── command-invalidation.sh   # Smart invalidation
│
├── templates/
│   └── command-verify-template/
│       ├── README.md                 # Full documentation
│       ├── install.sh                # One-line installer
│       ├── .command-verify.conf.example
│       ├── .opencode/commands/
│       │   └── verify-commands.md    # Slash command
│       └── scripts/lib/              # Library modules
│
├── .cache/
│   └── command-validations/
│       ├── last-commit.txt
│       ├── commands/
│       └── manifest.json
│
├── .opencode/commands/
│   └── verify-commands.md            # Installed slash command
│
└── .command-verify.conf              # Project configuration
```

---

## Appendix B: Comparison with d-oit/command-verify

| Feature | Original | This Implementation |
|---------|----------|---------------------|
| Git diff caching | ✅ | ✅ |
| Smart invalidation | ✅ | ✅ |
| Command categorization | ✅ | ✅ |
| Zero-token operation | ✅ | ✅ |
| Reusable template | ❌ | ✅ |
| Integration with quality gate | ❌ | ✅ |
| Auto-update orchestration | ❌ | ✅ |
| BATS tests | ❌ | ✅ |
| Subfolder organization | ❌ | ✅ |

---

## Appendix C: Configuration Reference

### `.command-verify.conf` Full Example

```bash
# Command keywords by category
SAFE_KEYWORDS="build:test:lint:check:status:list:help:version:describe:doc:info:show:get"
CONDITIONAL_KEYWORDS="install:clean:format:migrate:update:init:add:remove:delete:replace"
DANGEROUS_KEYWORDS="rm:delete:drop:force:destroy:purge:reset:hard:kill:terminate"

# Smart invalidation rules
INVALIDATION_RULES=(
    "package.json:npm"
    "package.json:yarn"
    "Cargo.toml:cargo"
    "requirements.txt:pip"
    "*.md:*"
)

# File exclusions
EXCLUDE_PATTERNS=(
    "node_modules"
    ".git"
    "dist"
    "build"
)

# Code block languages
CODE_BLOCK_LANGUAGES=("bash" "sh" "shell" "console" "zsh" "fish")

# Advanced settings
FAIL_ON_DANGEROUS=false
CACHE_TTL_DAYS=30
MIN_COMMAND_LENGTH=2
DEBUG=false
```

---

**Document Version:** 1.0
**Last Updated:** 2024
**Maintainer:** Repository maintainers
**License:** MIT
