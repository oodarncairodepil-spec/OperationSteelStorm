# Changelog

## 0.3.0 — Phase 3 multiplayer combat

- `HostCombatSession`: host-auth fire, projectiles, enemy sync, revive, reject bogus damage claims
- `NetPlayer` combat (HP, shoot intent, downed, revive)
- Networked Patrol Trooper snapshots / death once
- Godot open docs (`OPEN_IN_GODOT.md`, `scripts/run-godot.sh`) — open **`game/`** not repo root
- Web export templates (nothreads) + `scripts/serve-web.sh`

## 0.2.0 — Phase 2 multiplayer connection

- `NetworkManager` autoload: signaling WebSocket + WebRTC mesh
- Multiplayer menu, join-room, lobby (ready/start), connection debug panel
- `MpArena` with two `NetPlayer` placeholders and snapshot interpolation
- Disconnect dialog / host-lost handling; return to menu cleans session
- Phase 2 smoke test for config + scene load

## 0.1.0 — Phase 1 offline prototype

- Offline combat room with platforms and three Patrol Troopers
- Player Rook: move, jump, crouch, aim up, shoot Standard Rifle
- Components: Health, Hurtbox, Hitbox, Weapon, StateMachine, ObjectPool
- Resource definitions for player, rifle, and patrol trooper
- Follow camera + HUD (HP, weapon, ammo, score, objective, results)
- SceneManager autoload; Boot → Main Menu → Combat Room
- Headless smoke test `game/tests/phase1_smoke.gd`

## 0.0.1 — Phase 0 scaffolding

- Initial monorepo layout (`game/`, `signaling-server/`, `docs/`, `deployment/`)
- Godot project renamed to **Operation Steelstorm**
- Compatibility renderer, 640×360 viewport, browser-friendly stretch
- Boot test scene with title, version, platform, Click to Start
- Web export preset (single-threaded)
- Network config placeholder (`network_config.json`)
- Node/TypeScript signaling skeleton (rooms, ready, WebRTC relay, health, rate limits)
- Core documentation and multiplayer protocol draft
- GitHub Actions CI workflow (Godot parse/export attempt + signaling tests)
