import { DurableObject } from "cloudflare:workers";

export interface Env {
  SIGNALING_HUB: DurableObjectNamespace<SignalingHub>;
  ASSET_BUCKET: R2Bucket;
  ALLOWED_ORIGINS?: string;
  ALLOW_LAN_ORIGINS?: string;
  MAX_PLAYERS_PER_ROOM?: string;
  ROOM_CODE_LENGTH?: string;
  PLAYER_NAME_MAX_LENGTH?: string;
  ROOM_IDLE_TTL_MS?: string;
  RATE_LIMIT_WINDOW_MS?: string;
  RATE_LIMIT_MAX_MESSAGES?: string;
  SIGNALING_MAX_MESSAGE_BYTES?: string;
  SIGNALING_SHARD_NAME?: string;
  ASSET_BASE_PATH?: string;
}

type ErrorCode =
  | "invalid_message"
  | "rate_limited"
  | "room_not_found"
  | "room_full"
  | "duplicate_name"
  | "not_in_room"
  | "target_not_found"
  | "forbidden"
  | "room_expired";

type ClientMessage =
  | { type: "create_room"; playerName: string }
  | { type: "join_room"; roomCode: string; playerName: string }
  | { type: "leave_room" }
  | { type: "set_ready"; ready: boolean }
  | { type: "set_room_scene"; sceneId: "phase4_beachhead" | "phase4_scene_1_2" }
  | { type: "webrtc_offer"; targetPeerId: string; sdp: string }
  | { type: "webrtc_answer"; targetPeerId: string; sdp: string }
  | {
      type: "webrtc_ice";
      targetPeerId: string;
      candidate: string;
      sdpMid?: string | null;
      sdpMLineIndex?: number | null;
    }
  | { type: "ping" };

interface LobbyPlayer {
  peerId: string;
  name: string;
  ready: boolean;
  isHost: boolean;
}

type ServerMessage =
  | { type: "welcome"; peerId: string }
  | { type: "room_created"; roomCode: string; peerId: string; isHost: true; sceneId: string }
  | {
      type: "room_joined";
      roomCode: string;
      peerId: string;
      isHost: boolean;
      sceneId: string;
      players: LobbyPlayer[];
    }
  | { type: "player_joined"; player: LobbyPlayer }
  | { type: "player_left"; peerId: string; reason: string }
  | { type: "player_ready"; peerId: string; ready: boolean }
  | { type: "room_scene_changed"; sceneId: string }
  | { type: "host_changed"; peerId: string }
  | { type: "webrtc_offer"; fromPeerId: string; sdp: string }
  | { type: "webrtc_answer"; fromPeerId: string; sdp: string }
  | {
      type: "webrtc_ice";
      fromPeerId: string;
      candidate: string;
      sdpMid?: string | null;
      sdpMLineIndex?: number | null;
    }
  | { type: "error"; code: ErrorCode; message: string }
  | { type: "pong" };

interface SessionAttachment {
  peerId: string;
  roomCode: string | null;
  playerName: string;
}

interface RoomPlayerState {
  peerId: string;
  name: string;
  ready: boolean;
}

interface RoomState {
  code: string;
  hostPeerId: string;
  sceneId: string;
  players: Record<string, RoomPlayerState>;
  updatedAt: number;
}

interface RateWindow {
  startedAt: number;
  count: number;
}

interface RuntimeConfig {
  allowedOrigins: string[];
  allowLanOrigins: boolean;
  maxPlayersPerRoom: number;
  roomCodeLength: number;
  playerNameMaxLength: number;
  roomIdleTtlMs: number;
  rateLimitWindowMs: number;
  rateLimitMaxMessages: number;
  maxMessageBytes: number;
  shardName: string;
  assetBasePath: string;
}

const ROOM_STORAGE_KEY = "rooms_v1";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const isWebSocket = request.headers.get("Upgrade")?.toLowerCase() === "websocket";
    const config = loadRuntimeConfig(env);
    const stub = env.SIGNALING_HUB.getByName(config.shardName);

    if (url.pathname === "/health") {
      return stub.fetch(new Request("https://signaling.internal/health"));
    }

    if (url.pathname.startsWith("/assets/")) {
      return serveAsset(request, env, config);
    }

    if (url.pathname !== "/" && url.pathname !== "/ws") {
      return Response.json(
        {
          ok: true,
          endpoints: ["/health", "/ws", "/assets/<key>"],
        },
        { status: 200 },
      );
    }

    if (!isWebSocket) {
      return new Response("Expected Upgrade: websocket", { status: 426 });
    }

    const origin = request.headers.get("Origin");
    if (origin !== null && !isOriginAllowed(origin, config.allowedOrigins, config.allowLanOrigins)) {
      return new Response("origin_not_allowed", { status: 403 });
    }

    return stub.fetch(request);
  },
};

export class SignalingHub extends DurableObject<Env> {
  private readonly config: RuntimeConfig;
  private readonly rooms = new Map<string, RoomState>();
  private readonly sessions = new Map<WebSocket, SessionAttachment>();
  private readonly rateWindows = new Map<string, RateWindow>();

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.config = loadRuntimeConfig(env);
    this.ctx.blockConcurrencyWhile(async () => {
      const storedRooms = await this.ctx.storage.get<Record<string, RoomState>>(ROOM_STORAGE_KEY);
      if (storedRooms) {
        for (const room of Object.values(storedRooms)) {
          if (typeof room.sceneId !== "string") {
            room.sceneId = "phase4_beachhead";
          }
          this.rooms.set(room.code, room);
        }
      }

      for (const ws of this.ctx.getWebSockets()) {
        const attachment = ws.deserializeAttachment() as SessionAttachment | null;
        if (attachment) {
          this.sessions.set(ws, attachment);
        }
      }

      this.ctx.setWebSocketAutoResponse(new WebSocketRequestResponsePair("ping", "pong"));
      await this.scheduleAlarm();
    });
  }

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") {
      return Response.json(
        {
          ok: true,
          rooms: this.rooms.size,
          peers: this.sessions.size,
        },
        { status: 200 },
      );
    }

    const upgrade = request.headers.get("Upgrade");
    if (request.method !== "GET" || !upgrade || upgrade.toLowerCase() !== "websocket") {
      return new Response("Expected Upgrade: websocket", { status: 426 });
    }

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair) as [WebSocket, WebSocket];
    const attachment: SessionAttachment = {
      peerId: crypto.randomUUID(),
      roomCode: null,
      playerName: "",
    };
    server.serializeAttachment(attachment);
    this.ctx.acceptWebSocket(server);
    this.sessions.set(server, attachment);
    this.send(server, { type: "welcome", peerId: attachment.peerId });
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    const session = this.getSession(ws);
    if (!session) {
      this.sendError(ws, "forbidden", "Session is not initialized.");
      return;
    }

    const text = typeof message === "string" ? message : new TextDecoder().decode(message);
    if (text.length > this.config.maxMessageBytes) {
      this.sendError(ws, "invalid_message", "Message too large.");
      return;
    }
    if (!this.allowRate(session.peerId)) {
      this.sendError(ws, "rate_limited", "Too many messages. Slow down.");
      return;
    }

    const parsed = parseClientMessage(text);
    if (!parsed.ok) {
      this.sendError(ws, parsed.code, parsed.message);
      return;
    }

    const msg = parsed.message;
    switch (msg.type) {
      case "ping":
        this.send(ws, { type: "pong" });
        return;
      case "create_room":
        await this.onCreateRoom(ws, session, msg.playerName);
        return;
      case "join_room":
        await this.onJoinRoom(ws, session, msg.roomCode, msg.playerName);
        return;
      case "leave_room":
        await this.onLeaveRoom(ws, session);
        return;
      case "set_ready":
        await this.onSetReady(ws, session, msg.ready);
        return;
      case "set_room_scene":
        await this.onSetRoomScene(ws, session, msg.sceneId);
        return;
      case "webrtc_offer":
      case "webrtc_answer":
      case "webrtc_ice":
        await this.relaySignal(ws, session, msg);
        return;
    }
  }

  async webSocketClose(ws: WebSocket, _code: number, reason: string, _wasClean: boolean): Promise<void> {
    await this.disconnectPeer(ws, reason || "socket_closed");
  }

  async webSocketError(ws: WebSocket, _error: unknown): Promise<void> {
    await this.disconnectPeer(ws, "socket_error");
  }

  async alarm(): Promise<void> {
    const now = Date.now();
    let changed = false;

    for (const [code, room] of [...this.rooms.entries()]) {
      if (now - room.updatedAt <= this.config.roomIdleTtlMs) {
        continue;
      }
      for (const [socket, session] of this.sessions) {
        if (session.roomCode !== code) {
          continue;
        }
        this.sendError(socket, "room_expired", "Room expired due to inactivity.");
        session.roomCode = null;
        session.playerName = "";
        socket.serializeAttachment(session);
        socket.close(1012, "room_expired");
      }
      this.rooms.delete(code);
      changed = true;
    }

    if (changed) {
      await this.persistRooms();
    } else {
      await this.scheduleAlarm();
    }
  }

  private async onCreateRoom(ws: WebSocket, session: SessionAttachment, playerName: string): Promise<void> {
    if (session.roomCode !== null && this.rooms.has(session.roomCode)) {
      this.sendError(ws, "forbidden", "Already in a room.");
      return;
    }

    const name = this.clampName(playerName);
    const code = this.generateUniqueCode();
    const room: RoomState = {
      code,
      hostPeerId: session.peerId,
      sceneId: "phase4_beachhead",
      players: {
        [session.peerId]: {
          peerId: session.peerId,
          name,
          ready: false,
        },
      },
      updatedAt: Date.now(),
    };

    session.roomCode = code;
    session.playerName = name;
    ws.serializeAttachment(session);
    this.rooms.set(code, room);
    await this.persistRooms();
    this.send(ws, {
      type: "room_created",
      roomCode: code,
      peerId: session.peerId,
      isHost: true,
      sceneId: room.sceneId,
    });
  }

  private async onJoinRoom(
    ws: WebSocket,
    session: SessionAttachment,
    roomCode: string,
    playerName: string,
  ): Promise<void> {
    if (session.roomCode !== null && this.rooms.has(session.roomCode)) {
      this.sendError(ws, "forbidden", "Already in a room.");
      return;
    }

    const room = this.rooms.get(roomCode.toUpperCase());
    if (!room) {
      this.sendError(ws, "room_not_found", "Room not found.");
      return;
    }
    if (Object.keys(room.players).length >= this.config.maxPlayersPerRoom) {
      this.sendError(ws, "room_full", "Room is full.");
      return;
    }

    const name = this.clampName(playerName);
    const normalized = name.trim().toLowerCase();
    for (const player of Object.values(room.players)) {
      if (player.name.trim().toLowerCase() === normalized) {
        this.sendError(ws, "duplicate_name", "That player name is already in use in this room.");
        return;
      }
    }

    session.roomCode = room.code;
    session.playerName = name;
    ws.serializeAttachment(session);
    room.players[session.peerId] = {
      peerId: session.peerId,
      name,
      ready: false,
    };
    room.updatedAt = Date.now();
    await this.persistRooms();

    const players = this.toLobbyPlayers(room);
    this.send(ws, {
      type: "room_joined",
      roomCode: room.code,
      peerId: session.peerId,
      isHost: room.hostPeerId === session.peerId,
      sceneId: room.sceneId,
      players,
    });
    this.broadcast(
      room.code,
      {
        type: "player_joined",
        player: {
          peerId: session.peerId,
          name,
          ready: false,
          isHost: false,
        },
      },
      session.peerId,
    );
  }

  private async onLeaveRoom(ws: WebSocket, session: SessionAttachment): Promise<void> {
    if (session.roomCode === null) {
      this.sendError(ws, "not_in_room", "Not in a room.");
      return;
    }

    const roomCode = session.roomCode;
    session.roomCode = null;
    session.playerName = "";
    ws.serializeAttachment(session);
    await this.removePeerFromRoom(session.peerId, roomCode, "left");
    ws.close(1000, "left");
  }

  private async onSetReady(ws: WebSocket, session: SessionAttachment, ready: boolean): Promise<void> {
    if (session.roomCode === null) {
      this.sendError(ws, "not_in_room", "Not in a room.");
      return;
    }
    const room = this.rooms.get(session.roomCode);
    const player = room?.players[session.peerId];
    if (!room || !player) {
      this.sendError(ws, "not_in_room", "Not in a room.");
      return;
    }

    player.ready = ready;
    room.updatedAt = Date.now();
    await this.persistRooms();
    this.broadcast(room.code, {
      type: "player_ready",
      peerId: session.peerId,
      ready,
    });
  }

  private async onSetRoomScene(
    ws: WebSocket,
    session: SessionAttachment,
    sceneId: "phase4_beachhead" | "phase4_scene_1_2",
  ): Promise<void> {
    if (session.roomCode === null) {
      this.sendError(ws, "not_in_room", "Not in a room.");
      return;
    }
    const room = this.rooms.get(session.roomCode);
    if (!room || !room.players[session.peerId]) {
      this.sendError(ws, "not_in_room", "Not in a room.");
      return;
    }
    if (room.hostPeerId !== session.peerId) {
      this.sendError(ws, "forbidden", "Only the host can change the room mission.");
      return;
    }
    room.sceneId = sceneId === "phase4_scene_1_2" ? "phase4_scene_1_2" : "phase4_beachhead";
    room.updatedAt = Date.now();
    await this.persistRooms();
    this.broadcast(room.code, {
      type: "room_scene_changed",
      sceneId: room.sceneId,
    });
  }

  private async relaySignal(
    ws: WebSocket,
    session: SessionAttachment,
    message:
      | { type: "webrtc_offer"; targetPeerId: string; sdp: string }
      | { type: "webrtc_answer"; targetPeerId: string; sdp: string }
      | {
          type: "webrtc_ice";
          targetPeerId: string;
          candidate: string;
          sdpMid?: string | null;
          sdpMLineIndex?: number | null;
        },
  ): Promise<void> {
    if (session.roomCode === null) {
      this.sendError(ws, "not_in_room", "Not in a room.");
      return;
    }
    const room = this.rooms.get(session.roomCode);
    if (!room) {
      this.sendError(ws, "not_in_room", "Not in a room.");
      return;
    }
    if (!room.players[message.targetPeerId]) {
      this.sendError(ws, "target_not_found", "Target peer is not in this room.");
      return;
    }

    const targetSocket = this.findSocketByPeerId(message.targetPeerId);
    if (!targetSocket) {
      this.sendError(ws, "target_not_found", "Target peer is offline.");
      return;
    }

    room.updatedAt = Date.now();
    await this.persistRooms();

    if (message.type === "webrtc_offer") {
      this.send(targetSocket, {
        type: "webrtc_offer",
        fromPeerId: session.peerId,
        sdp: message.sdp,
      });
      return;
    }
    if (message.type === "webrtc_answer") {
      this.send(targetSocket, {
        type: "webrtc_answer",
        fromPeerId: session.peerId,
        sdp: message.sdp,
      });
      return;
    }
    this.send(targetSocket, {
      type: "webrtc_ice",
      fromPeerId: session.peerId,
      candidate: message.candidate,
      sdpMid: message.sdpMid ?? null,
      sdpMLineIndex: message.sdpMLineIndex ?? null,
    });
  }

  private async disconnectPeer(ws: WebSocket, reason: string): Promise<void> {
    const session = this.getSession(ws);
    if (!session) {
      return;
    }
    this.sessions.delete(ws);
    this.rateWindows.delete(session.peerId);
    if (session.roomCode !== null) {
      await this.removePeerFromRoom(session.peerId, session.roomCode, reason);
    }
  }

  private async removePeerFromRoom(peerId: string, roomCode: string, reason: string): Promise<void> {
    const room = this.rooms.get(roomCode);
    if (!room || !room.players[peerId]) {
      return;
    }

    delete room.players[peerId];
    room.updatedAt = Date.now();
    let hostChanged = false;

    if (room.hostPeerId === peerId) {
      const nextHost = Object.values(room.players)[0];
      if (nextHost) {
        room.hostPeerId = nextHost.peerId;
        hostChanged = true;
      }
    }

    if (Object.keys(room.players).length === 0) {
      this.rooms.delete(room.code);
    }

    await this.persistRooms();

    if (this.rooms.has(room.code)) {
      this.broadcast(room.code, {
        type: "player_left",
        peerId,
        reason,
      });
      if (hostChanged) {
        this.broadcast(room.code, {
          type: "host_changed",
          peerId: room.hostPeerId,
        });
      }
    }
  }

  private getSession(ws: WebSocket): SessionAttachment | undefined {
    const existing = this.sessions.get(ws);
    if (existing) {
      return existing;
    }
    const attachment = ws.deserializeAttachment() as SessionAttachment | null;
    if (attachment) {
      this.sessions.set(ws, attachment);
      return attachment;
    }
    return undefined;
  }

  private findSocketByPeerId(peerId: string): WebSocket | null {
    for (const [socket, session] of this.sessions) {
      if (session.peerId === peerId) {
        return socket;
      }
    }
    return null;
  }

  private broadcast(roomCode: string, message: ServerMessage, exceptPeerId?: string): void {
    for (const [socket, session] of this.sessions) {
      if (session.roomCode !== roomCode || session.peerId === exceptPeerId) {
        continue;
      }
      this.send(socket, message);
    }
  }

  private send(socket: WebSocket, message: ServerMessage): void {
    try {
      socket.send(JSON.stringify(message));
    } catch {
      // Ignore send failures; close events will reconcile state.
    }
  }

  private sendError(socket: WebSocket, code: ErrorCode, message: string): void {
    this.send(socket, {
      type: "error",
      code,
      message,
    });
  }

  private clampName(name: string): string {
    const cleaned = name.trim();
    if (cleaned === "") {
      return "Operative";
    }
    return cleaned.slice(0, this.config.playerNameMaxLength);
  }

  private toLobbyPlayers(room: RoomState): LobbyPlayer[] {
    return Object.values(room.players).map((player) => ({
      peerId: player.peerId,
      name: player.name,
      ready: player.ready,
      isHost: player.peerId === room.hostPeerId,
    }));
  }

  private generateUniqueCode(): string {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    for (let attempt = 0; attempt < 50; attempt += 1) {
      let code = "";
      for (let i = 0; i < this.config.roomCodeLength; i += 1) {
        code += alphabet[Math.floor(Math.random() * alphabet.length)];
      }
      if (!this.rooms.has(code)) {
        return code;
      }
    }
    throw new Error("Unable to allocate unique room code");
  }

  private allowRate(peerId: string): boolean {
    const now = Date.now();
    const current = this.rateWindows.get(peerId);
    if (!current || now - current.startedAt > this.config.rateLimitWindowMs) {
      this.rateWindows.set(peerId, {
        startedAt: now,
        count: 1,
      });
      return true;
    }
    current.count += 1;
    return current.count <= this.config.rateLimitMaxMessages;
  }

  private async persistRooms(): Promise<void> {
    const stored: Record<string, RoomState> = {};
    for (const [code, room] of this.rooms) {
      stored[code] = room;
    }
    await this.ctx.storage.put(ROOM_STORAGE_KEY, stored);
    await this.scheduleAlarm();
  }

  private async scheduleAlarm(): Promise<void> {
    if (this.rooms.size === 0) {
      await this.ctx.storage.deleteAlarm();
      return;
    }
    let nextAt = Number.POSITIVE_INFINITY;
    for (const room of this.rooms.values()) {
      nextAt = Math.min(nextAt, room.updatedAt + this.config.roomIdleTtlMs);
    }
    if (Number.isFinite(nextAt)) {
      await this.ctx.storage.setAlarm(nextAt);
    }
  }
}

function loadRuntimeConfig(env: Env): RuntimeConfig {
  return {
    allowedOrigins: parseCommaList(env.ALLOWED_ORIGINS ?? ""),
    allowLanOrigins: envFlag(env.ALLOW_LAN_ORIGINS, false),
    maxPlayersPerRoom: envInt(env.MAX_PLAYERS_PER_ROOM, 2),
    roomCodeLength: envInt(env.ROOM_CODE_LENGTH, 6),
    playerNameMaxLength: envInt(env.PLAYER_NAME_MAX_LENGTH, 16),
    roomIdleTtlMs: envInt(env.ROOM_IDLE_TTL_MS, 1_800_000),
    rateLimitWindowMs: envInt(env.RATE_LIMIT_WINDOW_MS, 10_000),
    rateLimitMaxMessages: envInt(env.RATE_LIMIT_MAX_MESSAGES, 60),
    maxMessageBytes: envInt(env.SIGNALING_MAX_MESSAGE_BYTES, 72_000),
    shardName: (env.SIGNALING_SHARD_NAME ?? "global").trim() || "global",
    assetBasePath: normalizeAssetBasePath(env.ASSET_BASE_PATH ?? "operation-steelstorm"),
  };
}

async function serveAsset(request: Request, env: Env, config: RuntimeConfig): Promise<Response> {
  const url = new URL(request.url);
  const suffix = url.pathname.replace(/^\/assets\/+/, "");
  if (suffix === "") {
    return new Response("not_found", { status: 404 });
  }

  const key = joinAssetKey(config.assetBasePath, suffix);
  const object = await env.ASSET_BUCKET.get(key);
  if (object === null) {
    return new Response("not_found", { status: 404 });
  }

  const headers = new Headers();
  object.writeHttpMetadata(headers);
  headers.set("etag", object.httpEtag);
  headers.set("cache-control", "public, max-age=31536000, immutable");
  headers.set("access-control-allow-origin", "*");
  headers.set("cross-origin-resource-policy", "cross-origin");
  if (key.endsWith(".wasm")) {
    headers.set("content-type", "application/wasm");
  }
  return new Response(object.body, { headers });
}

function envInt(raw: string | undefined, fallback: number): number {
  if (!raw) {
    return fallback;
  }
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function envFlag(raw: string | undefined, fallback: boolean): boolean {
  if (!raw) {
    return fallback;
  }
  const normalized = raw.trim().toLowerCase();
  return normalized === "1" || normalized === "true" || normalized === "yes" || normalized === "on";
}

function parseCommaList(raw: string): string[] {
  return raw
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value !== "");
}

function normalizeAssetBasePath(raw: string): string {
  return raw.trim().replace(/^\/+|\/+$/g, "");
}

function joinAssetKey(basePath: string, suffix: string): string {
  const trimmedSuffix = suffix.replace(/^\/+/, "");
  return basePath === "" ? trimmedSuffix : `${basePath}/${trimmedSuffix}`;
}

function isOriginAllowed(origin: string, allowedOrigins: string[], allowLanOrigins: boolean): boolean {
  if (allowedOrigins.length === 0) {
    return true;
  }
  if (allowedOrigins.includes(origin)) {
    return true;
  }
  if (!allowLanOrigins) {
    return false;
  }

  try {
    const url = new URL(origin);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      return false;
    }
    const host = url.hostname.toLowerCase();
    return (
      host === "localhost" ||
      host === "127.0.0.1" ||
      host === "::1" ||
      host.endsWith(".local") ||
      host.startsWith("10.") ||
      host.startsWith("192.168.") ||
      /^172\.(1[6-9]|2\d|3[0-1])\./.test(host)
    );
  } catch {
    return false;
  }
}

function parseClientMessage(text: string):
  | { ok: true; message: ClientMessage }
  | { ok: false; code: ErrorCode; message: string } {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    return {
      ok: false,
      code: "invalid_message",
      message: "Malformed JSON.",
    };
  }

  if (!isRecord(value) || typeof value.type !== "string") {
    return {
      ok: false,
      code: "invalid_message",
      message: "Message failed validation.",
    };
  }

  switch (value.type) {
    case "ping":
    case "leave_room":
      return { ok: true, message: { type: value.type } };
    case "create_room":
      if (typeof value.playerName === "string" && value.playerName.length <= 64) {
        return { ok: true, message: { type: "create_room", playerName: value.playerName } };
      }
      break;
    case "join_room":
      if (
        typeof value.roomCode === "string" &&
        value.roomCode.length >= 4 &&
        value.roomCode.length <= 12 &&
        typeof value.playerName === "string" &&
        value.playerName.length <= 64
      ) {
        return {
          ok: true,
          message: {
            type: "join_room",
            roomCode: value.roomCode,
            playerName: value.playerName,
          },
        };
      }
      break;
    case "set_ready":
      if (typeof value.ready === "boolean") {
        return { ok: true, message: { type: "set_ready", ready: value.ready } };
      }
      break;
    case "set_room_scene":
      if (value.sceneId === "phase4_beachhead" || value.sceneId === "phase4_scene_1_2") {
        return { ok: true, message: { type: "set_room_scene", sceneId: value.sceneId } };
      }
      break;
    case "webrtc_offer":
      if (typeof value.targetPeerId === "string" && typeof value.sdp === "string") {
        return {
          ok: true,
          message: {
            type: "webrtc_offer",
            targetPeerId: value.targetPeerId,
            sdp: value.sdp,
          },
        };
      }
      break;
    case "webrtc_answer":
      if (typeof value.targetPeerId === "string" && typeof value.sdp === "string") {
        return {
          ok: true,
          message: {
            type: "webrtc_answer",
            targetPeerId: value.targetPeerId,
            sdp: value.sdp,
          },
        };
      }
      break;
    case "webrtc_ice":
      if (typeof value.targetPeerId === "string" && typeof value.candidate === "string") {
        return {
          ok: true,
          message: {
            type: "webrtc_ice",
            targetPeerId: value.targetPeerId,
            candidate: value.candidate,
            sdpMid: typeof value.sdpMid === "string" || value.sdpMid === null ? value.sdpMid : undefined,
            sdpMLineIndex:
              typeof value.sdpMLineIndex === "number" || value.sdpMLineIndex === null
                ? value.sdpMLineIndex
                : undefined,
          },
        };
      }
      break;
  }

  return {
    ok: false,
    code: "invalid_message",
    message: "Message failed validation.",
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
