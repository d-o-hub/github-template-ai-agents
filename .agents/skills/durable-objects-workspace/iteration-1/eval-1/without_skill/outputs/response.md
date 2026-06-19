# Durable Object: Multiplayer Game Room

## Overview

A Durable Object implementation for tracking player positions and state in a multiplayer game room. Uses WebSockets for real-time communication and SQLite storage via the Durable Object API for persistence.

## Implementation

### `src/game-room.ts`

```typescript
import { DurableObject } from "cloudflare:workers";

interface Player {
  id: string;
  name: string;
  position: { x: number; y: number };
  velocity: { x: number; y: number };
  health: number;
  score: number;
  lastUpdate: number;
}

interface GameState {
  roomId: string;
  players: Map<string, Player>;
  createdAt: number;
  lastActivity: number;
}

interface WSMessage {
  type: "join" | "leave" | "move" | "state" | "chat" | "ping" | "pong";
  payload: Record<string, unknown>;
  sender?: string;
  timestamp?: number;
}

export class GameRoom extends DurableObject {
  private state: DurableObjectState;
  private players: Map<string, Player> = new Map();
  private connections: Map<string, WebSocket> = new Map();
  private roomId: string;
  private broadcast: ((msg: string, exclude?: string) => void) | null = null;

  constructor(state: DurableObjectState, env: unknown) {
    super(state, env);
    this.state = state;
    this.roomId = state.id.toString();
    this.state.blockConcurrencyWhile(async () => {
      await this.loadState();
    });
  }

  private async loadState(): Promise<void> {
    const stored = await this.state.storage.get<Map<string, Player>>("players");
    if (stored) {
      this.players = stored;
    }
  }

  private async saveState(): Promise<void> {
    await this.state.storage.put("players", this.players);
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (request.headers.get("Upgrade") === "websocket") {
      return this.handleWebSocketUpgrade(request);
    }

    if (url.pathname === "/state") {
      return this.getState();
    }

    if (url.pathname === "/player" && request.method === "GET") {
      const playerId = url.searchParams.get("id");
      if (playerId) {
        return this.getPlayer(playerId);
      }
    }

    return new Response("Not Found", { status: 404 });
  }

  private handleWebSocketUpgrade(request: Request): Response {
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);

    this.state.acceptWebSocket(server);

    const playerId = new URL(request.url).searchParams.get("playerId") || crypto.randomUUID();

    this.ctx.waitUntil(
      (async () => {
        await this.waitForWebSocketOpen(server, playerId);
      })()
    );

    return new Response(null, { status: 101, webSocket: client });
  }

  private async waitForWebSocketOpen(ws: WebSocket, playerId: string): Promise<void> {
    while (ws.readyState === WebSocket.CONNECTING) {
      await new Promise((resolve) => setTimeout(resolve, 10));
    }

    if (ws.readyState === WebSocket.OPEN) {
      this.connections.set(playerId, ws);
      this.broadcastPlayerJoined(playerId);
    }
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const data = typeof message === "string" ? JSON.parse(message) : JSON.parse(new TextDecoder().decode(message));
    const msg = data as WSMessage;
    const senderId = this.findPlayerByWs(ws);

    switch (msg.type) {
      case "join":
        await this.handleJoin(senderId, msg);
        break;
      case "leave":
        await this.handleLeave(senderId);
        break;
      case "move":
        await this.handleMove(senderId, msg);
        break;
      case "chat":
        this.handleChat(senderId, msg);
        break;
      case "ping":
        this.handlePing(ws);
        break;
    }
  }

  async webSocketClose(
    ws: WebSocket,
    code: number,
    reason: string,
    wasClean: boolean
  ): Promise<void> {
    const playerId = this.findPlayerByWs(ws);
    if (playerId) {
      await this.handleLeave(playerId);
    }
  }

  async webSocketError(ws: WebSocket, error: unknown): Promise<void> {
    const playerId = this.findPlayerByWs(ws);
    if (playerId) {
      await this.handleLeave(playerId);
    }
  }

  private findPlayerByWs(ws: WebSocket): string | null {
    for (const [id, conn] of this.connections) {
      if (conn === ws) return id;
    }
    return null;
  }

  private async handleJoin(playerId: string, msg: WSMessage): Promise<void> {
    const player: Player = {
      id: playerId,
      name: (msg.payload.name as string) || `Player ${playerId.slice(0, 6)}`,
      position: { x: 0, y: 0 },
      velocity: { x: 0, y: 0 },
      health: 100,
      score: 0,
      lastUpdate: Date.now(),
    };

    this.players.set(playerId, player);
    await this.saveState();

    const conn = this.connections.get(playerId);
    if (conn) {
      conn.send(JSON.stringify({
        type: "join_ack",
        payload: {
          playerId,
          player,
          players: Object.fromEntries(this.players),
        },
      }));
    }

    this.broadcastToAll({
      type: "player_joined",
      payload: { player },
      sender: playerId,
    });
  }

  private async handleLeave(playerId: string): Promise<void> {
    this.players.delete(playerId);
    this.connections.delete(playerId);
    await this.saveState();

    this.broadcastToAll({
      type: "player_left",
      payload: { playerId },
      sender: playerId,
    });
  }

  private async handleMove(playerId: string, msg: WSMessage): Promise<void> {
    const player = this.players.get(playerId);
    if (!player) return;

    const { position, velocity } = msg.payload;
    if (position) {
      player.position = position as { x: number; y: number };
    }
    if (velocity) {
      player.velocity = velocity as { x: number; y: number };
    }
    player.lastUpdate = Date.now();

    await this.saveState();

    this.broadcastToAll({
      type: "player_moved",
      payload: {
        playerId,
        position: player.position,
        velocity: player.velocity,
      },
      sender: playerId,
    });
  }

  private handleChat(senderId: string, msg: WSMessage): void {
    this.broadcastToAll({
      type: "chat",
      payload: {
        message: msg.payload.message,
        playerName: this.players.get(senderId)?.name,
      },
      sender: senderId,
    });
  }

  private handlePing(ws: WebSocket): void {
    ws.send(JSON.stringify({ type: "pong" }));
  }

  private broadcastToAll(msg: WSMessage): void {
    const data = JSON.stringify(msg);
    for (const [id, conn] of this.connections) {
      if (id !== msg.sender && conn.readyState === WebSocket.OPEN) {
        conn.send(data);
      }
    }
  }

  private broadcastPlayerJoined(playerId: string): void {
    this.broadcastToAll({
      type: "player_joined",
      payload: { playerId },
      sender: playerId,
    });
  }

  private getState(): Response {
    const state = {
      roomId: this.roomId,
      players: Object.fromEntries(this.players),
      playerCount: this.players.size,
      createdAt: this.state.createdAt?.getTime?.() ?? Date.now(),
    };
    return Response.json(state);
  }

  private getPlayer(playerId: string): Response {
    const player = this.players.get(playerId);
    if (!player) {
      return Response.json({ error: "Player not found" }, { status: 404 });
    }
    return Response.json(player);
  }

  async alarm(): Promise<void> {
    const now = Date.now();
    for (const [id, player] of this.players) {
      if (now - player.lastUpdate > 300_000) {
        this.players.delete(id);
        this.connections.delete(id);
      }
    }
    await this.saveState();

    if (this.players.size > 0) {
      this.ctx.setAlarm(Date.now() + 60_000);
    }
  }
}
```

### `src/index.ts`

```typescript
import { GameRoom } from "./game-room";

export interface Env {
  GAME_ROOM: DurableObjectNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/room") {
      const roomId = url.searchParams.get("id") || crypto.randomUUID();
      const id = env.GAME_ROOM.idFromName(roomId);
      const stub = env.GAME_ROOM.get(id);
      return stub.fetch(request);
    }

    return new Response("Multiplayer Game Server", { status: 200 });
  },
};
```

### `wrangler.toml`

```toml
name = "multiplayer-game"
main = "src/index.ts"
compatibility_date = "2024-01-01"

[durable_objects]
bindings = [
  { name = "GAME_ROOM", class_name = "GameRoom" }
]

[[migrations]]
tag = "v1"
new_classes = ["GameRoom"]
```

## Usage Examples

### Connect to a Game Room

```javascript
const ws = new WebSocket(
  `wss://your-worker.workers.dev/room?id=room-123&playerId=player-abc`
);

ws.onopen = () => {
  ws.send(JSON.stringify({
    type: "join",
    payload: { name: "Alice" },
  }));
};

ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  switch (msg.type) {
    case "join_ack":
      console.log("Joined room:", msg.payload.players);
      break;
    case "player_moved":
      console.log(`${msg.payload.playerId} moved to`, msg.payload.position);
      break;
    case "player_left":
      console.log(`${msg.payload.playerId} left`);
      break;
  }
};
```

### Send Position Updates

```javascript
ws.send(JSON.stringify({
  type: "move",
  payload: {
    position: { x: 100, y: 200 },
    velocity: { x: 5, y: 0 },
  },
}));
```

### Get Room State via HTTP

```javascript
const response = await fetch(
  "https://your-worker.workers.dev/room?id=room-123/state"
);
const state = await response.json();
// { roomId: "room-123", players: {...}, playerCount: 2 }
```

## Key Features

1. **Real-time synchronization**: WebSocket-based communication for instant position updates
2. **Persistence**: Player state stored in Durable Object storage, survives restarts
3. **Automatic cleanup**: Alarm-based cleanup of inactive players (5-minute timeout)
4. **Scalability**: Each room is isolated in its own Durable Object instance
5. **State queries**: HTTP endpoints for fetching room/player state without WebSocket

## Message Types

| Type | Direction | Description |
|------|-----------|-------------|
| `join` | Client → Server | Player joins the room |
| `join_ack` | Server → Client | Confirmation with current state |
| `leave` | Client → Server | Player leaves the room |
| `move` | Client → Server | Position/velocity update |
| `player_joined` | Server → All | Broadcast when player joins |
| `player_left` | Server → All | Broadcast when player leaves |
| `player_moved` | Server → All | Broadcast position updates |
| `chat` | Both | Chat messages |
| `ping/pong` | Both | Keep-alive |
