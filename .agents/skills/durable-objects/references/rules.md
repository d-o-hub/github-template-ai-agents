# Durable Objects Rules & Best Practices

## Design & Sharding

### Model Around Coordination Atoms

Create one DO per logical unit needing coordination: chat room, game session, document, user, tenant.

```typescript
// ✅ Good: One DO per chat room
const stub = env.CHAT_ROOM.getByName(roomId);

// ❌ Bad: Single global DO
const stub = env.CHAT_ROOM.getByName("global"); // Bottleneck!
```

## Storage

### SQLite (Recommended)

Configure in wrangler:

```json
{ "migrations": [{ "tag": "v1", "new_sqlite_classes": ["MyDO"] }] }
```

SQL API is synchronous:

```typescript
// Write
this.ctx.storage.sql.exec(
  "INSERT INTO items (name, value) VALUES (?, ?)",
  name,
  value,
);

// Read
const rows = this.ctx.storage.sql
  .exec<{
    id: number;
    name: string;
  }>("SELECT * FROM items WHERE name = ?", name)
  .toArray();
```

## Concurrency

### Input/Output Gates

Storage operations automatically block other requests (input gates). Responses wait for writes (output gates).

### blockConcurrencyWhile()

Blocks ALL concurrency. Use sparingly - only for initialization. Never hold across external I/O (fetch, R2, KV).

## RPC Methods

Use RPC (compatibility date >= 2024-04-03) instead of fetch() handler.

## Alarms

One alarm per DO. `setAlarm()` replaces existing. Alarms auto-retry on failure. Use idempotent handlers.

## WebSockets (Hibernation API)

Durable Objects can accept WebSocket connections and hibernate while waiting for messages, reducing costs.
