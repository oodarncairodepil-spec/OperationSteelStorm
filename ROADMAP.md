# Roadmap — Operation Steelstorm

## Current phase

**Phase 3 — Multiplayer combat** (complete for combat MVP)

## Phase 0 — Documentation and scaffolding

- [x] Folder structure
- [x] Godot project (Compatibility, 640×360)
- [x] Signaling-server skeleton
- [x] Core docs + protocol draft
- [x] Web export preset
- [x] Boot / Click-to-Start test scene
- [x] Local Godot run verified on this machine
- [x] Web export verified (templates for local 4.7.1 + CI 4.5)

**Exit criteria:** Boot scene runs; signaling builds/tests; docs exist; no combat systems yet.

## Phase 1 — Offline gameplay prototype

- [x] Placeholder player (run, jump, crouch, aim up, shoot)
- [x] Standard rifle (Resource-driven, unlimited ammo)
- [x] Patrol Trooper enemy (patrol → detect → fire)
- [x] Damage + invulnerability + death
- [x] Combat room test level
- [x] Follow camera + basic HUD
- [x] Boot → Main Menu → Combat Room flow
- [x] Headless smoke test (`tests/phase1_smoke.gd`)
- [x] Web export verified (still needs export templates)

**Exit criteria:** Player can clear the offline combat room. No multiplayer required.

## Phase 2 — Multiplayer connection prototype

- [x] Signaling client (WebSocket) in `NetworkManager`
- [x] Create / join room + ready + lobby UI
- [x] WebRTC mesh (`WebRTCMultiplayerPeer`) offer/answer/ICE
- [x] Two placeholder `NetPlayer`s with remote movement sync
- [x] Disconnect handling + connection debug panel
- [x] Headless smoke (`tests/phase2_smoke.gd`)
- [ ] Manual two-client WebRTC verified on this machine (needs two game windows)

**Exit criteria:** Two clients join one room, see each other move, survive peer disconnect.

## Phase 3 — Multiplayer combat

- [x] Host-authoritative fire requests / projectile spawn
- [x] Host-only hit resolution; client damage claims rejected
- [x] Enemy spawn + snapshot sync + single death broadcast
- [x] Player health sync, downed state, revive (E near ally)
- [x] MpArena combat HUD / round result
- [x] `tests/phase3_smoke.gd`
- [x] Web export produces `game/web/operation-steelstorm.html`

**Exit criteria:** Both peers share enemy/player health; invalid client damage rejected; disconnect safe.

## Phase 4 — Vertical-slice mission

Mission flow, three weapons, four enemies, rescue, Assault Rover, Siege Walker boss, results screens.

Planning docs:

- `docs/phase-4-plan.md`
- `docs/phase-4-asset-ideation.md`

## Phase 5 — Polish

Temp visuals, audio buses/settings, gamepad, interpolation, errors, loading, deploy docs, perf.

## Explicit non-goals until later

- Four-player gameplay (prepare only)
- Mobile virtual controls (structure input for later)
- Full deterministic rollback
- Diagonal aiming unless trivial
- Paid third-party netcode services (ask first)
