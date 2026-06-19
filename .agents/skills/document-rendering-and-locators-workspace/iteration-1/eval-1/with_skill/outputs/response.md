# Annotation Anchoring Implementation

Resilient annotation anchoring that survives document version changes.

## 1. Data Model

Multi-signal locator schema combining position, text, chapter, and element signals:

```typescript
interface Locator {
  version: 1;
  position: string;        // CFI or offset-based position
  selectedText: string;    // Text excerpt for fuzzy matching
  chapterRef: string;      // Chapter/section identifier
  elementIndex: number;    // Element index within document
  charOffset: number;      // Character offset within text node
  precedingContext: string; // ~50 chars before selection
  followingContext: string; // ~50 chars after selection
}
```

```typescript
interface Annotation {
  id: string;
  locator: Locator;
  content: string;
  createdAt: string;
  updatedAt: string;
}
```

Serialization uses stable casing and schema versioning for forward compatibility.

## 2. Anchor Design

DOM selection mapping:

```typescript
function selectionToLocator(selection: Selection, document: Document): Locator {
  const range = selection.getRangeAt(0);
  const container = range.startContainer;
  const offset = range.startOffset;

  return {
    version: 1,
    position: computePosition(range, document),
    selectedText: selection.toString(),
    chapterRef: findChapterRef(container, document),
    elementIndex: computeElementIndex(container, document),
    charOffset: offset,
    precedingContext: extractContext(container, offset, -50),
    followingContext: extractContext(container, offset, selection.toString().length + 50),
  };
}
```

## 3. Re-anchoring Strategy

Cascading fallback with user notification:

```typescript
async function reAnchor(
  annotation: Annotation,
  rendition: Rendition
): Promise<{ locator: Locator; confidence: 'exact' | 'fuzzy' | 'chapter' | 'none' }> {
  const { locator } = annotation;

  // Level 1: Exact match (CFI + text)
  const exact = await tryExactMatch(locator, rendition);
  if (exact) return { locator: exact, confidence: 'exact' };

  // Level 2: Fuzzy text match (surrounding context)
  const fuzzy = await tryFuzzyMatch(locator, rendition);
  if (fuzzy) return { locator: fuzzy, confidence: 'fuzzy' };

  // Level 3: Chapter fallback with user warning
  const chapter = await tryChapterFallback(locator, rendition);
  if (chapter) {
    notifyUser('Annotation relocated to chapter start. Manual adjustment may be needed.');
    return { locator: chapter, confidence: 'chapter' };
  }

  // Level 4: Cannot anchor - user notice
  notifyUser('Annotation could not be anchored. Document content may have changed significantly.');
  return { locator: locator, confidence: 'none' };
}

async function tryExactMatch(locator: Locator, rendition: Rendition): Promise<Locator | null> {
  const node = await rendition.findNodeByPosition(locator.position);
  if (!node) return null;

  const text = node.textContent || '';
  if (text.includes(locator.selectedText)) {
    return { ...locator };
  }
  return null;
}

async function tryFuzzyMatch(locator: Locator, rendition: Rendition): Promise<Locator | null> {
  const searchText = concatenateContext(locator.precedingContext, locator.selectedText, locator.followingContext);
  const node = await rendition.findTextFuzzy(searchText);
  if (!node) return null;

  return computeLocatorFromNode(node, locator.selectedText);
}

async function tryChapterFallback(locator: Locator, rendition: Rendition): Promise<Locator | null> {
  const chapter = await rendition.findChapter(locator.chapterRef);
  if (!chapter) return null;

  return {
    ...locator,
    position: chapter.startPosition,
    charOffset: 0,
  };
}
```

## 4. Event Cleanup

Prevent memory leaks by removing handlers on unmount:

```typescript
class AnnotationManager {
  private handlers: Array<{ target: EventTarget; type: string; handler: EventListener }> = [];

  addHandler(target: EventTarget, type: string, handler: EventListener): void {
    target.addEventListener(type, handler);
    this.handlers.push({ target, type, handler });
  }

  cleanup(): void {
    this.handlers.forEach(({ target, type, handler }) => {
      target.removeEventListener(type, handler);
    });
    this.handlers = [];
  }
}
```

## 5. Performance

- Lazy-load document assets: only fetch chapter content when navigated to
- Reuse single rendition instance across re-anchor operations
- Batch re-anchoring for multiple annotations in same chapter
- Remove event listeners on unmount

## 6. Testing

```typescript
describe('Locator serialization', () => {
  it('serializes and deserializes with stable casing', () => {
    const locator: Locator = {
      version: 1,
      position: 'epubcfi(/6/4!/4/2)',
      selectedText: 'Chapter One',
      chapterRef: 'ch001',
      elementIndex: 5,
      charOffset: 12,
      precedingContext: 'In the beginning, there was ',
      followingContext: ', and it was good.',
    };
    const serialized = JSON.stringify(locator);
    const deserialized = JSON.parse(serialized);
    expect(deserialized).toEqual(locator);
  });
});

describe('Re-anchor cascade', () => {
  it('falls back to fuzzy match when exact fails', async () => {
    const annotation = createAnnotation({ position: 'changed' });
    const rendition = mockRendition({ findNodeByPosition: null, findTextFuzzy: validNode });
    const result = await reAnchor(annotation, rendition);
    expect(result.confidence).toBe('fuzzy');
  });

  it('falls back to chapter when fuzzy fails', async () => {
    const annotation = createAnnotation();
    const rendition = mockRendition({
      findNodeByPosition: null,
      findTextFuzzy: null,
      findChapter: validChapter,
    });
    const result = await reAnchor(annotation, rendition);
    expect(result.confidence).toBe('chapter');
  });

  it('returns none when all methods fail', async () => {
    const annotation = createAnnotation();
    const rendition = mockRendition({
      findNodeByPosition: null,
      findTextFuzzy: null,
      findChapter: null,
    });
    const result = await reAnchor(annotation, rendition);
    expect(result.confidence).toBe('none');
  });
});
```

## Checklist

- [x] Position + text excerpt + chapterRef persisted together
- [x] Anchor serialization uses stable casing + schema
- [x] Re-anchoring warns user when falling back
- [x] Event handlers removed on unmount
- [ ] Telemetry events logged for load failures with trace IDs (deferred)
