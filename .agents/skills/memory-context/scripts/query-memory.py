import os
import json
import argparse
import re
import glob
import math
import pickle
import hashlib
from pathlib import Path
from collections import Counter

# Basic tokenization: lowercase and alphanumeric words
# Support underscores for constants like MAX_CONTEXT_TOKENS
def tokenize(text):
    return re.findall(r'[a-z0-9_]+', text.lower())

# BM25 Constants
K1 = 1.5
B = 0.75

def get_repo_root():
    current_dir = Path.cwd()
    while current_dir != current_dir.parent:
        if (current_dir / ".agents").exists():
            return current_dir
        current_dir = current_dir.parent
    return Path.cwd()

def get_index_dir(root):
    # Store in .git/memory-index/ as requested
    git_dir = root / ".git"
    if not git_dir.exists():
        # Fallback for non-git environments
        index_dir = root / ".memory-index"
    else:
        index_dir = git_dir / "memory-index"

    index_dir.mkdir(parents=True, exist_ok=True)
    return index_dir

class BM25:
    def __init__(self, corpus):
        self.corpus_size = len(corpus)
        self.avgdl = sum(len(doc) for doc in corpus) / self.corpus_size if self.corpus_size > 0 else 0
        self.corpus = corpus
        self.f = [Counter(doc) for doc in corpus]
        self.df = Counter()
        for doc in corpus:
            for word in set(doc):
                self.df[word] += 1
        self.idf = {word: math.log((self.corpus_size - freq + 0.5) / (freq + 0.5) + 1.0)
                    for word, freq in self.df.items()}

    def get_score(self, query, index):
        score = 0.0
        doc_len = len(self.corpus[index])
        frequencies = self.f[index]
        for word in query:
            if word not in frequencies:
                continue
            freq = frequencies[word]
            score += self.idf[word] * freq * (K1 + 1) / (freq + K1 * (1 - B + B * doc_len / self.avgdl))
        return score

def load_documents(root):
    documents = []

    # 1. Load lessons.jsonl
    lessons_path = root / "agents-docs" / "lessons.jsonl"
    if lessons_path.exists():
        with open(lessons_path, "r") as f:
            for line in f:
                try:
                    data = json.loads(line)
                    # Include the actual lesson content for better retrieval
                    text = f"{data.get('id', '')} {data.get('title', '')} {data.get('component', '')} {' '.join(data.get('tags', []))} {data.get('lesson', '')}"
                    documents.append({"source": str(lessons_path.relative_to(root)), "content": text, "raw": data})
                except json.JSONDecodeError:
                    continue

    # 2. Load analysis/**/*.md
    for path_str in glob.glob(str(root / "analysis" / "**" / "*.md"), recursive=True):
        path = Path(path_str)
        if path.is_file():
            with open(path, "r") as f:
                content = f.read()
                documents.append({"source": str(path.relative_to(root)), "content": content[:1000], "raw": content})

    # 3. Load **/AGENTS.md
    for path_str in glob.glob(str(root / "**" / "AGENTS.md"), recursive=True):
        path = Path(path_str)
        if path.is_file():
            with open(path, "r") as f:
                content = f.read()
                documents.append({"source": str(path.relative_to(root)), "content": content[:1000], "raw": content})

    # 4. Load agents-docs/*.md (excluding compiled LESSONS.md to avoid redundancy with lessons.jsonl)
    for path_str in glob.glob(str(root / "agents-docs" / "*.md")):
        path = Path(path_str)
        if path.is_file() and path.name != "LESSONS.md":
            with open(path, "r", encoding="utf-8") as f:
                content = f.read()
                # Use the whole content for the searchable part
                documents.append({"source": str(path.relative_to(root)), "content": content, "raw": content})

    return documents

def get_max_tokens(root):
    config_path = root / ".agents" / "config.sh"
    if config_path.exists():
        with open(config_path, "r") as f:
            for line in f:
                if "MAX_CONTEXT_TOKENS=" in line:
                    try:
                        return int(line.split("=")[1].split()[0])
                    except (ValueError, IndexError):
                        pass
    return 4000 # Default fallback

def main():
    parser = argparse.ArgumentParser(description="Query semantic memory")
    parser.add_argument("query", help="Natural language query")
    parser.add_argument("--top-k", type=int, default=5, help="Number of results to return")
    parser.add_argument("--semantic", action="store_true", help="Use semantic embeddings (Tier 2)")
    parser.add_argument("--refresh", action="store_true", help="Force refresh of the index")
    args = parser.parse_args()

    root = get_repo_root()
    index_dir = get_index_dir(root)
    index_file = index_dir / "bm25_index.pkl"
    docs_file = index_dir / "documents.pkl"

    if args.refresh or not index_file.exists() or not docs_file.exists():
        documents = load_documents(root)
        if not documents:
            print("No documents found in memory.")
            return

        corpus = [tokenize(doc["content"]) for doc in documents]
        bm25 = BM25(corpus)

        with open(index_file, "wb") as f:
            pickle.dump(bm25, f)
        with open(docs_file, "wb") as f:
            pickle.dump(documents, f)
    else:
        with open(index_file, "rb") as f:
            bm25 = pickle.load(f)
        with open(docs_file, "rb") as f:
            documents = pickle.load(f)

    if args.semantic:
        try:
            # Placeholder for Tier 2
            # from fastembed import TextEmbedding
            print("Tier 2 (Semantic) is not fully implemented. Falling back to Tier 1.")
        except ImportError:
            print("fastembed not installed. Falling back to Tier 1.")

    query_tokens = tokenize(args.query)
    scores = [(i, bm25.get_score(query_tokens, i)) for i in range(len(documents))]
    scores.sort(key=lambda x: x[1], reverse=True)

    results = [documents[i] for i, score in scores[:args.top_k] if score > 0]

    if not results:
        print("No relevant memories found.")
        return

    max_tokens = get_max_tokens(root)
    current_tokens = 0

    print("### RETRIEVED MEMORIES")
    for doc in results:
        # Simple token estimation
        content_to_print = ""
        if isinstance(doc["raw"], dict):
            content_to_print = json.dumps(doc["raw"], indent=2)
        else:
            content_to_print = doc["raw"]

        tokens_est = len(content_to_print.split())
        if current_tokens + tokens_est > max_tokens and current_tokens > 0:
            print(f"\n--- [Truncated to stay within {max_tokens} tokens] ---")
            break

        print(f"\n--- Source: {doc['source']} ---")
        print(content_to_print)
        current_tokens += tokens_est

if __name__ == "__main__":
    main()
