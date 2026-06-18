---
name: durable-objects
description: Create and review Cloudflare Durable Objects. Use when building stateful coordination (chat rooms, multiplayer games, booking systems), implementing RPC methods, SQLite storage, alarms, WebSockets, or reviewing DO code for best practices. Covers Workers integration, wrangler config, and testing with Vitest. Biases towards retrieval from Cloudflare docs over pre-trained knowledge.
version: "0.2.10"
category: platform
metadata:
  author: <ORG_NAME>
  spec: agentskills.io
license: MIT
---

# Durable Objects

Build stateful, coordinated applications on Cloudflare's edge using Durable Objects.

## Retrieval Sources

Your knowledge of Durable Objects APIs and configuration may be outdated. Prefer retrieval over pre-training for any Durable Objects task.

| Resource | URL |
|----------|-----|
| Docs | <https://developers.cloudflare.com/durable-objects/> |
| API Reference | <https://developers.cloudflare.com/durable-objects/api/> |
| Best Practices | <https://developers.cloudflare.com/durable-objects/best-practices/> |
| Examples | <https://developers.cloudflare.com/durable-objects/examples/> |

## When to Use

- Creating new Durable Object classes for stateful coordination
- Implementing RPC methods, alarms, or WebSocket handlers
- Reviewing existing DO code for best practices
- Configuring wrangler.jsonc/toml for DO bindings and migrations
- Writing tests with @cloudflare/vitest-pool-workers
- Designing sharding strategies and parent-child relationships

## Core Principles

### Use Durable Objects For

| Need | Example |
|------|---------|
| Coordination | Chat rooms, multiplayer games, collaborative docs |
| Strong consistency | Inventory, booking systems, turn-based games |
| Per-entity storage | Multi-tenant SaaS, per-user data |
| Persistent connections | WebSockets, real-time notifications |
| Scheduled work per entity | Subscription renewals, game timeouts |

### Do NOT Use For

- Stateless request handling (use plain Workers)
- Maximum global distribution needs
- High fan-out independent requests

## Quick Reference

### Wrangler Configuration

```jsonc
// wrangler.jsonc
{
  "durable_objects": {
    "bindings": [{ "name": "MY_DO", "class_name": "MyDurableObject" }],
  },
  "migrations": [{ "tag": "v1", "new_sqlite_classes": ["MyDurableObject"] }],
}
```

### Basic Durable Object Pattern

```typescript
import { DurableObject } from "cloudflare:workers";

export interface Env {
  MY_DO: DurableObjectNamespace<MyDurableObject>;
}

export class MyDurableObject extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.ctx.storage.sql.exec(`
        CREATE TABLE IF NOT EXISTS entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          data TEXT NOT NULL
        )
      `);
    });
  }

  async appendEntry(data: string): Promise<number> {
    const result = this.ctx.storage.sql.exec<{ id: number }>(
      "INSERT INTO entries (data) VALUES (?) RETURNING id",
      data,
    );
    return result.one().id;
  }
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const stub = env.MY_DO.getByName("instance-123");
    const id = await stub.appendEntry("hello world");
    return Response.json({ id });
  },
};
```

## Critical Rules

1. **Model around coordination atoms** - One DO per chat room/game/user, not one global DO.
2. **Use getByName() for deterministic routing** - Same input = same DO instance.
3. **Use SQLite storage** - Configure `new_sqlite_classes` in migrations.
4. **Initialize in constructor** - Use `blockConcurrencyWhile()` for schema setup only.
5. **Use RPC methods** - Not `fetch()` handler (compatibility date >= 2024-04-03).
6. **Persist first, cache second** - Always write to storage before updating in-memory state.
7. **One alarm per DO** - `setAlarm()` replaces any existing alarm.

## Anti-Patterns (NEVER)

- Single global DO handling all requests (bottleneck).
- Using `blockConcurrencyWhile()` on every request (kills throughput).
- Storing critical state only in memory (lost on eviction/crash).
- Using `await` between related storage writes (breaks atomicity).
- Holding `blockConcurrencyWhile()` across `fetch()` or external I/O.

## References

- `references/rules.md` - Core rules, storage, concurrency, RPC, alarms

## See Also

- `cloudflare-worker-api` — Cloudflare Worker API routes
- `turso-db` — Database development

## Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "I can handle state in a global variable." | Durable Objects provide persistence across restarts and evictions. |
| "Writing to storage on every request is slow." | SQLite storage is extremely fast and ensures data integrity. |
| "I'll just use fetch() for communication." | RPC methods provide better type safety and performance (no HTTP overhead). |

## Red Flags

- [ ] Using a single Durable Object for all application state.
- [ ] Performing external API calls inside `blockConcurrencyWhile()`.
- [ ] Lack of a migration strategy for SQLite schema updates.
- [ ] Using `newUniqueId()` without storing the ID elsewhere (lost reference).
