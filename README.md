# Operation Steelstorm

> **Buka di Godot:** import folder **`game/`** (file `game/project.godot`).  
> Jangan buka root repo `ok-thank-you/` — di situ tidak ada `project.godot`, jadi Godot akan error.  
> Detail: [OPEN_IN_GODOT.md](OPEN_IN_GODOT.md) · helper: `./scripts/run-godot.sh`

Temporary working title for an original browser-based 2D side-scrolling run-and-gun game with offline single-player and online cooperative multiplayer.

> **Rename-friendly:** replace `Operation Steelstorm` / `operation-steelstorm` project-wide when the final title is chosen.

## Status

**Current phase: Phase 4 — Vertical slice mission + co-op**

Offline Phase 4 mission + online co-op Phase 4 mission (host-authoritative) are available.

## Goals

- Runs in desktop web browsers (Godot Web / WebAssembly)
- Offline 1-player mode
- Online 2-player co-op (architecture prepared for 4 players)
- Host-authoritative peer-to-peer over WebRTC
- Lightweight WebSocket signaling only for matchmaking / WebRTC handshake
- Static hosting for the game client + separate signaling service

## Repository layout

```text
operation-steelstorm/
├── README.md
├── PROJECT_RULES.md
├── ARCHITECTURE.md
├── ROADMAP.md
├── CHANGELOG.md
├── game/                 # Godot 4.5+ client (Compatibility renderer)
├── signaling-server/     # Node.js + TypeScript WebSocket signaling
├── deployment/           # Docker Compose, nginx, hosting notes
└── docs/                 # Design and protocol docs
```

## Prerequisites

| Tool | Notes |
|------|--------|
| Godot **4.5 stable** (CI target; local smoke tests may use newer 4.x Compatibility builds) | Open `game/project.godot` |
| Node.js **20+** | Signaling server |
| npm | Signaling dependencies |
| Docker (optional) | Signaling / compose deploy |

## Quick start (Phase 0)

### Godot client

1. Open `game/project.godot` in Godot.
2. Run the main scene (`scenes/ui/boot_test.tscn`).
3. Click **Click to Start** → **Single Player — Combat Room**.
4. Clear the three Patrol Troopers.

Controls: `A/D` move · `Space` jump · `S` crouch · `W`/Up aim up · `J` shoot · `Esc` menu

Headless smoke test:

```bash
godot --path game --headless --editor --quit-after 20   # once, to refresh class cache
godot --path game --headless --script tests/phase1_smoke.gd
```

### Signaling server

```bash
cd signaling-server
cp .env.example .env
npm install
npm run typecheck
npm test
npm run dev
```

Health check: `http://127.0.0.1:8787/health`

Multiplayer (two Godot windows): Main Menu → Multiplayer → Create/Join → Ready → Host Start Match.

### Web export

Export preset: **Web** → `game/web/operation-steelstorm.html`  
Requires Godot export templates for the matching engine version. See [docs/web-export-guide.md](docs/web-export-guide.md).

LAN browser testing:

```bash
HTTPS=1 ./scripts/serve-web.sh
cd signaling-server && npm run dev
```

Then open `https://<your-lan-ip>:8080/operation-steelstorm.html`.
If the browser blocks the self-signed cert, run `bash ./scripts/trust-local-cert.sh` once on macOS.

## Documentation map

| Doc | Purpose |
|-----|---------|
| [PROJECT_RULES.md](PROJECT_RULES.md) | IP, tech constraints, Cursor working rules |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Systems, folders, authority model |
| [ROADMAP.md](ROADMAP.md) | Phased delivery |
| [docs/multiplayer-protocol.md](docs/multiplayer-protocol.md) | Signaling + gameplay RPC draft |
| [docs/gameplay-design.md](docs/gameplay-design.md) | Original setting / vertical slice |
| [docs/asset-guide.md](docs/asset-guide.md) | Placeholder → final art replacement |
| [docs/phase-4-plan.md](docs/phase-4-plan.md) | Detailed vertical-slice production plan |
| [docs/phase-4-asset-ideation.md](docs/phase-4-asset-ideation.md) | SpriteCook-driven asset generation plan |
| [docs/testing-guide.md](docs/testing-guide.md) | Manual / automated test plans |
| [docs/web-export-guide.md](docs/web-export-guide.md) | Browser export notes |
| [deployment/hosting-guide.md](deployment/hosting-guide.md) | Static client + signaling deploy |

## Intellectual property

This project must remain **original**. Do not copy Metal Slug or any other game’s characters, art, audio, levels, UI, or code. Genre mechanics (run, jump, shoot, co-op) are fine.

## License

Project license TBD. Do not commit proprietary ripped assets or production TURN credentials.
