import { createServer as createHttpServer, type IncomingMessage, type ServerResponse } from "node:http";
import { randomUUID } from "node:crypto";
import { createServer as createHttpsServer } from "node:https";
import { readFileSync } from "node:fs";
import { WebSocketServer, type WebSocket } from "ws";
import type { ServerConfig } from "./config.js";
import { Logger } from "./logger.js";
import { ClientMessageSchema, type ServerMessage } from "./protocol.js";
import { RateLimiter } from "./rate-limiter.js";
import { RoomStore } from "./room-store.js";

interface PeerState {
  id: string;
  socket: WebSocket;
  remoteAddress: string;
}

export class SignalingServer {
  private readonly roomStore: RoomStore;
  private readonly rateLimiter: RateLimiter;
  private readonly peers = new Map<string, PeerState>();
  private readonly logger: Logger;
  private cleanupTimer: NodeJS.Timeout | undefined;

  constructor(private readonly config: ServerConfig) {
    this.logger = new Logger(config.logLevel);
    this.roomStore = new RoomStore(config.maxPlayersPerRoom, config.roomCodeLength);
    this.rateLimiter = new RateLimiter(config.rateLimitWindowMs, config.rateLimitMaxMessages);
  }

  start(): void {
    const httpServer =
      this.config.tlsCertFile !== "" && this.config.tlsKeyFile !== ""
        ? createHttpsServer(
            {
              cert: readFileSync(this.config.tlsCertFile),
              key: readFileSync(this.config.tlsKeyFile),
            },
            (req, res) => {
              this.handleHttp(req, res);
            },
          )
        : createHttpServer((req, res) => {
            this.handleHttp(req, res);
          });

    const wss = new WebSocketServer({ server: httpServer });
    wss.on("connection", (socket, req) => {
      this.handleConnection(socket, req);
    });

    httpServer.listen(this.config.port, this.config.host, () => {
      this.logger.info("server_started", {
        host: this.config.host,
        port: this.config.port,
        maxPlayersPerRoom: this.config.maxPlayersPerRoom,
        tls: this.config.tlsCertFile !== "" && this.config.tlsKeyFile !== "",
      });
    });

    this.cleanupTimer = setInterval(() => {
      const removed = this.roomStore.cleanupIdle(this.config.roomIdleTtlMs);
      if (removed.length > 0) {
        this.logger.info("rooms_cleaned", { codes: removed });
      }
    }, 60_000);
  }

  private handleHttp(req: IncomingMessage, res: ServerResponse): void {
    if (req.url === "/health" || req.url === "/healthz") {
      res.writeHead(200, { "content-type": "application/json" });
      res.end(
        JSON.stringify({
          ok: true,
          rooms: this.roomStore.roomCount(),
          peers: this.peers.size,
        }),
      );
      return;
    }

    res.writeHead(404, { "content-type": "application/json" });
    res.end(JSON.stringify({ ok: false, error: "not_found" }));
  }

  private handleConnection(socket: WebSocket, req: IncomingMessage): void {
    const origin = req.headers.origin;
    if (origin && !this.isOriginAllowed(origin)) {
      this.logger.warning("origin_rejected", { origin });
      socket.close(1008, "origin_not_allowed");
      return;
    }

    const peerId = randomUUID();
    const remoteAddress = req.socket.remoteAddress ?? "unknown";
    const peer: PeerState = { id: peerId, socket, remoteAddress };
    this.peers.set(peerId, peer);
    this.logger.info("peer_connected", { peerId, remoteAddress });
    this.send(socket, { type: "welcome", peerId });

    socket.on("message", (raw) => {
      this.handleMessage(peer, raw.toString());
    });

    socket.on("close", () => {
      this.handleDisconnect(peerId, "socket_closed");
    });

    socket.on("error", (err) => {
      this.logger.warning("socket_error", { peerId, error: String(err) });
    });
  }

  private handleMessage(peer: PeerState, raw: string): void {
    if (raw.length > 72_000) {
      this.send(peer.socket, {
        type: "error",
        code: "invalid_message",
        message: "Message too large.",
      });
      return;
    }

    if (!this.rateLimiter.allow(peer.id)) {
      this.send(peer.socket, {
        type: "error",
        code: "rate_limited",
        message: "Too many messages. Slow down.",
      });
      return;
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      this.send(peer.socket, {
        type: "error",
        code: "invalid_message",
        message: "Malformed JSON.",
      });
      return;
    }

    const result = ClientMessageSchema.safeParse(parsed);
    if (!result.success) {
      this.send(peer.socket, {
        type: "error",
        code: "invalid_message",
        message: "Message failed validation.",
      });
      return;
    }

    const message = result.data;
    switch (message.type) {
      case "ping":
        this.send(peer.socket, { type: "pong" });
        break;
      case "create_room":
        this.onCreateRoom(peer, message.playerName);
        break;
      case "join_room":
        this.onJoinRoom(peer, message.roomCode, message.playerName);
        break;
      case "leave_room":
        this.onLeaveRoom(peer);
        break;
      case "set_ready":
        this.onSetReady(peer, message.ready);
        break;
      case "set_room_scene":
        this.onSetRoomScene(peer, message.sceneId);
        break;
      case "webrtc_offer":
      case "webrtc_answer":
      case "webrtc_ice":
        this.relaySignal(peer, message);
        break;
    }
  }

  private onCreateRoom(peer: PeerState, playerName: string): void {
    if (this.roomStore.getRoomForPeer(peer.id)) {
      this.send(peer.socket, {
        type: "error",
        code: "forbidden",
        message: "Already in a room.",
      });
      return;
    }

    const name = this.clampName(playerName);
    const room = this.roomStore.createRoom(peer.id, name);
    this.logger.info("room_created", { roomCode: room.code, peerId: peer.id });
    this.send(peer.socket, {
      type: "room_created",
      roomCode: room.code,
      peerId: peer.id,
      isHost: true,
      sceneId: room.sceneId,
    });
  }

  private onJoinRoom(peer: PeerState, roomCode: string, playerName: string): void {
    if (this.roomStore.getRoomForPeer(peer.id)) {
      this.send(peer.socket, {
        type: "error",
        code: "forbidden",
        message: "Already in a room.",
      });
      return;
    }

    const name = this.clampName(playerName);
    const join = this.roomStore.joinRoom(roomCode, peer.id, name);
    if (!join.ok) {
      this.send(peer.socket, {
        type: "error",
        code: join.reason,
        message: this.errorMessage(join.reason),
      });
      return;
    }

    const room = join.room;
    const players = this.roomStore.toLobbyPlayers(room);
    this.logger.info("room_joined", { roomCode: room.code, peerId: peer.id });
    this.send(peer.socket, {
      type: "room_joined",
      roomCode: room.code,
      peerId: peer.id,
      isHost: peer.id === room.hostPeerId,
      sceneId: room.sceneId,
      players,
    });

    const joinedPlayer = players.find((p) => p.peerId === peer.id);
    if (joinedPlayer) {
      this.broadcast(room.code, { type: "player_joined", player: joinedPlayer }, peer.id);
    }
  }

  private onLeaveRoom(peer: PeerState): void {
    this.handleDisconnect(peer.id, "left");
  }

  private onSetReady(peer: PeerState, ready: boolean): void {
    const room = this.roomStore.setReady(peer.id, ready);
    if (!room) {
      this.send(peer.socket, {
        type: "error",
        code: "not_in_room",
        message: "Not in a room.",
      });
      return;
    }
    this.broadcast(room.code, { type: "player_ready", peerId: peer.id, ready });
  }

  private onSetRoomScene(peer: PeerState, sceneId: string): void {
    const result = this.roomStore.setScene(peer.id, sceneId);
    if (!result.ok) {
      this.send(peer.socket, {
        type: "error",
        code: result.reason,
        message: result.reason === "forbidden" ? "Only the host can change the room mission." : "Not in a room.",
      });
      return;
    }
    this.broadcast(result.room.code, {
      type: "room_scene_changed",
      sceneId: result.room.sceneId,
    });
  }

  private relaySignal(
    peer: PeerState,
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
  ): void {
    const room = this.roomStore.getRoomForPeer(peer.id);
    if (!room) {
      this.send(peer.socket, {
        type: "error",
        code: "not_in_room",
        message: "Not in a room.",
      });
      return;
    }
    if (!room.players.has(message.targetPeerId)) {
      this.send(peer.socket, {
        type: "error",
        code: "target_not_found",
        message: "Target peer is not in this room.",
      });
      return;
    }

    const target = this.peers.get(message.targetPeerId);
    if (!target) {
      this.send(peer.socket, {
        type: "error",
        code: "target_not_found",
        message: "Target peer is offline.",
      });
      return;
    }

    if (message.type === "webrtc_offer") {
      this.send(target.socket, {
        type: "webrtc_offer",
        fromPeerId: peer.id,
        sdp: message.sdp,
      });
      return;
    }
    if (message.type === "webrtc_answer") {
      this.send(target.socket, {
        type: "webrtc_answer",
        fromPeerId: peer.id,
        sdp: message.sdp,
      });
      return;
    }
    this.send(target.socket, {
      type: "webrtc_ice",
      fromPeerId: peer.id,
      candidate: message.candidate,
      sdpMid: message.sdpMid ?? null,
      sdpMLineIndex: message.sdpMLineIndex ?? null,
    });
  }

  private handleDisconnect(peerId: string, reason: string): void {
    const peer = this.peers.get(peerId);
    const leave = this.roomStore.leaveRoom(peerId);
    this.peers.delete(peerId);
    this.rateLimiter.clear(peerId);

    if (leave) {
      this.broadcast(leave.room.code, {
        type: "player_left",
        peerId,
        reason,
      });
      if (leave.hostChanged) {
        this.broadcast(leave.room.code, {
          type: "host_changed",
          peerId: leave.room.hostPeerId,
        });
      }
      this.logger.info("peer_left_room", {
        peerId,
        roomCode: leave.room.code,
        reason,
        hostChanged: leave.hostChanged,
      });
    } else {
      this.logger.info("peer_disconnected", { peerId, reason });
    }

    if (peer && peer.socket.readyState === peer.socket.OPEN) {
      peer.socket.close();
    }
  }

  private broadcast(roomCode: string, message: ServerMessage, exceptPeerId?: string): void {
    const room = this.roomStore.getRoom(roomCode);
    if (!room) {
      return;
    }
    for (const player of room.players.values()) {
      if (player.peerId === exceptPeerId) {
        continue;
      }
      const peer = this.peers.get(player.peerId);
      if (peer) {
        this.send(peer.socket, message);
      }
    }
  }

  private send(socket: WebSocket, message: ServerMessage): void {
    if (socket.readyState === socket.OPEN) {
      socket.send(JSON.stringify(message));
    }
  }

  private clampName(name: string): string {
    return name.trim().slice(0, this.config.playerNameMaxLength);
  }

  private errorMessage(code: "room_not_found" | "room_full" | "duplicate_name"): string {
    switch (code) {
      case "room_not_found":
        return "Room not found.";
      case "room_full":
        return "Room is full.";
      case "duplicate_name":
        return "That player name is already in use in this room.";
    }
  }

  private isOriginAllowed(origin: string): boolean {
    if (this.config.allowedOrigins.length === 0) {
      return true;
    }
    if (this.config.allowedOrigins.includes(origin)) {
      return true;
    }
    if (!this.config.allowLanOrigins) {
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
        host.startsWith("10.") ||
        host.startsWith("192.168.") ||
        /^172\.(1[6-9]|2\d|3[0-1])\./.test(host)
      );
    } catch {
      return false;
    }
  }
}
