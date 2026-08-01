# Multiplayer Protocol Draft — Operation Steelstorm

This document covers **signaling** (WebSocket JSON) and a **gameplay RPC draft** (Godot Multiplayer API over WebRTC). Gameplay RPCs are **not implemented in Phase 0**.

## Transport summary

| Stage | Transport | Payload |
|-------|-----------|---------|
| Matchmaking / lobby | WebSocket ↔ signaling server | JSON messages below |
| WebRTC handshake | WebSocket relay | SDP offer/answer + ICE |
| Gameplay | WebRTC via `WebRTCMultiplayerPeer` | Godot RPCs / sync |

Signaling must **not** carry continuous gameplay after the peer connection is established.

---

## Signaling messages

### Conventions

- UTF-8 JSON objects with a `type` field
- Player names max length: config (`PLAYER_NAME_MAX_LENGTH`, default 16)
- Room codes: uppercase alphanumeric, length 6 by default
- Max message size enforced server-side (~72 KB hard cap)
- Rate limit: default 60 messages / 10s / connection

### Client → server

| Type | Params | Notes |
|------|--------|-------|
| `create_room` | `playerName` | Creator becomes host |
| `join_room` | `roomCode`, `playerName` | Errors: not found, full, duplicate name |
| `leave_room` | — | Also implied on disconnect |
| `set_ready` | `ready: bool` | Lobby only |
| `webrtc_offer` | `targetPeerId`, `sdp` | Relayed to target |
| `webrtc_answer` | `targetPeerId`, `sdp` | Relayed to target |
| `webrtc_ice` | `targetPeerId`, `candidate`, optional `sdpMid`, `sdpMLineIndex` | Relayed |
| `ping` | — | Liveness |

### Server → client

| Type | Params | Notes |
|------|--------|-------|
| `welcome` | `peerId` | Assigned on connect |
| `room_created` | `roomCode`, `peerId`, `isHost` | |
| `room_joined` | `roomCode`, `peerId`, `isHost`, `players[]` | Full lobby snapshot |
| `player_joined` | `player` | Broadcast |
| `player_left` | `peerId`, `reason` | Broadcast |
| `player_ready` | `peerId`, `ready` | Broadcast |
| `host_changed` | `peerId` | If host disconnects and peers remain |
| `webrtc_offer` / `webrtc_answer` / `webrtc_ice` | `fromPeerId` + payload | Relay |
| `error` | `code`, `message` | See codes below |
| `pong` | — | |

### Error codes

`invalid_message`, `rate_limited`, `room_not_found`, `room_full`, `duplicate_name`, `not_in_room`, `target_not_found`, `forbidden`

### Lobby player object

```json
{
  "peerId": "uuid",
  "name": "Scout",
  "ready": false,
  "isHost": true
}
```

---

## Gameplay RPC categories (draft)

Authority: **H** = host only may send authoritative result; **C** = any client may request; **A** = any peer (usually host broadcasts).

Transfer: **R** = reliable; **U** = unreliable (or ordered-unreliable where Godot allows).

### Lobby / session (in-game channel after WebRTC)

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_match_start` | Host | All | H | `mission_id`, `seed` | R | once | Host only; mission known |
| `rpc_return_lobby` | Host | All | H | `reason` | R | rare | Host only |
| `rpc_peer_announce` | Host | All | H | `peer_id`, `player_slot`, `name` | R | on join | Slot unique |

### Player input

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_input_frame` | Client | Host | C | `seq`, `bits`, `aim`, `buttons` | U | 20–60 Hz | Rate limit; clamp sticks |
| `rpc_fire_request` | Client | Host | C | `seq`, `weapon_id`, `aim` | R | weapon fire rate | Ammo, cooldown, alive |
| `rpc_grenade_request` | Client | Host | C | `seq`, `aim` | R | low | Count, cooldown |
| `rpc_interact_request` | Client | Host | C | `target_net_id` | R | low | Distance, state |
| `rpc_revive_request` | Client | Host | C | `downed_peer_id` | R | low | Distance, both valid |
| `rpc_vehicle_enter_request` | Client | Host | C | `vehicle_id`, `seat` | R | low | Distance, seat free |
| `rpc_vehicle_exit_request` | Client | Host | C | `vehicle_id` | R | low | Occupancy |

### Player state

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_player_snapshot` | Host | All | H | `peer_id`, `pos`, `vel`, `anim`, `aim`, `tick` | U | 15–20 Hz | Host only |
| `rpc_player_downed` | Host | All | H | `peer_id` | R | rare | Host only |
| `rpc_player_revived` | Host | All | H | `peer_id`, `hp` | R | rare | Host only |
| `rpc_player_died` | Host | All | H | `peer_id` | R | rare | Host only |

### Combat

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_damage_applied` | Host | All | H | `target_id`, `amount`, `source_id` | R | bursty | Host computes amount |
| `rpc_weapon_changed` | Host | All | H | `peer_id`, `weapon_id`, `ammo` | R | low | Host inventory |

### Enemies

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_enemy_spawn` | Host | All | H | `net_id`, `type_id`, `pos` | R | on spawn | Host only |
| `rpc_enemy_snapshot` | Host | All | H | `net_id`, `pos`, `state`, `hp`, `tick` | U | 15–20 Hz | Host only |
| `rpc_enemy_despawn` | Host | All | H | `net_id`, `reason` | R | on death | Host only |

### Projectiles

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_projectile_spawn` | Host | All | H | `net_id`, `owner`, `weapon`, `pos`, `vel` | R | fire rate | Host only |
| `rpc_projectile_despawn` | Host | All | H | `net_id`, `reason` | R | on hit/timeout | Host only |

### Pickups / rescue

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_pickup_spawn` | Host | All | H | `net_id`, `type`, `pos` | R | rare | Host only |
| `rpc_pickup_collected` | Host | All | H | `net_id`, `peer_id` | R | rare | Eligibility |
| `rpc_npc_rescued` | Host | All | H | `npc_id`, `peer_id`, `reward` | R | once | Once-only flag |

### Vehicles

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_vehicle_snapshot` | Host | All | H | `id`, `pos`, `vel`, `hp`, `seats` | U | 15–20 Hz | Host only |
| `rpc_vehicle_destroyed` | Host | All | H | `id` | R | rare | Host only |

### Mission / connection

| Name | Sender | Receiver | Auth | Params | Transfer | Max freq | Validation |
|------|--------|----------|------|--------|----------|----------|------------|
| `rpc_objective_update` | Host | All | H | `objective_id`, `state` | R | rare | Ordered progression |
| `rpc_boss_phase` | Host | All | H | `phase`, `hp` | R | rare | Host only |
| `rpc_mission_complete` | Host | All | H | `scores` | R | once | Host only |
| `rpc_mission_failed` | Host | All | H | `reason` | R | once | Host only |
| `rpc_reject` | Host | One | H | `seq`, `code` | R | as needed | Inform client of invalid intent |

### Failure behavior

- Invalid client intent → host ignores + optional `rpc_reject`; never apply damage/score from client numbers.
- Duplicate spawn IDs → reject / log Error.
- Host disconnect → clients show connection-lost; return to lobby (MVP: no host migration for active mission; signaling may elect lobby host if still in lobby).
- High latency → interpolate remotes; do not rewind entire sim in Phase 2–3.

## Snapshot policy

- Default send rate: **20 Hz** (`network_config.json` → `snapshots.send_rate_hz`)
- Clients interpolate between snapshots
- Do not send positions every rendered frame

## Security notes

- All damage values originate on host
- Signaling validates JSON with Zod; clamps names; enforces room size
- Browser must not embed production TURN passwords; inject via secure config at deploy time
