# Render Deploy Guide

## Recommended shape

Use **two Render services from the same GitHub repository**:

1. A **Static Site** for the exported Godot web client
2. A **Web Service** for the Node.js WebSocket signaling server

This repository is already organized as a monorepo:

- `game/` = Godot browser client
- `signaling-server/` = signaling backend

`render.yaml` at the repo root defines both services.

## Why one repo is better here

- The browser client and signaling protocol evolve together.
- One commit can update both sides safely.
- Render Blueprints support multiple services from one repo with per-service build settings and `rootDir`/`staticPublishPath`.
- You avoid duplicated docs, duplicated issue tracking, and version drift.

Use separate repos only if:

- different teams own each service
- release cadence must be independent
- you want separate access control or billing boundaries

## Service 1: Static Site

Create or sync the Blueprint service:

- Name: `operation-steelstorm-game`
- Type: `Static Site`
- Build command: `bash ./scripts/vercel-build.sh`
- Publish directory: `game/web`

Required environment variable:

```text
SIGNALING_URL=wss://<your-signaling-service>.onrender.com
```

The build injects that URL into the exported web client so production room creation knows where to connect.

## Service 2: Web Service

Create or sync the Blueprint service:

- Name: `operation-steelstorm-signaling`
- Type: `Web Service`
- Root directory: `signaling-server`
- Build command: `npm ci && npm run build`
- Start command: `npm run start`
- Health check path: `/health`

Required environment variable:

```text
ALLOWED_ORIGINS=https://<your-static-site>.onrender.com
```

Optional production env:

```text
HOST=0.0.0.0
LOG_LEVEL=info
MAX_PLAYERS_PER_ROOM=2
ROOM_CODE_LENGTH=6
PLAYER_NAME_MAX_LENGTH=16
ROOM_IDLE_TTL_MS=1800000
RATE_LIMIT_WINDOW_MS=10000
RATE_LIMIT_MAX_MESSAGES=60
```

## Render dashboard flow

1. Push `render.yaml` to GitHub.
2. In Render, choose **New > Blueprint**.
3. Select this repository.
4. Review the two services from `render.yaml`.
5. Enter values for:
   - `SIGNALING_URL`
   - `ALLOWED_ORIGINS`
6. Deploy the Blueprint.

## Wiring order

1. Deploy the signaling service first.
2. Copy its public `https://...onrender.com` URL.
3. Convert that to `wss://...onrender.com` and set it as `SIGNALING_URL` on the static site.
4. Copy the static site public `https://...onrender.com` URL.
5. Set that as `ALLOWED_ORIGINS` on the signaling service.
6. Redeploy both once after wiring.

## Notes

- Render terminates TLS for both services, so the browser connects with `wss://...` even though the Node app itself listens on plain HTTP internally.
- Do not point the static site at `ws://127.0.0.1:8787` in production.
- Do not expect the static site host to serve the signaling websocket on port `8787`.
