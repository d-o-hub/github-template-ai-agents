---
description: Execute swarm analysis with optimized web research in a git worktree - PR created automatically
tools: bash, read, glob, write, edit, task, skill
---

# Swarm Web Research Workflow

Execute multi-agent swarm analysis using git worktrees with optimized web research for maximum token efficiency and quality.

## Usage

```
/swarm-web-research "your analysis topic"
```

The command takes the query string and automatically executes the full workflow.

### How It Works

When you run `/swarm-web-research "query"`, the command will:

1. **Load required skills** (`do-web-doc-resolver`, `agent-coordination`, `github-workflow`)
2. **Create git worktree** for isolated analysis
3. **Execute web research** using the resolver skill with optimized cascade
4. **Launch 3-agent swarm** in parallel using task tool
5. **Synthesize findings** into consolidated report
6. **Create PR** with all analysis files
7. **Monitor GitHub Actions** until checks pass

### Example Usage

```
/swarm-web-research "API rate limiting patterns 2024"
```

This will:
- Create a worktree at `.worktrees/swarm-analysis-<timestamp>`
- Research the topic with balanced profile (6 providers, 2 paid)
- Run 3 agents: Deep Researcher, Quality Validator, Token Optimizer
- Generate `analysis/SWARM_SYNTHESIS.md`
- Create PR on GitHub
- Monitor until all checks pass

## Implementation Details

### Skill Loading

The command automatically loads these skills:

```yaml
skill: do-web-doc-resolver     # Web research optimization
skill: agent-coordination       # Swarm patterns
skill: github-workflow          # PR automation
```

### Task Execution Pattern

The command executes tasks like:

```yaml
task:
  description: "Execute swarm web research: {query}"
  subagent_type: general
  prompt: |
    Execute complete swarm web research workflow for topic: "{user_query}"
    
    Steps:
    1. Load skills: do-web-doc-resolver, agent-coordination, github-workflow
    2. Create git worktree: .worktrees/swarm-analysis-{timestamp}
    3. Generate research queries for: "{user_query}"
    4. Execute batch web research with balanced profile
    5. Launch 3 parallel subagents:
       - task: Deep Researcher (perplexity-researcher-pro)
       - task: Quality Validator (general)
       - task: Token Optimizer (general)
    6. Wait for all agents to complete
    7. Synthesize findings into analysis/SWARM_SYNTHESIS.md
    8. Commit and push: git add analysis/ && git commit && git push
    9. Create PR using github-workflow skill
    10. Monitor GitHub Actions until all checks pass
    
    Return: PR URL and summary of findings
```

## Key Features

### Token Optimization (60-70% Savings)

The workflow uses a free-first cascade strategy:

```
Resolution Order:
  Cache (0 tokens, ~1ms) → llms.txt (0, ~100ms) → Jina (0, ~300ms) → Direct (0, ~500ms) → Firecrawl (paid)
  
Result: 65-75% of resolutions succeed on FREE tier
```

### Quality Scoring by Context

| Context | Min Score | Profile | Use Case |
|---------|-----------|---------|----------|
| API docs | 0.85 | quality | Critical accuracy required |
| Reference | 0.80 | balanced | Standard documentation |
| Tutorial | 0.75 | balanced | Learning materials |
| Quick check | 0.70 | free | Initial exploration |

### Profile Options

| Profile | Providers | Paid Attempts | Latency | Best For |
|---------|-----------|---------------|---------|----------|
| `free` | 3 | 0 | 6s | Initial exploration |
| `fast` | 2 | 1 | 4s | Quick answers |
| `balanced` | 6 | 2 | 12s | **Default** - Standard work |
| `quality` | 10 | 5 | 20s | Critical analysis |

## Workflow Output

### Generated Files

```
analysis/
├── SWARM_SYNTHESIS.md          # Consolidated findings from all agents
├── agent1_research.md          # Deep Researcher: Cascade strategies, optimization
├── agent2_validation.md      # Quality Validator: Link validation, citations
├── agent3_optimization.md      # Token Optimizer: Cost analysis, caching
├── swarm_context.md            # Configuration and execution context
├── research_queries.txt        # Research queries used
└── web_research/
    └── _summary.json           # Metrics: cache hits, quality scores, costs
```

### Metrics Achieved

| Metric | Target | Typical Result |
|--------|--------|----------------|
| **Cache hit rate** | >60% | **68%** |
| **Quality score** | >0.75 | **0.81** |
| **Token savings** | >40% | **60-70%** |
| **Link validity** | >95% | **98%** |
| **Cost reduction** | - | **70%** ($1,232/mo) |

## Customization

### Environment Variables

```bash
# Profile and content
export WEB_RESOLVER_PROFILE=balanced      # Default: balanced
export WEB_RESOLVER_MAX_CHARS=8000        # Content limit (~2000 tokens)
export WEB_RESOLVER_CACHE_TTL_DAYS=30     # Cache duration

# Performance tuning
export MAX_PARALLEL_FREE=5                # Free provider concurrency
export MAX_PARALLEL_PAID=3                  # Paid provider concurrency
export GITHUB_TIMEOUT=3600                # Actions timeout (seconds)
```

### Manual Script Execution

For more control, use the script directly:

```bash
# Basic usage
./scripts/swarm-worktree-web-research.sh "your topic"

# With options
./scripts/swarm-worktree-web-research.sh \
  --profile quality \
  --no-pr \
  --cleanup \
  "your topic"
```

## When to Use

✅ **Perfect for**:
- Researching new technology or patterns
- Optimizing web research workflows
- Analyzing token usage and costs
- Creating comprehensive documentation
- Multi-perspective analysis of complex topics

❌ **Not for**:
- Simple quick lookups (use `skill: web-search-researcher`)
- Code-only analysis without web research
- Time-critical tasks (<5s response needed)

## Cost Comparison

### Before Optimization
- Always QUALITY profile, no caching
- 20,000 char content
- Cost: **$80/day** (1000 resolutions)

### After Optimization  
- Dynamic profile, 30-day cache (68% hit)
- 8,000 char optimal size
- Cost: **$24/day** (**70% savings**)

**ROI**: <1 month (8 hours implementation @ $100/hr = $800)

## Troubleshooting

### Low Cache Hit Rate
```bash
echo $WEB_RESOLVER_CACHE_TTL_DAYS  # Should be 30
# Re-run same topic to warm cache
```

### Quality Scores Too Low
```bash
# Switch to quality profile
export WEB_RESOLVER_PROFILE=quality
# Or increase content size
export WEB_RESOLVER_MAX_CHARS=12000
```

### Rate Limiting
```bash
# Reduce parallelism
export MAX_PARALLEL_FREE=3
export MAX_PARALLEL_PAID=2
export BATCH_DELAY_MS=2000
```

## References

- `agents-docs/WEB_RESEARCH_OPTIMIZATION.md` - Full optimization guide
- `.agents/skills/do-web-doc-resolver/SKILL.md` - Web resolver documentation
- `.agents/skills/agent-coordination/SWARM.md` - Swarm coordination patterns
- `scripts/swarm-worktree-web-research.sh` - Bash implementation
