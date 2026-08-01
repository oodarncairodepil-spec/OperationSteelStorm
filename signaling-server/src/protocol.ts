import { z } from "zod";

export const ClientMessageSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("create_room"),
    playerName: z.string().min(1).max(64),
  }),
  z.object({
    type: z.literal("join_room"),
    roomCode: z.string().min(4).max(12),
    playerName: z.string().min(1).max(64),
  }),
  z.object({
    type: z.literal("leave_room"),
  }),
  z.object({
    type: z.literal("set_ready"),
    ready: z.boolean(),
  }),
  z.object({
    type: z.literal("webrtc_offer"),
    targetPeerId: z.string().min(1).max(64),
    sdp: z.string().min(1).max(64_000),
  }),
  z.object({
    type: z.literal("webrtc_answer"),
    targetPeerId: z.string().min(1).max(64),
    sdp: z.string().min(1).max(64_000),
  }),
  z.object({
    type: z.literal("webrtc_ice"),
    targetPeerId: z.string().min(1).max(64),
    candidate: z.string().min(1).max(8_000),
    sdpMid: z.string().nullable().optional(),
    sdpMLineIndex: z.number().int().nullable().optional(),
  }),
  z.object({
    type: z.literal("ping"),
  }),
]);

export type ClientMessage = z.infer<typeof ClientMessageSchema>;

export type ServerMessage =
  | { type: "welcome"; peerId: string }
  | { type: "room_created"; roomCode: string; peerId: string; isHost: true }
  | {
      type: "room_joined";
      roomCode: string;
      peerId: string;
      isHost: boolean;
      players: LobbyPlayer[];
    }
  | { type: "player_joined"; player: LobbyPlayer }
  | { type: "player_left"; peerId: string; reason: string }
  | { type: "player_ready"; peerId: string; ready: boolean }
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

export interface LobbyPlayer {
  peerId: string;
  name: string;
  ready: boolean;
  isHost: boolean;
}

export type ErrorCode =
  | "invalid_message"
  | "rate_limited"
  | "room_not_found"
  | "room_full"
  | "duplicate_name"
  | "not_in_room"
  | "target_not_found"
  | "forbidden";
