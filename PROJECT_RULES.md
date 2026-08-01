# Project Rules — Operation Steelstorm

## Intellectual property
- Create original names, art direction, enemies, weapons, bosses, vehicles, maps, and audio.
- General genre mechanics are allowed: run, jump, crouch, shoot, rescue NPCs, bosses, vehicles, co-op multiplayer.

## Technology constraints

### Allowed

- Godot **4.5 stable** target (Compatibility / GL Compatibility renderer)
- GDScript only (typed where practical)
- Godot High-Level Multiplayer API
- `WebRTCMultiplayerPeer` for gameplay networking
- WebSocket signaling for matchmaking / WebRTC handshake
- Single-threaded Godot Web export
- Signaling: Node.js + TypeScript + WebSocket + in-memory rooms

### Forbidden

- C#
- GDExtension unless absolutely necessary
- ENet for browser clients
- Native-only dependencies / plugins that break Web export
- Continuous gameplay traffic through the signaling server after WebRTC is up
- Copyrighted ripped assets
- Committing production TURN credentials or other secrets

## Multiplayer rules

- MVP: **host-authoritative** peer-to-peer.
- Room creator is host.
- Clients send **input / intent**, not authoritative results.
- Host validates fire rate, ammo, damage sources, pickups, mission events, etc.
- Design so a dedicated authoritative server can replace the host later.
- Prepare for 4 players; ship stable 2-player first.

## Cursor / agent working instructions

Before code changes:

1. Inspect the repository.
2. Read this file and `ARCHITECTURE.md`.
3. Identify the current implementation phase (`ROADMAP.md`).
4. Avoid duplicating existing systems.

For every task:

1. State the immediate goal.
2. List files created/changed.
3. Implement **only** the current milestone.
4. Run relevant validation.
5. Report errors honestly.
6. Update docs.
7. Provide exact testing steps.
8. **Stop** after the milestone.

Do not:

- Rewrite unrelated working code
- Build later phases early
- Swallow errors with empty catches
- Mark placeholders as production-ready
- Claim tests passed without running them

Ask before:

- Changing main architecture
- Replacing multiplayer transport
- Adding paid third-party services
- Deleting significant working code
- Starting a new implementation phase

## Code quality (GDScript)

- Typed variables and signatures where reasonable
- Focused responsibilities; descriptive names
- No unexplained magic numbers
- Validate external / network data
- No per-frame `get_nodes_in_group()` spam
- Avoid UI ↔ gameplay tight coupling and circular deps
- Comment non-obvious networking authority

## Scene documentation

Important scenes should note: purpose, expected parent, required children, exported properties, signals, multiplayer authority.

## Phase gate

**Current gate: Phase 0 only.**  
Do not implement player combat, enemies, or the complete multiplayer gameplay stack until Phase 0 is accepted and the next phase is explicitly started.
