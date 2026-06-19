# Multiplayer Game Room Durable Object

## Durable Object Class

```typescript
import { DurableObject } from "cloudflare:workers";

export interface Player {
  id: string;
  name: string;
  x: number;
  y: number;
  z: number;
  health: number;
  score: number;
  lastUpdate: number;
}

export interface Env {
  GAME_ROOM: DurableObjectNamespace<GameRoom>;
}

export class GameRoom extends DurableObject<Env> {
  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.ctx.storage.sql.exec(`
        CREATE TABLE IF NOT EXISTS players (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          x REAL NOT NULL DEFAULT 0,
          y REAL NOT NULL DEFAULT 0,
          z REAL NOT NULL DEFAULT 0,
          health INTEGER NOT NULL DEFAULT 100,
          score INTEGER NOT NULL DEFAULT 0,
          last_update INTEGER NOT NULL DEFAULT (unixepoch())
        )
      `);
    });
  }

  async addPlayer(id: string, name: string): Promise<Player> {
    this.ctx.storage.sql.exec(
      `INSERT OR REPLACE INTO players (id, name, x, y, z, health, score, last_update)
       VALUES (?, ?, 0, 0, 0, 100, 0, unixepoch())`,
      id,
      name,
    );
    return this.getPlayer(id);
  }

  async removePlayer(id: string): Promise<void> {
    this.ctx.storage.sql.exec("DELETE FROM players WHERE id = ?", id);
  }

  async updatePosition(id: string, x: number, y: number, z: number): Promise<Player> {
    this.ctx.storage.sql.exec(
      "UPDATE players SET x = ?, y = ?, z = ?, last_update = unixepoch() WHERE id = ?",
      x,
      y,
      z,
      id,
    );
    return this.getPlayer(id);
  }

  async updateHealth(id: string, health: number): Promise<Player> {
    this.ctx.storage.sql.exec(
      "UPDATE players SET health = ?, last_update = unixepoch() WHERE id = ?",
      health,
      id,
    );
    return this.getPlayer(id);
  }

  async addScore(id: string, points: number): Promise<Player> {
    this.ctx.storage.sql.exec(
      "UPDATE players SET score = score + ?, last_update = unixepoch() WHERE id = ?",
      points,
      id,
    );
    return this.getPlayer(id);
  }

  async getPlayer(id: string): Promise<Player | null> {
    const results = this.ctx.storage.sql
      .exec<{ id: string; name: string; x: number; y: number; z: number; health: number; score: number; last_update: number }>(
        "SELECT * FROM players WHERE id = ?",
        id,
      )
      .toArray();
    return results[0] ?? null;
  }

  async getAllPlayers(): Promise<Player[]> {
    return this.ctx.storage.sql
      .exec<Player>("SELECT * FROM players ORDER BY last_update DESC")
      .toArray();
  }

  async getTopPlayers(limit: number = 10): Promise<Player[]> {
    return this.ctx.storage.sql
      .exec<Player>("SELECT * FROM players ORDER BY score DESC LIMIT ?", limit)
      .toArray();
  }
}
```

## Wrangler Configuration

```jsonc
// wrangler.jsonc
{
  "durable_objects": {
    "bindings": [
      { "name": "GAME_ROOM", "class_name": "GameRoom" }
    ]
  },
  "migrations": [
    {
      "tag": "v1",
      "new_sqlite_classes": ["GameRoom"]
    }
  ]
}
```

## Worker Fetch Handler

```typescript
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const pathParts = url.pathname.split("/").filter(Boolean);

    if (pathParts[0] !== "room" || !pathParts[1]) {
      return Response.json({ error: "Usage: /room/:roomId" }, { status: 400 });
    }

    const roomId = pathParts[1];
    const stub = env.GAME_ROOM.getByName(roomId);

    if (request.method === "POST") {
      const body = await request.json<{ action: string; [key: string]: unknown }>();

      switch (body.action) {
        case "join":
          const newPlayer = await stub.addPlayer(body.playerId as string, body.playerName as string);
          return Response.json(newPlayer);

        case "leave":
          await stub.removePlayer(body.playerId as string);
          return Response.json({ ok: true });

        case "move":
          const moved = await stub.updatePosition(
            body.playerId as string,
            body.x as number,
            body.y as number,
            body.z as number,
          );
          return Response.json(moved);

        case "damage":
          const damaged = await stub.updateHealth(body.playerId as string, body.health as number);
          return Response.json(damaged);

        case "score":
          const scored = await stub.addScore(body.playerId as string, body.points as number);
          return Response.json(scored);

        default:
          return Response.json({ error: "Unknown action" }, { status: 400 });
      }
    }

    if (request.method === "GET") {
      const action = url.searchParams.get("action");

      if (action === "player") {
        const player = await stub.getPlayer(url.searchParams.get("playerId")!);
        return Response.json(player ?? { error: "Player not found" });
      }

      if (action === "top") {
        const limit = parseInt(url.searchParams.get("limit") ?? "10", 10);
        const top = await stub.getTopPlayers(limit);
        return Response.json(top);
      }

      const allPlayers = await stub.getAllPlayers();
      return Response.json(allPlayers);
    }

    return Response.json({ error: "Method not allowed" }, { status: 405 });
  },
};
```

## Key Design Decisions

- **One DO per room**: Each game room gets its own DO instance via `getByName(roomId)`, avoiding the single-global-DO bottleneck.
- **SQLite storage**: Player state persists across restarts/evictions. Schema initialized in constructor via `blockConcurrencyWhile()`.
- **RPC-ready**: The class methods can be called directly via RPC (compatibility date >= 2024-04-03) for type safety and no HTTP overhead.
- **Atomic storage**: Single SQL statements per mutation — no multi-write atomicity concerns.
- **Persist-first**: All mutations write to SQLite before returning.

**Status**: success
**Summary**: Created a GameRoom Durable Object with SQLite-backed player position/state tracking, RPC methods for join/leave/move/damage/score, wrangler config, and Worker fetch handler.

**Files touched**: `.agents/skills/durable-objects-workspace/iteration-1/eval-1/with_skill/outputs/response.md`
**Findings worth promoting**: (none)
