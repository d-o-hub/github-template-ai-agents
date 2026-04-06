---
name: memory-context
description: Retrieve semantically relevant past learnings and analysis outputs using the csm CLI (HDC encoder with hybrid BM25 retrieval)
category: KnowledgeManagement
---

# Memory Context

Retrieve semantically relevant past learnings, analysis outputs, and project knowledge using the `csm` (Chaotic Semantic Memory) CLI.

## Prerequisites

```bash
cargo install chaotic_semantic_memory --features cli
```

## When to Use

- At session start to recall previous work
- When facing a problem that might have been solved before
- To retrieve specific findings from `analysis/` or `agents-docs/`

## Indexing (Run Once)

```bash
# Index lessons
csm index-jsonl -F agents-docs/lessons.jsonl --field lesson --id-field id --tag-field tags

# Index analysis outputs and docs
csm index-dir --glob "analysis/**/*.md" --glob "agents-docs/*.md" --heading-level 2
```

Index stored in `.git/memory-index/csm.db` (per-clone, never committed).

## Querying

```bash
# Natural language query (default: hybrid retrieval)
csm query "how to handle git worktree cleanup" --top-k 5

# Code identifier query (exact match optimized)
csm query "MAX_CONTEXT_TOKENS" --top-k 3 --output-format json

# Code-heavy query
csm query "get_user_by_id" --code-aware --top-k 5
```

## Output Formats

- `--output-format table` (default): human-readable
- `--output-format json`: machine-parseable for agent consumption
- `--output-format quiet`: IDs only

## Token Budget

Respects `MAX_CONTEXT_TOKENS` (default 4000) from `.agents/config.sh`. Use `--top-k` to control output size.
