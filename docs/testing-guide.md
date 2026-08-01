# Testing Guide — Operation Steelstorm

## Phase 3 checks

### Automated

```bash
godot --path game --headless --script tests/phase3_smoke.gd
```

### Manual co-op combat

1. `cd signaling-server && npm run dev`
2. Two Godot windows on **`game/`**
3. Create/Join → Ready → Start Match
4. Both shoot (`J`); enemy HP matches on both screens
5. Down a player; ally presses `E` nearby to revive
6. Confirm HUD `REJECTED_DMG` stays 0 during normal play

### Browser

```bash
HTTPS=1 ./scripts/serve-web.sh
# other terminal: cd signaling-server && npm run dev
# open https://127.0.0.1:8080/operation-steelstorm.html
```

Ensure signaling `.env` allows the HTTPS origin or enable `ALLOW_LAN_ORIGINS=true`.

## Phase 2 checks

### Automated

```bash
cd signaling-server && npm test && npm run dev
# other terminal:
godot --path game --headless --script tests/phase2_smoke.gd
```

### Manual two-client (native editor)

1. Start signaling: `cd signaling-server && npm run dev`
2. Open **two** Godot instances on `game/project.godot` (or one editor + one exported/debug instance).
3. Instance A: Multiplayer → Create Room → note room code → Ready.
4. Instance B: Multiplayer → Join Room → enter code (different name) → Ready.
5. Confirm lobby debug shows `webrtc: connected`.
6. Host: Start Match. Both enter arena; each should see the other move (`A/D`, `Space`).
7. Close B: A shows disconnect dialog and remains stable.
8. Repeat; close host: client shows host-lost and can return to menu.

### Manual two-client (web)

Requires Web export templates + signaling `ALLOWED_ORIGINS` matching the static host origin. Use two browser windows / incognito.

For same-LAN device/browser testing, use HTTPS:

```bash
HTTPS=1 ./scripts/serve-web.sh
cd signaling-server && npm run dev
# open https://<host-lan-ip>:8080/operation-steelstorm.html
```

The Web client now resolves signaling to `wss://<current-page-host>:8787` automatically on web builds.
If your browser blocks the self-signed certificate, trust it once on macOS with `bash ./scripts/trust-local-cert.sh`.

## Phase 1 checks

### Offline combat room

1. Open `game/project.godot` and run.
2. Click to Start → Single Player — Combat Room.
3. Verify: move, jump, crouch, aim up, shoot.
4. Take damage from a trooper (flash/i-frames).
5. Defeat all three troopers → Room Cleared.
6. Die on purpose → Mission Failed → Restart / Main Menu.

### Automated

```bash
godot --path game --headless --script tests/phase1_smoke.gd
```

Expect: `players=1 enemies=3` and `Phase1Smoke OK`.

## Phase 0 checks

### Godot boot scene

1. Open `game/project.godot` in Godot 4.5+ (Compatibility).
2. Run main scene.
3. Confirm: title **Operation Steelstorm**, Godot version string, platform (Native/Web), **Click to Start** works.
4. Headless: `godot --path game --headless --quit-after 2`

### Signaling server

```bash
cd signaling-server
npm install
npm run typecheck
npm test
npm run dev
curl -s http://127.0.0.1:8787/health
```

## Later-phase checklists (planned)

### Gameplay

Movement, jump, crouch, shoot, damage, i-frames, death, revive, weapon pickup, vehicle enter/exit, mission complete.

### Multiplayer

Create/join room, invalid/full room, host start, remote move, simultaneous shoot, enemy/pickup sync, disconnects, latency/loss, duplicate/invalid RPC, lobby return.

### Manual two-client procedure

1. Start signaling server.
2. Serve Web build over HTTPS/HTTP as required for WebRTC.
3. Open two windows (or normal + incognito, or two machines).
4. Create room on A; join code on B.
5. Verify both peers connect; move; disconnect one; confirm other stays stable.
6. Optional: Chrome DevTools Network throttling / WebRTC internals.

### Web

Chrome, Firefox, Edge, Safari (where practical), fullscreen, audio unlock, resize, gamepad, refresh, focus loss, slow load, signaling down.
