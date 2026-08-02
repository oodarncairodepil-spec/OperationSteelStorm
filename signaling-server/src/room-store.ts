import type { LobbyPlayer } from "./protocol.js";

export interface RoomPlayer {
  peerId: string;
  name: string;
  ready: boolean;
}

export interface Room {
  code: string;
  hostPeerId: string;
  sceneId: string;
  players: Map<string, RoomPlayer>;
  updatedAt: number;
}

export class RoomStore {
  private readonly rooms = new Map<string, Room>();
  private readonly peerToRoom = new Map<string, string>();

  constructor(
    private readonly maxPlayers: number,
    private readonly roomCodeLength: number,
  ) {}

  createRoom(peerId: string, playerName: string): Room {
    const code = this.generateUniqueCode();
    const room: Room = {
      code,
      hostPeerId: peerId,
      sceneId: "phase4_beachhead",
      players: new Map([
        [
          peerId,
          {
            peerId,
            name: playerName,
            ready: false,
          },
        ],
      ]),
      updatedAt: Date.now(),
    };
    this.rooms.set(code, room);
    this.peerToRoom.set(peerId, code);
    return room;
  }

  getRoom(code: string): Room | undefined {
    return this.rooms.get(code.toUpperCase());
  }

  getRoomForPeer(peerId: string): Room | undefined {
    const code = this.peerToRoom.get(peerId);
    return code ? this.rooms.get(code) : undefined;
  }

  joinRoom(
    code: string,
    peerId: string,
    playerName: string,
  ): { ok: true; room: Room } | { ok: false; reason: "room_not_found" | "room_full" | "duplicate_name" } {
    const room = this.getRoom(code);
    if (!room) {
      return { ok: false, reason: "room_not_found" };
    }
    if (room.players.size >= this.maxPlayers) {
      return { ok: false, reason: "room_full" };
    }
    const normalized = playerName.trim().toLowerCase();
    for (const player of room.players.values()) {
      if (player.name.trim().toLowerCase() === normalized) {
        return { ok: false, reason: "duplicate_name" };
      }
    }

    room.players.set(peerId, {
      peerId,
      name: playerName,
      ready: false,
    });
    room.updatedAt = Date.now();
    this.peerToRoom.set(peerId, room.code);
    return { ok: true, room };
  }

  leaveRoom(peerId: string): { room: Room; removed: RoomPlayer; hostChanged: boolean } | undefined {
    const room = this.getRoomForPeer(peerId);
    if (!room) {
      return undefined;
    }
    const removed = room.players.get(peerId);
    if (!removed) {
      return undefined;
    }

    room.players.delete(peerId);
    this.peerToRoom.delete(peerId);
    room.updatedAt = Date.now();

    let hostChanged = false;
    if (room.hostPeerId === peerId) {
      const nextHost = room.players.values().next().value as RoomPlayer | undefined;
      if (nextHost) {
        room.hostPeerId = nextHost.peerId;
        hostChanged = true;
      }
    }

    if (room.players.size === 0) {
      this.rooms.delete(room.code);
    }

    return { room, removed, hostChanged };
  }

  setReady(peerId: string, ready: boolean): Room | undefined {
    const room = this.getRoomForPeer(peerId);
    const player = room?.players.get(peerId);
    if (!room || !player) {
      return undefined;
    }
    player.ready = ready;
    room.updatedAt = Date.now();
    return room;
  }

  setScene(
    peerId: string,
    sceneId: string,
  ): { ok: true; room: Room } | { ok: false; reason: "not_in_room" | "forbidden" } {
    const room = this.getRoomForPeer(peerId);
    if (!room) {
      return { ok: false, reason: "not_in_room" };
    }
    if (room.hostPeerId !== peerId) {
      return { ok: false, reason: "forbidden" };
    }
    room.sceneId = sceneId === "phase4_scene_1_2" ? "phase4_scene_1_2" : "phase4_beachhead";
    room.updatedAt = Date.now();
    return { ok: true, room };
  }

  toLobbyPlayers(room: Room): LobbyPlayer[] {
    return [...room.players.values()].map((player) => ({
      peerId: player.peerId,
      name: player.name,
      ready: player.ready,
      isHost: player.peerId === room.hostPeerId,
    }));
  }

  cleanupIdle(ttlMs: number, now = Date.now()): string[] {
    const removed: string[] = [];
    for (const [code, room] of this.rooms) {
      if (now - room.updatedAt > ttlMs) {
        for (const peerId of room.players.keys()) {
          this.peerToRoom.delete(peerId);
        }
        this.rooms.delete(code);
        removed.push(code);
      }
    }
    return removed;
  }

  roomCount(): number {
    return this.rooms.size;
  }

  private generateUniqueCode(): string {
    const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    for (let attempt = 0; attempt < 50; attempt += 1) {
      let code = "";
      for (let i = 0; i < this.roomCodeLength; i += 1) {
        code += alphabet[Math.floor(Math.random() * alphabet.length)];
      }
      if (!this.rooms.has(code)) {
        return code;
      }
    }
    throw new Error("Unable to allocate unique room code");
  }
}
