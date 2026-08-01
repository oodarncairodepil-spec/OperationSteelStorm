# Architecture — Operation Steelstorm

## Overview

```text
┌────────────────────┐     WebSocket      ┌─────────────────────┐
│  Godot Web Client  │◄──────────────────►│  Signaling Server   │
│  (static HTML/WASM)│  rooms + WebRTC    │  Node.js / TS / ws  │
└─────────┬──────────┘  offer/answer/ICE  └─────────────────────┘
          │
          │ WebRTC data channels
          │ (Godot Multiplayer API)
          ▼
   Host-authoritative P2P session
```

After WebRTC connects, **gameplay state does not traverse the signaling server**.

## Runtime targets

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Engine | Godot 4.5+ Compatibility | WebGL 2 friendly, single-threaded Web export |
| Internal resolution | 640×360 (configurable) | Pixel-art friendly; integer/viewport stretch |
| Stretch | `viewport` + `keep` + integer scale when possible | Crisp pixels in browser |
| Physics | Fixed 60 Hz ticks | Stable gameplay stepping |
| Netcode MVP | Host-auth P2P via `WebRTCMultiplayerPeer` | Browser-compatible; later replaceable by dedicated server |
| Snapshots | ~15–20 Hz | Render 60 FPS with interpolation |
| Signaling | Separate Node service | Static client hosting stays simple |

## Repository boundaries

| Path | Responsibility |
|------|----------------|
| `game/` | Godot client only |
| `signaling-server/` | Matchmaking + WebRTC signaling only |
| `deployment/` | Compose, nginx, hosting docs |
| `docs/` | Protocol, design, testing, export |

## Godot folder roles

| Path | Role |
|------|------|
| `autoload/` | Global managers only when truly global |
| `components/` | Reusable composition pieces (`HealthComponent`, etc.) |
| `entities/` | Players, enemies, projectiles, vehicles, world props |
| `multiplayer/` | Network config, peers, RPC helpers, lobby bridge |
| `resources/` | Weapon/enemy/mission Resource definitions |
| `scenes/` | Levels, menus, UI |
| `scripts/` | Shared utilities not tied to a single entity |
| `tests/` | GUT / custom test hooks (later phases) |
| `web/` | Export output (artifacts; may be gitignored later) |

## Planned autoloads

Only add when needed by a phase. Responsibilities:

| Autoload | Responsibility |
|----------|----------------|
| `GameManager` | High-level game/mission flow, pause, fail/complete |
| `SceneManager` | Scene transitions / loading screens |
| `NetworkManager` | Signaling client, WebRTC peer, authority helpers |
| `AudioManager` | Buses, volumes, unlock-on-gesture |
| `SettingsManager` | Settings persistence |
| `SaveManager` | Local progress / last player name |
| `InputManager` | Actions, remapping, device prompts, future touch hooks |

**Phase 0:** no gameplay autoloads registered yet (keeps boot scene minimal).

**Phase 1:** `SceneManager` registered for Boot → Main Menu → Combat Room navigation.

**Phase 2:** `NetworkManager` registered for signaling + WebRTC lobby/session lifecycle.

## Authority model

- **Host (room creator):** authoritative health, spawns, AI, damage, projectiles, drops, score, mission/boss/game-over.
- **Clients:** local predictive movement where useful; send sequenced input/intent; interpolate remotes.
- **Never trust clients for:** damage amounts, health, scores, enemy deaths, pickup claims, mission completion.

Future migration path: move host validation into a dedicated headless Godot or custom server without rewriting entity APIs that already speak “request → validate → broadcast”.

## Component plan (later phases)

- `HealthComponent`, `DamageReceiverComponent`
- `HitboxComponent`, `HurtboxComponent`
- `WeaponComponent`, `MovementComponent`
- `InteractableComponent`
- `NetworkIdentityComponent`, `NetworkInterpolationComponent`
- `StateMachine`, `ObjectPool`, `SpawnManager`

## Configuration

- `game/multiplayer/network_config.json` — signaling URL, STUN list, snapshot rate, lobby limits
- Local TURN overrides via gitignored `network_config.local.json` (see example file)
- Signaling env vars — see `signaling-server/.env.example`

## Logging

Structured logs with levels: Debug, Info, Warning, Error.  
Do not log every position snapshot at Info.

## Decisions locked in Phase 0

1. Monorepo with separated `game/` and `signaling-server/`.
2. Host-authoritative P2P for MVP; dedicated server later.
3. Signaling is room + WebRTC handshake only.
4. Internal resolution 640×360; Compatibility renderer; Web threads **off**.
5. Max players config: MVP `2`, planned `4`.
6. Working title kept replaceable in docs and `project.godot` name.
