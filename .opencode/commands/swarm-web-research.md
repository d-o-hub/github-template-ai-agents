---
description: Execute swarm analysis with optimized web research in a git worktree - PR created automatically
tools: bash, read, glob, write, edit
type: command
---

# Swarm Web Research Workflow

Execute multi-agent swarm analysis using git worktrees with optimized web research for maximum token efficiency and quality.

## Quick Usage

```
@swarm-web-research <analysis-topic> [--profile <free|fast|balanced|quality>] [--no-pr] [--cleanup]
```

### Examples

```
# Full workflow - creates worktree, runs swarm, creates PR
@swarm-web-research "API performance optimization"

# With quality profile for critical research
@swarm-web-research "React Server Components patterns" --profile quality

# Analysis only (no PR)
@swarm-web-research "Database query optimization" --no-pr

# Cleanup worktree after completion
@swarm-web-research "Testing strategies" --cleanup
```

## What It Does

1. **Creates isolated git worktree** for the analysis
2. **Generates optimized research queries** based on topic
3. **Executes 3-agent swarm** in parallel:
   - **Agent 1 (Deep Researcher)**: Web research strategies, cascade optimization
   - **Agent 2 (Quality Validator)**: Link validation, citation verification  
   - **Agent 3 (Token Optimizer)**: Cost analysis, caching strategies
4. **Synthesizes findings** into consolidated report
5. **Creates PR** with all analysis files
6. **Monitors GitHub Actions** until all checks pass

## Key Features

### Token Optimization (60-70% Savings)

```
Cascade Strategy:
  Cache (0 tokens) → llms.txt (0) → Jina (0) → Direct (0) → Firecrawl (paid)
  
Result: 65-75% of resolutions use FREE tier
```

### Quality Scoring

| Context | Min Score | Profile |
|---------|-----------|---------|
| API docs | 0.85 | quality |
| Reference | 0.80 | balanced |
| Tutorial | 0.75 | balanced |
| Quick check | 0.70 | free |

### Profile Options

| Profile | Providers | Paid | Best For |
|---------|-----------|------|----------|
| `free` | 3 | 0 | Initial exploration |
| `fast` | 2 | 1 | Quick answers (4s) |
| `balanced` | 6 | 2 | Standard work (12s) |
| `quality` | 10 | 5 | Critical analysis (20s) |

## Workflow Steps

### Phase 1: Setup (Automated)
```bash
# Create worktree for isolated analysis
git worktree add .worktrees/swarm-analysis-<timestamp> -b swarm-analysis-<timestamp>

# Create analysis structure
mkdir -p analysis/web_research reports
```

### Phase 2: Web Research (Optimized)
```bash
# Generate research queries based on topic
# Execute batch resolution with profile
# Cache results for 30 days
```

### Phase 3: Swarm Analysis (Parallel)
```
Agent 1 ──► analysis/agent1_research.md
     (Deep Researcher)
     
Agent 2 ──► analysis/agent2_validation.md
     (Quality Validator)
     
Agent 3 ──► analysis/agent3_optimization.md
     (Token Optimizer)
```

### Phase 4: Synthesis
```bash
# Combine all agent findings
# Identify consensus and conflicts
# Generate actionable recommendations
cat > analysis/SWARM_SYNTHESIS.md
```

### Phase 5: PR & Validation
```bash
# Commit all analysis files
git add analysis/
git commit -m "feat(analysis): swarm analysis..."

# Push and create PR
git push origin swarm-analysis-<timestamp>
gh pr create --title "..." --body "..."

# Monitor GitHub Actions
gh pr checks --watch
```

## Output Structure

```
analysis/
├── SWARM_SYNTHESIS.md          # Consolidated findings
├── agent1_research.md          # Deep researcher output
├── agent2_validation.md        # Quality validator output
├── agent3_optimization.md      # Token optimizer output
├── swarm_context.md            # Configuration & context
├── research_queries.txt        # Queries used
└── web_research/
    └── _summary.json           # Metrics & performance
```

## Metrics Tracked

| Metric | Target | Typical Result |
|--------|--------|----------------|
| Cache hit rate | >60% | 68% |
| Quality score | >0.75 | 0.81 |
| Token savings | >40% | 60-70% |
| Link validity | >95% | 98% |
| Cost reduction | - | 70% |

## Advanced Options

### Custom Configuration

```bash
# Environment variables for fine-tuning
export WEB_RESOLVER_PROFILE=quality      # Default profile
export WEB_RESOLVER_MAX_CHARS=8000       # Content limit
export WEB_RESOLVER_CACHE_TTL_DAYS=30    # Cache duration
export MAX_PARALLEL_FREE=5               # Concurrency
export GITHUB_TIMEOUT=3600               # Actions timeout
```

### Manual Script Usage

```bash
# Direct script execution
./scripts/swarm-worktree-web-research.sh "topic"

# With all options
./scripts/swarm-worktree-web-research.sh \
  --profile quality \
  --worktree-path ./custom-worktree \
  --cleanup \
  "analysis topic"
```

## When to Use

✅ **Use this when**:
- Researching new technology or patterns
- Optimizing existing web research workflows
- Analyzing token usage and costs
- Documenting best practices
- Creating comprehensive guides

❌ **Don't use when**:
- Simple quick lookups (use `/web-research` instead)
- Code-only analysis without web sources
- Time-critical tasks requiring <5s response

## Cost Efficiency

### Before Optimization
- Always use QUALITY profile
- No caching
- 20,000 char content
- Cost: ~$80/day for 1000 resolutions

### After Optimization
- Dynamic profile selection
- 30-day cache (68% hit rate)
- 8,000 char optimal size
- Cost: ~$24/day (70% savings)

**ROI**: <1 month (8 hours implementation)

## Troubleshooting

### Low Cache Hit Rate
```bash
# Check configuration
echo $WEB_RESOLVER_CACHE_TTL_DAYS  # Should be 30

# Warm cache for common queries
# (Re-run same topic after initial research)
```

### Quality Scores Too Low
```bash
# Switch to higher profile
@swarm-web-research "topic" --profile quality

# Increase content size
export WEB_RESOLVER_MAX_CHARS=12000
```

### Rate Limiting
```bash
# Reduce parallelism
export MAX_PARALLEL_FREE=3
export MAX_PARALLEL_PAID=2
```

## References

- `agents-docs/WEB_RESEARCH_OPTIMIZATION.md` - Full optimization guide
- `.agents/skills/do-web-doc-resolver/SKILL.md` - Resolver documentation
- `.agents/skills/agent-coordination/SWARM.md` - Swarm patterns
- `scripts/swarm-worktree-web-research.sh` - Implementation
- `.opencode/commands/web-research.md` - Simple web research command
