---
name: memory-context
description: Retrieve semantically relevant past learnings and analysis outputs using vector embeddings
category: knowledge-management
---

# Memory Context

Retrieve semantically relevant past learnings and analysis outputs to provide context for the current session.

## When to Use

- At the start of a session to recall previous work.
- When facing a problem that might have been solved before.
- To retrieve specific findings from `analysis/` or `agents-docs/LESSONS.md`.

## Capabilities

### Tier 1: Keyword Search (Default)
Fast, zero-dependency BM25-based keyword search over `lessons.jsonl`, `analysis/`, and `AGENTS.md` files.

### Tier 2: Semantic Retrieval (Optional)
Use vector embeddings for true semantic similarity. Requires `sentence-transformers` or `fastembed`.

## Usage

### Querying Memory

```bash
python .agents/skills/memory-context/scripts/query-memory.py "how to handle git worktree cleanup"
```

The tool will return the top-k most relevant entries formatted as a context block.

## Configuration

The skill respects `MAX_CONTEXT_TOKENS` from `.agents/config.sh` to ensure retrieved context doesn't overwhelm the agent.

## Implementation Details

- **Index Storage**: `.git/memory-index/` (per-clone, never committed).
- **Sources**:
  - `agents-docs/lessons.jsonl`
  - `analysis/**/*.md`
  - `**/AGENTS.md`

## Installation (Tier 2 Optional)

To enable Tier 2 semantic retrieval:
```bash
pip install fastembed
```
Then run the query script with `--semantic`:
```bash
python .agents/skills/memory-context/scripts/query-memory.py "query" --semantic
```
