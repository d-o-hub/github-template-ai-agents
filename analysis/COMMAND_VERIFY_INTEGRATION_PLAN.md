# Command Verification Integration Plan

## Analysis of Current State

### Existing Documentation Infrastructure

1. **267 markdown files** across the repository
2. **47 skills** in `.agents/skills/`
3. **7 commands** in `.opencode/commands/`
4. **7 agents** in `.opencode/agents/`
5. Multiple documentation folders: `agents-docs/`, `analysis/`, etc.

### Current Scripts

- `scripts/update-agents-md.sh` - Updates AGENTS.md skill table
- `scripts/validate-links.sh` - Validates reference links in SKILL.md files
- `scripts/validate-skills.sh` - Validates skill format
- `scripts/generate-skills-readme.py` - Generates skills README

### command-verify Approach (from GitHub)

Key features to adopt:
1. **Command Discovery** - Extract all commands from markdown code blocks
2. **Git Diff-Based Caching** - Only revalidate changed commands
3. **Smart Invalidation** - package.json changes → revalidate npm commands
4. **Safety Categories** - Safe/Conditional/Dangerous command classification
5. **Zero-Token Operation** - After initial setup, uses only git + file operations
6. **Cross-Platform** - Platform-aware command detection

## Implementation Plan

### Phase 1: Command Discovery Script

Create `/workspace/scripts/discover-commands.sh`:
- Scan all `.md` files for code blocks (```bash, ```shell, ```console, ```sh)
- Extract inline code commands (`npm run build`)
- Track: command text, file location, line numbers
- Output JSON structure for caching

### Phase 2: Command Categorization

Create `/workspace/scripts/lib/command-categories.sh`:
- Define SAFE commands (build, test, lint, git status)
- Define CONDITIONAL commands (npm install, format)
- Define DANGEROUS commands (rm -rf, git push --force)
- Support project-specific command patterns

### Phase 3: Git-Aware Cache System

Create `/workspace/scripts/lib/command-cache.sh`:
- Store validation results in `.cache/command-validations/`
- Track last validation commit hash
- Implement git diff-based invalidation
- Smart rules: package.json → npm commands, Cargo.toml → cargo commands

### Phase 4: Verification Command

Create `/workspace/.opencode/commands/verify-commands.md`:
- Slash command for command verification
- Integration with existing quality gate
- Report generation with cache hit rates

### Phase 5: Auto-Update Integration

Enhance existing scripts:
- Update `pre-commit-hook.sh` to trigger command discovery
- Update `quality_gate.sh` to include command verification
- Create `update-all-docs.sh` for comprehensive doc synchronization

### Phase 6: Knowledge Base

Create `.claude/knowledge.json` for self-learning:
- CLI name corrections
- Project-specific command patterns
- Validation rules
- Learning log

## File Structure

```
/workspace/
├── .cache/
│   └── command-validations/
│       ├── last-validation-commit.txt
│       ├── commands/           # Cached validation results
│       └── audit.log
├── .claude/
│   └── knowledge.json          # Self-learning memory
├── .opencode/
│   └── commands/
│       └── verify-commands.md  # New verification command
└── scripts/
    ├── discover-commands.sh    # Command discovery
    ├── verify-commands.sh      # Main verification script
    ├── update-all-docs.sh      # Comprehensive doc update
    └── lib/
        ├── command-categories.sh
        └── command-cache.sh
```

## Benefits

1. **Automated Documentation Accuracy** - Commands in docs always validated
2. **Fast Incremental Checks** - Git diff caching means <1s typical runs
3. **Safety First** - Dangerous commands never auto-executed
4. **Zero Token Cost** - After initial setup, deterministic operations only
5. **Comprehensive Coverage** - All 267 markdown files scanned
6. **Self-Learning** - System improves from corrections over time

## Migration Steps

1. Create discovery script and test on current codebase
2. Build cache infrastructure
3. Implement categorization logic
4. Create verification command
5. Integrate with quality gate
6. Add self-learning knowledge base
7. Document usage in AGENTS.md

