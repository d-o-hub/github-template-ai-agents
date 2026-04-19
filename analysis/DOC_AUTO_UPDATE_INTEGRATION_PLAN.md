# Documentation Auto-Update & Command Verification Integration Plan

## Executive Summary

This plan outlines how to integrate automated documentation updates and command verification into the codebase, reusing the approach from [d-oit/command-verify](https://github.com/d-oit/command-verify) while making it reusable as a template for any other codebase.

**Key Goals:**
1. ✅ Auto-discover all commands in `.md` files
2. ✅ Validate commands with git diff-based caching (zero-token after setup)
3. ✅ Auto-update documentation when code changes
4. ✅ Package as reusable template for other repositories
5. ✅ **DO NOT modify `.gitignore`** (explicit requirement)

---

## Current State Analysis

### Existing Infrastructure

**Documentation Structure:**
- 267+ markdown files across repository
- 47 skills in `.agents/skills/`
- 7 commands in `.opencode/commands/`
- 7 agents in `.opencode/agents/`
- Multiple doc folders: `agents-docs/`, `analysis/`, `examples/`

**Existing Scripts:**
| Script | Purpose | Status |
|--------|---------|--------|
| `scripts/discover-commands.sh` | Command discovery | ✅ Exists, needs fixes |
| `scripts/docs-sync.sh` | Basic doc sync via git hooks | ⚠️ Minimal implementation |
| `scripts/update-agents-md.sh` | Updates AGENTS.md skill table | ✅ Working |
| `scripts/validate-links.sh` | Validates reference links | ✅ Working |
| `scripts/quality_gate.sh` | Main quality gate | ✅ Comprehensive |
| `scripts/pre-commit-hook.sh` | Pre-commit validation | ✅ Working |

**Issues Found in `discover-commands.sh`:**
1. Extracts closing braces `}` as commands (code block parsing issue)
2. Stats calculation broken (shows "1 unique command" when there are hundreds)
3. No caching mechanism implemented yet
4. No command categorization (safe/dangerous)
5. No git diff-based invalidation

---

## command-verify Approach (Key Features to Adopt)

From analyzing https://github.com/d-oit/command-verify:

### 1. **Zero-Token Operation**
- After initial setup, uses only git + file operations
- No LLM API calls needed for routine checks
- Cache stored in `.cache/command-validations/`

### 2. **Git Diff-Based Caching**
```javascript
// Core concept:
- Store last validation commit hash
- On each run: git diff --name-only <last-commit> HEAD
- Only revalidate commands in changed files
- Typical cache hit rate: 90%+ (<1s runs)
```

### 3. **Smart Invalidation Rules**
| File Changed | Commands to Revalidate |
|--------------|----------------------|
| `package.json` | All npm/yarn/pnpm/npx commands |
| `Cargo.toml` | All cargo/rustc commands |
| `requirements.txt` | All pip/python commands |
| `*.md` | Commands in that specific file |
| `src/**` | Test-related commands |

### 4. **Command Categorization**
```javascript
SAFE_COMMANDS = ['build', 'test', 'lint', 'git status', 'cargo fmt --check']
CONDITIONAL = ['npm install', 'format', 'clean']
DANGEROUS = ['rm -rf', 'git push --force', 'DROP TABLE']
```

### 5. **Cross-Platform Awareness**
- Detect OS-specific command variants
- Windows: `dir`, `copy`, PowerShell commands
- Unix: `ls`, `cp`, bash commands
- Platform-aware validation

---

## Implementation Architecture

### Proposed File Structure

```

├── .cache/
│   └── command-validations/
│       ├── last-commit.txt           # Git commit hash
│       ├── commands/                 # Cached validation results
│       │   ├── <command-hash>.json   # Per-command cache
│       │   └── manifest.json         # All commands index
│       └── audit.log                 # Validation history
│
├── .opencode/
│   └── commands/
│       └── verify-commands.md        # New slash command
│
├── scripts/
│   ├── discover-commands.sh          # Fix existing script
│   ├── verify-commands.sh            # New: main verification
│   ├── update-all-docs.sh            # New: comprehensive doc update
│   └── lib/
│       ├── command-categories.sh     # Safe/dangerous classification
│       ├── command-cache.sh          # Cache management
│       ├── command-invalidation.sh   # Git diff logic
│       └── command-template.sh       # Template for reuse
│
└── templates/                        # NEW: Reusable template package
    └── command-verify-template/
        ├── README.md                 # Setup instructions
        ├── install.sh                # One-line install script
        ├── package.json              # Optional Node.js version
        └── scripts/                  # Copy-paste ready scripts
```

---

## Phase-by-Phase Implementation Plan

### Phase 1: Fix Command Discovery Script

**File:** `scripts/discover-commands.sh`

**Issues to Fix:**
1. Code block parser extracts `}` as commands
2. Stats calculation broken (jq not handling input correctly)
3. Need to filter out non-command lines

**Solution:**
```bash
# Improved extraction logic
extract_commands() {
    local file="$1"
    local in_code_block=0
    local code_block_type=""

    while IFS= read -r line; do
        # Better code block detection
        if [[ "$line" =~ ^\`\`\`([a-zA-Z]*) ]]; then
            in_code_block=$((1 - in_code_block))
            code_block_type="${BASH_REMATCH[1]}"
            continue
        fi

        # Only extract actual commands (not closing braces, etc.)
        if [[ $in_code_block -eq 1 ]] && [[ "$code_block_type" =~ ^(bash|sh|shell|console)$ ]]; then
            # Skip lines that are clearly not commands
            [[ "$line" =~ ^[\}\]\)] ]] && continue
            [[ "$line" =~ ^[[:space:]]*$ ]] && continue

            # Trim and validate
            local cmd=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [[ ${#cmd} -lt 2 ]] && continue

            # Output valid command
            echo "{\"command\":\"$cmd\",\"file\":\"$file\",...}"
        fi
    done < "$file"
}
```

**Deliverables:**
- [ ] Fixed `discover-commands.sh`
- [ ] Proper JSON output
- [ ] Accurate statistics

---

### Phase 2: Command Categorization Library

**File:** `scripts/lib/command-categories.sh`

```bash
#!/usr/bin/env bash
# Command categorization for safety assessment

CATEGORIES=(
    "safe:build:test:lint:check:status:list:help:version"
    "conditional:install:clean:format:migrate:update"
    "dangerous:rm:delete:drop:force:destroy:purge"
)

categorize_command() {
    local cmd="$1"

    for category_def in "${CATEGORIES[@]}"; do
        IFS=':' read -r category keywords <<< "$category_def"
        for keyword in $keywords; do
            if [[ "$cmd" == *"$keyword"* ]]; then
                echo "$category"
                return 0
            fi
        done
    done

    echo "unknown"
}

# Project-specific overrides (via .command-verify.conf)
if [ -f ".command-verify.conf" ]; then
    source ".command-verify.conf"
fi
```

**Deliverables:**
- [ ] Categorization function
- [ ] Config file support for project-specific rules
- [ ] Dangerous command warnings

---

### Phase 3: Git-Aware Cache System

**File:** `scripts/lib/command-cache.sh`

```bash
#!/usr/bin/env bash
# Git diff-based cache management

CACHE_DIR=".cache/command-validations"
LAST_COMMIT_FILE="$CACHE_DIR/last-commit.txt"

get_last_commit() {
    if [ -f "$LAST_COMMIT_FILE" ]; then
        cat "$LAST_COMMIT_FILE"
    else
        echo ""
    fi
}

save_current_commit() {
    git rev-parse HEAD > "$LAST_COMMIT_FILE"
}

get_changed_files() {
    local last_commit=$(get_last_commit)
    if [ -z "$last_commit" ]; then
        # First run - all files changed
        git ls-files "*.md"
    else
        git diff --name-only "$last_commit" HEAD -- "*.md"
    fi
}

should_invalidate_command() {
    local cmd="$1"
    local changed_files="$2"

    # Check if any changed file affects this command
    for file in $changed_files; do
        # Rule 1: MD file change → commands in that file
        if [[ "$cmd" == *"$(basename "$file")"* ]]; then
            return 0
        fi

        # Rule 2: package.json → npm commands
        if [[ "$file" == "package.json" ]] && [[ "$cmd" =~ ^(npm|yarn|pnpm) ]]; then
            return 0
        fi

        # Rule 3: Cargo.toml → cargo commands
        if [[ "$file" == "Cargo.toml" ]] && [[ "$cmd" =~ ^cargo ]]; then
            return 0
        fi
    done

    return 1  # No invalidation needed
}
```

**Deliverables:**
- [ ] Cache directory structure
- [ ] Commit tracking
- [ ] Smart invalidation rules

---

### Phase 4: Verification Command

**File:** `.opencode/commands/verify-commands.md`

```markdown
# /verify-commands

Verify all commands in markdown documentation with intelligent caching.

## Usage

```bash
/scripts/verify-commands.sh [OPTIONS]
```

## Options

- `--force` - Force full validation, bypass cache
- `--stats` - Show detailed statistics
- `--json` - Output results as JSON
- `--dry-run` - Show what would be validated without running

## What It Does

1. Discovers all commands in `.md` files
2. Checks cache for previous validations
3. Uses git diff to determine what needs re-validation
4. Categorizes commands (safe/conditional/dangerous)
5. Reports cache hit rate and validation results

## Example Output

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

## Slash Command Integration

When using Claude Code:
- `/verify` - Quick verification with cache
- `/verify-force` - Full revalidation
- `/verify-stats` - Detailed statistics
```

**Deliverables:**
- [ ] Command definition file
- [ ] Integration with existing quality gate
- [ ] Statistics reporting

---

### Phase 5: Auto-Update Documentation System

**File:** `scripts/update-all-docs.sh`

```bash
#!/usr/bin/env bash
# Comprehensive documentation auto-update

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "🔄 Starting documentation auto-update..."

# 1. Update skill table in AGENTS.md
echo "  📝 Updating AGENTS.md skill table..."
./scripts/update-agents-md.sh

# 2. Discover and verify commands
echo "  🔍 Discovering commands..."
./scripts/discover-commands.sh --output .cache/commands.json

# 3. Generate AVAILABLE_SKILLS.md from .agents/skills/
echo "  📚 Regenerating AVAILABLE_SKILLS.md..."
./scripts/generate-available-skills.sh

# 4. Validate all internal links
echo "  🔗 Validating links..."
./scripts/validate-links.sh

# 5. Run command verification
echo "  ✅ Verifying commands..."
./scripts/verify-commands.sh

# 6. Generate changelog from commits
echo "  📋 Updating CHANGELOG.md..."
# (Optional: implement changelog generation)

echo ""
echo "✅ Documentation update complete!"
echo ""
echo "Changed files:"
git status --short "*.md"
```

**Integration Points:**
- Pre-commit hook: Run quick validation
- CI pipeline: Full verification
- Manual trigger: `/update-docs` command

**Deliverables:**
- [ ] Unified update script
- [ ] Pre-commit integration
- [ ] CI workflow

---

### Phase 6: Reusable Template Package

**Directory:** `templates/command-verify-template/`

This is the key deliverable for reusability across codebases.

#### Template Structure

```
templates/command-verify-template/
├── README.md                 # Installation & usage guide
├── install.sh                # One-line installation
├── .command-verify.conf.example  # Configuration template
├── scripts/
│   ├── discover-commands.sh  # Copy to target repo
│   ├── verify-commands.sh    # Copy to target repo
│   └── lib/
│       ├── command-categories.sh
│       ├── command-cache.sh
│       └── command-invalidation.sh
└── .opencode/
    └── commands/
        └── verify-commands.md
```

#### Installation Script

**File:** `templates/command-verify-template/install.sh`

```bash
#!/usr/bin/env bash
# One-line installation for any repository

set -euo pipefail

TARGET_DIR="${1:-.}"
TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "📦 Installing command-verify template..."

# Create directories
mkdir -p "$TARGET_DIR/scripts/lib"
mkdir -p "$TARGET_DIR/.cache/command-validations"
mkdir -p "$TARGET_DIR/.opencode/commands"

# Copy scripts
cp "$TEMPLATE_DIR/scripts/"*.sh "$TARGET_DIR/scripts/"
cp "$TEMPLATE_DIR/scripts/lib/"*.sh "$TARGET_DIR/scripts/lib/"
cp "$TEMPLATE_DIR/.opencode/commands/verify-commands.md" "$TARGET_DIR/.opencode/commands/"

# Copy config template
cp "$TEMPLATE_DIR/.command-verify.conf.example" "$TARGET_DIR/.command-verify.conf"

# Make executable
chmod +x "$TARGET_DIR/scripts/"*.sh

# Add to pre-commit hook (optional)
if [ -f "$TARGET_DIR/scripts/pre-commit-hook.sh" ]; then
    echo ""
    echo "⚠️  To integrate with pre-commit, add this line to your pre-commit hook:"
    echo '   ./scripts/verify-commands.sh --quick'
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/verify-commands.sh"
echo "  2. Customize: .command-verify.conf"
echo "  3. (Optional) Add to CI/CD pipeline"
```

#### Configuration Template

**File:** `templates/command-verify-template/.command-verify.conf.example`

```bash
# Command Verification Configuration
# Copy to .command-verify.conf and customize

# Categories (colon-separated keywords)
SAFE_KEYWORDS="build:test:lint:check:status:list:help:version:describe"
CONDITIONAL_KEYWORDS="install:clean:format:migrate:update:init"
DANGEROUS_KEYWORDS="rm:delete:drop:force:destroy:purge:reset:hard"

# File patterns for smart invalidation
# Format: FILE_PATTERN:COMMAND_PREFIX
INVALIDATION_RULES=(
    "package.json:npm"
    "package.json:yarn"
    "package.json:pnpm"
    "Cargo.toml:cargo"
    "requirements.txt:pip"
    "pyproject.toml:python"
    "go.mod:go"
)

# Exclude patterns (files to skip)
EXCLUDE_PATTERNS=(
    "node_modules"
    ".git"
    "dist"
    "build"
    "target"
    "vendor"
)

# Knowledge base path (optional)
# KNOWLEDGE_BASE_PATH=".claude/knowledge.json"

# Fail on dangerous commands? (true/false)
FAIL_ON_DANGEROUS=false

# Cache TTL in days (0 = forever)
CACHE_TTL_DAYS=30
```

**Deliverables:**
- [ ] Complete template package
- [ ] One-line install script
- [ ] Configuration examples
- [ ] Documentation for template users

---

## Integration with Existing Quality Gate

### Modify `scripts/quality_gate.sh`

Add this section after language-specific checks:

```bash
# --- Command Verification in Documentation ---
echo -e "${BLUE}Verifying documentation commands...${NC}"

if [ -f "./scripts/verify-commands.sh" ]; then
    # Quick check in pre-commit, full check in CI
    if [ "${CI:-false}" = "true" ] || [ "${FULL_CHECK:-false}" = "true" ]; then
        if ! OUTPUT=$(./scripts/verify-commands.sh 2>&1); then
            echo -e "${RED}  ✗ Command verification failed${NC}"
            echo "$OUTPUT" >&2
            FAILED=1
        else
            echo -e "${GREEN}  ✓ Command verification passed${NC}"
        fi
    else
        # Quick cache check only
        if ! OUTPUT=$(./scripts/verify-commands.sh --quick 2>&1); then
            echo -e "${YELLOW}  ⚠ Command verification skipped (run manually)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}  ⚠ verify-commands.sh not found - skipping${NC}"
fi
echo ""
```

### Modify `scripts/pre-commit-hook.sh`

Add lightweight check:

```bash
# Quick command verification (cache-only)
if [ -f "./scripts/verify-commands.sh" ]; then
    ./scripts/verify-commands.sh --quick --silent || true
fi
```

---

## Testing Strategy

### Unit Tests for Scripts

Create `tests/command-verify.bats`:

```bash
#!/usr/bin/env bats

@test "discover-commands finds bash commands" {
    run ./scripts/discover-commands.sh
    assert_output --partial '"type":"code-block"'
}

@test "discover-commands ignores closing braces" {
    run ./scripts/discover-commands.sh
    refute_output --partial '"command":"}"'
}

@test "verify-commands uses cache" {
    # First run populates cache
    ./scripts/verify-commands.sh

    # Second run should use cache
    run ./scripts/verify-commands.sh
    assert_output --partial "Cache hit rate"
}

@test "categorize-command identifies safe commands" {
    source scripts/lib/command-categories.sh
    result=$(categorize_command "cargo test")
    assert_equal "$result" "safe"
}

@test "categorize-command identifies dangerous commands" {
    source scripts/lib/command-categories.sh
    result=$(categorize_command "rm -rf /")
    assert_equal "$result" "dangerous"
}
```

### Integration Tests

1. **Fresh Install Test**: Clone template, run install, verify commands work
2. **Cache Invalidation Test**: Change package.json, verify npm commands revalidated
3. **CI Pipeline Test**: Run full verification in CI environment

---

## Metrics & Success Criteria

| Metric | Target | Measurement |
|--------|--------|-------------|
| Command discovery accuracy | >99% | Manual sampling of output |
| Cache hit rate | >90% | `--stats` output |
| Verification speed (cached) | <1s | Time command execution |
| Verification speed (full) | <30s | Time full validation |
| False positives (dangerous) | 0 | Manual review |
| Template adoption | Any repo | Successful install test |

---

## Migration Steps

### For This Repository

1. **Week 1**: Fix `discover-commands.sh` (Phase 1)
2. **Week 1**: Implement categorization (Phase 2)
3. **Week 2**: Build cache system (Phase 3)
4. **Week 2**: Create verification command (Phase 4)
5. **Week 3**: Auto-update integration (Phase 5)
6. **Week 3**: Package template (Phase 6)
7. **Week 4**: Testing & documentation

### For Other Repositories (Template Users)

One-line installation:

```bash
# Clone and install
git clone https://github.com/YOUR_REPO/templates/command-verify-template.git /tmp/cv-template
bash /tmp/cv-template/install.sh

# Verify installation
./scripts/verify-commands.sh
```

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing scripts | High | Backward-compatible changes, feature flags |
| Performance degradation | Medium | Cache-first design, benchmark before/after |
| False positives on dangerous cmds | High | Conservative categorization, manual review mode |
| Template incompatibility | Medium | Extensive testing on different repo types |
| Git repo requirement | Low | Graceful fallback for non-git repos |

---

## Future Enhancements

1. **LLM Integration** (Optional):
   - Use Claude to suggest command corrections
   - Auto-generate examples for undocumented commands

2. **Multi-Language Support**:
   - PowerShell commands on Windows
   - Rake/Ruby commands
   - Maven/Gradle for Java

3. **Dashboard/Reporting**:
   - Web UI for command statistics
   - Trend analysis over time
   - Team-wide command usage patterns

4. **IDE Plugins**:
   - VSCode extension for real-time validation
   - Inline warnings for dangerous commands

5. **Community Templates**:
   - Language-specific template packs
   - Framework-specific rules (React, Django, etc.)

---

## Conclusion

This plan provides a comprehensive approach to:
1. ✅ Fix and enhance existing command discovery
2. ✅ Implement git diff-based caching (zero-token operation)
3. ✅ Auto-update documentation when code changes
4. ✅ Package everything as a reusable template
5. ✅ Integrate seamlessly with existing quality gates
6. ✅ **Respect the constraint: DO NOT modify `.gitignore`**

The template package ensures any repository can adopt this system with a one-line installation, while the modular design allows customization for specific project needs.

**Next Step:** Begin Phase 1 by fixing the `discover-commands.sh` script to properly parse code blocks and calculate accurate statistics.
