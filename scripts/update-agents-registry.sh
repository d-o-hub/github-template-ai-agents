#!/usr/bin/env bash
# Auto-update AGENTS_REGISTRY.md by scanning .claude/agents/ and .opencode/agents/ directories
# Run manually or set up as a file watcher
# Usage: ./scripts/update-agents-registry.sh
# Note: OpenCode agents live in .opencode/agents/ (real files, not symlinks)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

REGISTRY_FILE="$REPO_ROOT/agents-docs/AGENTS_REGISTRY.md"
TEMP_FILE=$(mktemp /tmp/agents-registry-XXXXXX)

# Trap to clean up temp files on exit or error
trap 'rm -f "$TEMP_FILE"' EXIT ERR

echo "Scanning for agent definitions..."

# Initialize counters for summary
CLAUDE_COUNT=0
OPENCODE_COUNT=0
SKILL_COUNT=0

# Start registry file
cat > "$TEMP_FILE" << 'HEADER'
# Agents Registry

> Auto-generated registry of all sub-agents in this repository.
> Last updated: TIMESTAMP

This file provides a centralized discovery mechanism for all available sub-agents.
Agents are organized by CLI tool and purpose.

---

## Quick Reference

| Agent | CLI | Purpose | Tools |
|-------|-----|---------|-------|
HEADER

# Function to extract agent info from YAML frontmatter
extract_agent_info() {
    local file="$1"
    local cli_type="$2"
    
    # Optimized extraction using a single awk pass to avoid multiple process spawns
    awk -v cli_type="$cli_type" '
    BEGIN { name=""; desc="No description"; tools="Inherited"; in_fm=0 }
    /^---$/ {
        in_fm++;
        if (in_fm == 2) {
            if (name != "") {
                # Clean up description
                sub(/\. Invoke when.*/, "", desc);
                sub(/Invoke when.*/, "", desc);
                # Trim to 60 chars
                if (length(desc) > 60) desc = substr(desc, 1, 60);
                printf("| `%s` | %s | %s | %s |\n", name, cli_type, desc, tools);
            }

        }
        next;
    }
    in_fm == 1 {
        if (/^name:/) {
            val = $0; sub(/^name: */, "", val); gsub(/"/, "", val); name = val;
        } else if (/^description:/) {
            val = $0; sub(/^description: */, "", val); gsub(/"/, "", val); desc = val;
        } else if (/^tools:/) {
            val = $0; sub(/^tools: */, "", val); gsub(/"/, "", val); tools = val;
        }
    }
    ' "$file"
}

# Scan .claude/agents/ directory
if [ -d "$REPO_ROOT/.claude/agents" ]; then
    echo "  Found .claude/agents/"
    
    for agent_file in "$REPO_ROOT/.claude/agents"/*.md; do
        [ -f "$agent_file" ] || continue
        ((CLAUDE_COUNT++))
        extract_agent_info "$agent_file" "Claude Code" >> "$TEMP_FILE"
    done
fi

# Scan .opencode/agents/ directory
if [ -d "$REPO_ROOT/.opencode/agents" ]; then
    echo "  Found .opencode/agents/"

    for agent_file in "$REPO_ROOT/.opencode/agents"/*.md; do
        [ -f "$agent_file" ] || continue
        # Skip symlinks to .agents/skills
        [ -L "$agent_file" ] && continue
        ((OPENCODE_COUNT++))
        extract_agent_info "$agent_file" "OpenCode" >> "$TEMP_FILE"
    done
fi

# Add skills section
cat >> "$TEMP_FILE" << 'SKILLS_HEADER'

---

## Available Skills

Skills are reusable knowledge modules with progressive disclosure.
See [`agents-docs/SKILLS.md`](agents-docs/SKILLS.md) for authoring guide.

| Skill | Location | Description |
|-------|----------|-------------|
SKILLS_HEADER

# Scan .agents/skills/ directory (canonical source)
if [ -d "$REPO_ROOT/.agents/skills" ]; then
    echo "  Found .agents/skills/"
    
    for skill_dir in "$REPO_ROOT/.agents/skills"/*/; do
        [ -d "$skill_dir" ] || continue
        # Use Bash parameter expansion instead of basename
        skill_name="${skill_dir%/}"
        skill_name="${skill_name##*/}"
        
        # Skip if no SKILL.md exists
        skill_file="$skill_dir/SKILL.md"
        [ -f "$skill_file" ] || continue
        ((SKILL_COUNT++))
        
        # Optimized extraction using a single awk pass
        awk -v name="$skill_name" '
        BEGIN { display_name=name; desc="No description"; in_fm=0 }
        /^---$/ {
            in_fm++;
            if (in_fm == 2) {
                # Trim description to 60 chars
                if (length(desc) > 60) desc = substr(desc, 1, 60);
                printf("| `%s` | `.agents/skills/%s` | %s |\n", display_name, name, desc);

            }
            next;
        }
        in_fm == 1 {
            if (/^name:/) {
                val = $0; sub(/^name: */, "", val); gsub(/"/, "", val); display_name = val;
            } else if (/^description: *[>|]/) {
                desc = "";
                while (getline > 0) {
                    if (/^[a-z-]*:/) {
                        # Re-process this field line
                        if (/^name:/) {
                            val = $0; sub(/^name: */, "", val); gsub(/"/, "", val); display_name = val;
                        }
                        break;
                    }
                    if (/^---$/) {
                        # End of frontmatter
                        # Trim description to 60 chars
                        if (length(desc) > 60) desc = substr(desc, 1, 60);
                        printf("| `%s` | `.agents/skills/%s` | %s |\n", display_name, name, desc);

                    }
                    line = $0; sub(/^ +/, "", line);
                    if (line != "") desc = (desc == "" ? line : desc " " line);
                }
            } else if (/^description:/) {
                val = $0; sub(/^description: */, "", val); gsub(/"/, "", val); desc = val;
            }
        }
        ' "$skill_file" >> "$TEMP_FILE"
    done
fi

# Add footer
cat >> "$TEMP_FILE" << 'FOOTER'

---

## Adding New Agents

1. Create agent file in `.claude/agents/<agent-name>.md` (Claude Code) or `.opencode/agents/<agent-name>.md` (OpenCode)
2. Include YAML frontmatter with `name`, `description`, and `tools`
3. Run `./scripts/update-agents-registry.sh` to update this registry

### Agent File Template

```markdown
---
name: agent-name
description: What this agent does. Invoke when [specific scenarios].
tools: Read, Grep, Glob, Bash
---

# Agent Name

System prompt for the agent...
```

## Adding New Skills

1. Create skill folder in `.agents/skills/<skill-name>/`
2. Add `SKILL.md` with frontmatter (≤250 lines)
3. Run `./scripts/setup-skills.sh` to create symlinks
4. Run `./scripts/update-agents-registry.sh` to update this registry

### Skill File Template

```markdown
---
name: skill-name
description: What this skill does. Use when [specific scenarios].
---

# Skill Name

Skill instructions...
```

---

## File Watcher Setup

### VS Code

Add to `.vscode/settings.json`:

```json
{
  "files.watcherExclude": {
    "**/.git/**": true
  },
  "files.watcherInclude": [
    ".claude/agents/**/*.md",
    ".opencode/agents/**/*.md",
    ".agents/skills/**/SKILL.md"
  ]
}
```

Then use a task to run the update script on file changes.

### npm-based Watcher

```bash
npm install -g chokidar-cli

# Watch for changes and update registry
chokidar ".claude/agents/*.md" ".opencode/agents/*.md" ".agents/skills/*/SKILL.md" \
  -c "./scripts/update-agents-registry.sh && git add AGENTS_REGISTRY.md"
```

### Git Hook (Post-Merge)

Add to `.git/hooks/post-merge`:

```bash
#!/bin/bash
./scripts/update-agents-registry.sh
git add AGENTS_REGISTRY.md
```

---

*This file is auto-generated. Do not edit manually.*
*Run `./scripts/update-agents-registry.sh` to regenerate.*
FOOTER

# Update timestamp and move to final location
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")
sed -i "s/TIMESTAMP/$TIMESTAMP/" "$TEMP_FILE"
mv "$TEMP_FILE" "$REGISTRY_FILE"

echo ""
echo "✓ agents-docs/AGENTS_REGISTRY.md updated successfully"
echo "  Timestamp: $TIMESTAMP"
echo ""
echo "Agents found:"
echo "  - Claude Code: $CLAUDE_COUNT"
echo "  - OpenCode: $OPENCODE_COUNT"
echo "  - Skills: $SKILL_COUNT"
echo ""
echo "To commit changes:"
echo "  git add agents-docs/AGENTS_REGISTRY.md"
echo "  git commit -m 'docs: update agents registry'"
