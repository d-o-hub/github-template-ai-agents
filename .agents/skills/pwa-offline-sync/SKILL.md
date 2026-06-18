---
version: "0.2.10"
name: pwa-offline-sync
description: >
  Design Cache Storage + IndexedDB strategy and sync queue. Use this skill when building service workers, implementing caching strategies, or investigating offline bugs — even if they just say "make it work offline" or "add caching". Generic pattern for any offline-first application.
category: workflow
license: MIT
---

# PWA Offline Sync

Purpose: design, implement, and validate offline/PWA behavior (service worker, caches, IndexedDB, sync queue).

## When to Use

- Editing service worker, cache strategies, or sync orchestration.
- Touching IndexedDB schema, permission caching, or zombie detection.
- Investigating offline bugs or data conflicts.

## Workflow

1. **Assess entity rules** -- confirm table of offline-first entities + conflict strategy.
2. **Plan caches** -- map static/assets/data to Cache Storage policies (cache-first vs stale-while-revalidate vs network-first).
3. **IndexedDB schema** -- define stores for progress, annotations, sync queue, permission cache; version migrations carefully.
4. **Service worker** -- implement install/activate/fetch with trace logging, offline fallback page, and error handling.
5. **Sync manager** -- queue writes locally, dedupe via mutation IDs, replay when online, implement exponential backoff + zombie detection.
6. **Testing** -- simulate offline/online in E2E tests; unit-test queue reducers; verify revoked access is blocked after reconnect.

## Checklist

- [ ] Cache + DB version numbers bumped intentionally (no silent clears).
- [ ] Headers sent even when offline data queued.
- [ ] Zombie detection notifies user + stops further reads upon revocation.
- [ ] Service worker cleans up old caches.
- [ ] Memory-safe listeners (remove event handlers when replaced).

## See Also

- `lifecycle-management` — Resource cleanup and error handling
- `css-render-performance` — CSS render performance optimization

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "Cache-first is always the best strategy" | Different data requires different strategies; stale-while-revalidate or network-first may be more appropriate. |
| "Sync queue is overkill for our simple app" | Even simple apps need conflict resolution when offline writes collide with server state. |
| "Zombie detection is too complex to implement" | Without it, revoked users can continue reading cached data indefinitely. |

## Red Flags

- [ ] Using a single cache strategy for all data types
- [ ] Not implementing zombie detection for revoked access
- [ ] Forgetting to bump cache/DB version numbers on schema changes

## References

- `references/offline-strategies.md` - Offline-first architecture patterns
- `references/sync-queue.md` - Sync queue design and conflict resolution
