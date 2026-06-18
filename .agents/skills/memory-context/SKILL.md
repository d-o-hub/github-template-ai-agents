---
name: memory-context
description: Retrieve semantically relevant past learnings, analysis outputs, and project context using the csm CLI (HDC encoder with hybrid BM25 retrieval). Use this skill when the user needs context retrieval, past session memory, learning recall, or wants to query the memory system for relevant documents or patterns — even if they just say "remember when we..." or "did we solve this before".
version: "0.2.10"
category: knowledge
license: MIT
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
# Index lessons (lessons.jsonl stores lesson summary text in "title")
csm index-jsonl -F agents-docs/lessons.jsonl --field title --id-field id --tag-field tags

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

Use a hard post-query cap from `.agents/config.sh`:

```bash
source .agents/config.sh
csm query "how to handle git worktree cleanup" --top-k 8 --output-format table |
awk -v max_tokens="$MAX_CONTEXT_TOKENS" '
{
    for (i = 1; i <= NF; i++) {
        if (token_count < max_tokens) {
            printf "%s%s", $i, (token_count + 1 < max_tokens ? " " : "\n")
            token_count++
        } else {
            exit
        }
    }
}
'
```

This enforces an approximate token ceiling even if retrieval output is verbose.

## See Also

- `learn` — Extract learnings into AGENTS.md
- `delegate` — Context retrieval and handoff

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll just search with grep instead" | grep finds literal text; semantic retrieval surfaces related concepts and non-obvious connections. |
| "The index is probably out of date" | A stale index is better than no index; re-index periodically rather than skipping retrieval entirely. |

## Red Flags

- [ ] Skipping index creation and assuming retrieval will work without it
- [ ] Ignoring token budget limits and flooding context with unfiltered results
- [ ] Using only keyword search when semantic relationships are needed
