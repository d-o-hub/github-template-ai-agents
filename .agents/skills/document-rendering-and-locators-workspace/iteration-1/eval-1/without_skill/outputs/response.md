# Annotation Anchoring for Document Version Changes

## Overview

Annotation anchoring ensures highlights, comments, and markers persist correctly positioned across document edits, insertions, deletions, and reformatting. This implementation uses content-based anchoring with fuzzy matching fallback.

## Core Architecture

### 1. Anchor Types

```typescript
type AnchorStrategy = 
  | 'exact-content'    // Hash-based content matching
  | 'contextual'       // Surrounding text pattern matching
  | 'structural'       // DOM/AST node-based positioning
  | 'fuzzy'           // Approximate string matching
  | 'composite';       // Combines multiple strategies

interface Anchor {
  id: string;
  strategy: AnchorStrategy;
  contentHash: string;
  contextBefore: string;
  contextAfter: string;
  position: number;
  confidence: number;
  version: string;
}
```

### 2. Content Hashing

```typescript
function computeContentHash(text: string): string {
  return createHash('sha256')
    .update(text.normalize('NFKD'))
    .digest('hex')
    .slice(0, 16);
}

function computeContextHash(context: string): string {
  // Normalize whitespace and case for resilience
  return computeContentHash(
    context
      .replace(/\s+/g, ' ')
      .toLowerCase()
      .trim()
  );
}
```

### 3. Anchor Creation

```typescript
function createAnchor(
  text: string,
  position: number,
  document: string,
  strategy: AnchorStrategy = 'composite'
): Anchor {
  const textSlice = text.slice(0, 200);
  const contextBefore = document.slice(
    Math.max(0, position - 100),
    position
  );
  const contextAfter = document.slice(
    position + text.length,
    Math.min(document.length, position + text.length + 100)
  );

  return {
    id: generateId(),
    strategy,
    contentHash: computeContentHash(textSlice),
    contextBefore: computeContextHash(contextBefore),
    contextAfter: computeContextHash(contextAfter),
    position,
    confidence: 1.0,
    version: getCurrentVersion()
  };
}
```

### 4. Anchor Resolution

```typescript
function resolveAnchor(
  anchor: Anchor,
  newDocument: string,
  anchors: Anchor[]
): { position: number; confidence: number } {
  // Strategy 1: Exact content match
  const exactMatch = findExactMatch(anchor, newDocument);
  if (exactMatch) return { position: exactMatch, confidence: 1.0 };

  // Strategy 2: Contextual matching
  const contextualMatch = findContextualMatch(anchor, newDocument);
  if (contextualMatch.confidence > 0.8) return contextualMatch;

  // Strategy 3: Structural (for DOM-based docs)
  const structuralMatch = findStructuralMatch(anchor, newDocument);
  if (structuralMatch) return { position: structuralMatch, confidence: 0.9 };

  // Strategy 4: Fuzzy matching
  const fuzzyMatch = findFuzzyMatch(anchor, newDocument, anchors);
  if (fuzzyMatch.confidence > 0.6) return fuzzyMatch;

  // Fallback: position-based with degraded confidence
  return { position: anchor.position, confidence: 0.3 };
}

function findExactMatch(anchor: Anchor, doc: string): number | null {
  const patterns = generateSearchPatterns(anchor.contentHash);
  for (const pattern of patterns) {
    const idx = doc.indexOf(pattern);
    if (idx !== -1) return idx;
  }
  return null;
}

function findContextualMatch(
  anchor: Anchor,
  doc: string
): { position: number; confidence: number } {
  const beforeIdx = doc.indexOf(anchor.contextBefore);
  const afterIdx = doc.indexOf(anchor.contextAfter);
  
  if (beforeIdx !== -1 && afterIdx !== -1) {
    const estimatedPos = beforeIdx + anchor.contextBefore.length;
    return { position: estimatedPos, confidence: 0.95 };
  }
  
  return { position: -1, confidence: 0 };
}
```

### 5. Fuzzy Matching with Levenshtein

```typescript
function findFuzzyMatch(
  anchor: Anchor,
  doc: string,
  existingAnchors: Anchor[]
): { position: number; confidence: number } {
  const windowSize = 50;
  const candidates = findCandidateRegions(anchor, doc);
  
  let bestMatch = { position: -1, confidence: 0 };
  
  for (const candidate of candidates) {
    const segment = doc.slice(
      candidate.position,
      candidate.position + windowSize
    );
    
    const similarity = calculateSimilarity(
      anchor.contextBefore + anchor.contextAfter,
      segment
    );
    
    if (similarity > bestMatch.confidence) {
      bestMatch = { position: candidate.position, confidence: similarity };
    }
  }
  
  return bestMatch;
}

function calculateSimilarity(a: string, b: string): number {
  // Levenshtein distance normalized to 0-1
  const maxLen = Math.max(a.length, b.length);
  if (maxLen === 0) return 1;
  
  const distance = levenshteinDistance(a.slice(0, 100), b.slice(0, 100));
  return 1 - (distance / Math.min(a.length, b.length));
}
```

### 6. Batch Anchor Migration

```typescript
async function migrateAnchors(
  oldAnchors: Anchor[],
  oldDocument: string,
  newDocument: string,
  version: string
): Promise<Anchor[]> {
  const migrations: Anchor[] = [];
  
  // Parallel resolution for performance
  const resolutions = await Promise.all(
    oldAnchors.map(anchor =>
      resolveAnchorBatch(anchor, newDocument)
    )
  );
  
  for (let i = 0; i < oldAnchors.length; i++) {
    const anchor = oldAnchors[i];
    const resolution = resolutions[i];
    
    migrations.push({
      ...anchor,
      position: resolution.position,
      confidence: resolution.confidence,
      version,
      strategy: resolution.confidence > 0.8 
        ? anchor.strategy 
        : 'fuzzy'
    });
  }
  
  return migrations;
}
```

### 7. Version Diffing

```typescript
interface DocumentDiff {
  insertions: Array<{ position: number; length: number }>;
  deletions: Array<{ position: number; length: number }>;
  modifications: Array<{ position: number; oldLength: number; newLength: number }>;
}

function computeDiff(
  oldDoc: string,
  newDoc: string
): DocumentDiff {
  const diff = {
    insertions: [],
    deletions: [],
    modifications: []
  };
  
  // Myers diff algorithm for efficient diffing
  const patches = computePatch(oldDoc, newDoc);
  
  for (const patch of patches) {
    if (patch.added) {
      diff.insertions.push({
        position: patch.start,
        length: patch.count
      });
    } else if (patch.removed) {
      diff.deletions.push({
        position: patch.start,
        length: patch.count
      });
    }
  }
  
  return diff;
}

function adjustPositionForDiff(
  position: number,
  diff: DocumentDiff
): number {
  let adjusted = position;
  
  for (const deletion of diff.deletions) {
    if (deletion.position < adjusted) {
      adjusted -= Math.min(deletion.length, adjusted - deletion.position);
    }
  }
  
  for (const insertion of diff.insertions) {
    if (insertion.position <= adjusted) {
      adjusted += insertion.length;
    }
  }
  
  return adjusted;
}
```

## Implementation Strategy

1. **Primary Anchor**: Use content hash of first 200 characters
2. **Secondary Anchor**: Context hash (50 chars before + 50 chars after)
3. **Tertiary Anchor**: Structural position in document tree
4. **Fallback**: Levenshtein-based fuzzy matching with 0.6 threshold

## Confidence Thresholds

| Confidence | Action |
|------------|--------|
| > 0.9 | Auto-migrate silently |
| 0.7 - 0.9 | Migrate with warning |
| 0.5 - 0.7 | Require user confirmation |
| < 0.5 | Mark as orphaned |

## Performance Considerations

- Cache content hashes for frequent documents
- Use Bloom filters for quick content lookup
- Batch anchor migrations in single pass
- Lazy resolution for non-visible annotations

## Edge Cases Handled

1. **Text duplication**: Context matching disambiguates
2. **Paragraph reordering**: Structural anchoring preserves
3. **Format changes**: Normalize before hashing
4. **Multi-language**: Unicode-aware normalization
5. **Concurrent edits**: Conflict resolution via timestamp
