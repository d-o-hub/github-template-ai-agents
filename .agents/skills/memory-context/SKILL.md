---
name: memory-context
description: Retrieve semantically relevant past learnings, analysis outputs, and project context using the csm CLI (HDC encoder with hybrid BM25 retrieval). Use this skill when the user needs context retrieval, past session memory, learning recall, or wants to query the memory system for relevant documents or patterns — even if they just say "remember when we..." or "did we solve this before". Not for learn, delegate.
version: "0.2.10"
category: knowledge
license: MIT
---

# Memory Context

Retrieve past learnings, analysis outputs, and project knowledge using the `csm` (Chaotic Semantic Memory) CLI.

## Prerequisites

```bash
cargo install chaotic_semantic_memory --features cli
```

## How Retrieval Works (Retrieval Engine Mechanics)

By default, `csm` uses Hyperdimensional Computing (HDC) combined with BM25 hybrid retrieval. This mechanism is **lexical and positional** (matching n-grams, exact tokens, and structural layout). It does NOT perform neural/dense semantic reasoning by default. Learned semantic embeddings are optional and require configuring a compatible embedding provider — never assume external model services are enabled or silently invoke third-party APIs.

## Indexing (Run Once or Update)

When indexing files, ensure all target documentation, codebase configuration, and analysis files are included in the corpus:

```bash
# Index lessons (lessons.jsonl stores lesson summary text in "title")
csm index-jsonl -F agents-docs/lessons.jsonl --field title --id-field id --tag-field tags

# Index analysis outputs, repo configs, and docs (including code configs like .agents/config.sh)
csm index-dir --glob "analysis/**/*.md" --glob "agents-docs/*.md" --glob ".agents/config.sh" --heading-level 2
```

Index stored in `.git/memory-index/csm.db` (per-clone, never committed). Files must be saved and read with UTF-8 encoding during both indexing and querying.

## Concrete Retrieval Pipeline

To ensure complete, up-to-date context and prevent hallucinating content from candidate IDs/scores alone, follow this sequence:

1. **Query in JSON Format**: Execute `csm query` with `--output-format json` to obtain structured candidate fields (`id`, `score`, `path`, `metadata`, `preview`).

   ```bash
   csm query "how to handle git worktree cleanup" --top-k 5 --output-format json
   ```

   For exact identifier or code matching:

   ```bash
   csm query "MAX_CONTEXT_TOKENS" --top-k 3 --output-format json
   csm query "get_user_by_id" --code-aware --top-k 5 --output-format json
   ```

2. **Inspect Bounded Candidates**: Review candidate matches (`id`, `score`, `path`, `metadata`, `preview`). Do NOT infer a lesson or document's full contents from its ID or score alone.

3. **Verify Source Freshness**:
   - Check if the source file at `path` exists.
   - Compare current file state (existence and last modified `mtime` or hash) against index `metadata`.
   - **Freshness Decision**: If the source file is missing, modified, or deleted, treat the candidate record as stale evidence. Re-index the target path or perform a direct source inspection. Never present deleted or stale index records as active truth.

4. **Read Source/Section Content**:
   - Fetch the actual source text from the matching source file path/heading directly (e.g., using `read_file` or file inspection).

5. **Cite Verified Source**:
   - Attribute retrieved findings directly to the verified source file path and heading/section.

## Output Formats

- `--output-format json` (recommended for programmatic usage): returns `id`, `score`, `path`, `preview`, and `metadata`.
- `--output-format table`: human-readable table containing concept IDs and scores only; requires source file reading to access full text.
- `--output-format quiet`: returns IDs only.

## Payload Budget & Bounding

Unfiltered retrieval outputs or raw file concatenation can exceed context limits.

- **Bounded UTF-8 Byte / Token Ceiling**: Enforce an explicit byte cap or tokenizer cap (e.g., matching budget limits in `.agents/config.sh`).
- **Preserve Parseable Structure**: When truncating structured payloads (such as JSON query outputs), trim array elements or field values prior to serialization. Never slice raw serialized JSON text mid-string, which creates malformed output.
- **Label Estimates**: Label word-count or character-based calculations as approximate estimates (`~tokens`) unless using an exact tokenizer.

Example JSON bounding function:

```python
import json

def bound_json_payload(items, max_bytes=4096):
    bounded = []
    current_bytes = 2  # []
    for item in items:
        serialized = json.dumps(item, ensure_ascii=False)
        item_bytes = len(serialized.encode('utf-8')) + (2 if bounded else 0)
        if current_bytes + item_bytes > max_bytes:
            break
        bounded.append(item)
        current_bytes += item_bytes
    return json.dumps(bounded, ensure_ascii=False)
```

## See Also

- `learn` — Extract learnings into AGENTS.md
- `delegate` — Context retrieval and handoff

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I'll just search with grep instead" | Grep finds literal string matches; CSM hybrid HDC/BM25 retrieval matches positional n-grams and indexed section metadata. |
| "The index is probably out of date, but I'll use the CLI output as full context anyway" | CSM CLI table/JSON output provides candidate IDs and previews, not full section source text. Always verify file freshness and read the source file directly. |

## Red Flags

- [ ] Inferring lesson or document contents from concept ID or score alone without reading the source file
- [ ] Presenting deleted or modified source files as current truth based on stale index records
- [ ] Truncating serialized JSON text mid-string, causing invalid JSON syntax
- [ ] Assuming default HDC/BM25 performs dense neural semantic reasoning or silently enabling external embedding services
- [ ] Skipping source freshness verification before incorporating retrieved context
