# Cloudflare Deploy Guide

## Recommended setup

Use **two Cloudflare projects from the same GitHub repository**:

1. **Cloudflare Pages** for the exported Godot web client
2. **Cloudflare Worker** for signaling, backed by a **Durable Object** with the **WebSocket Hibernation API**

This repository now supports that split directly:

- `scripts/cloudflare-pages-build.sh` builds the Godot web export into `game/web`
- `cloudflare/signaling-worker/` contains the signaling Worker and Durable Object

## Why the old deploy failed

The failing command:

```bash
npx wrangler deploy
```

was being executed from the repository root. That fails for the static client because there is:

- no root Worker entrypoint to deploy
- no prebuilt static asset directory for Wrangler to auto-detect

For Pages, you should **build static files** and let Pages publish `game/web`.
For signaling, you should deploy the **separate Worker** in `cloudflare/signaling-worker/`.

## Cloudflare Pages settings

Create a **Pages** project for this repository and set:

- Framework preset: `None`
- Build command: `npm run cf:pages:build`
- Build output directory: `game/web`
- Root directory: `/`

Set this environment variable on Pages:

```text
SIGNALING_URL=wss://<your-worker-subdomain>/ws
```

Example:

```text
SIGNALING_URL=wss://operation-steelstorm-signaling.<subdomain>.workers.dev/ws
```

If you use the included GitHub Actions workflow instead of Cloudflare-managed builds, this value should be stored in the GitHub repository secret `CLOUDFLARE_SIGNALING_URL` instead of a Pages build variable.

## Worker deploy

Create a separate **Worker** project for the signaling backend from:

- directory: `cloudflare/signaling-worker`

Local deploy command:

```bash
cd /Users/plugoemployee/ok-thank-you/cloudflare/signaling-worker
npm install
npm run deploy
```

Important Worker env vars:

```text
ALLOWED_ORIGINS=https://<your-pages-project>.pages.dev
ALLOW_LAN_ORIGINS=false
MAX_PLAYERS_PER_ROOM=2
ROOM_CODE_LENGTH=6
PLAYER_NAME_MAX_LENGTH=16
ROOM_IDLE_TTL_MS=1800000
RATE_LIMIT_WINDOW_MS=10000
RATE_LIMIT_MAX_MESSAGES=60
SIGNALING_MAX_MESSAGE_BYTES=72000
SIGNALING_SHARD_NAME=global
```

`ALLOWED_ORIGINS` can be stored as a Worker secret/value in the Cloudflare dashboard after the first deploy.

## GitHub Actions deploy

The repository includes [cloudflare-deploy.yml](file:///Users/plugoemployee/ok-thank-you/.github/workflows/cloudflare-deploy.yml) for direct upload to Pages plus Worker deployment.

Required GitHub repository secrets:

```text
CLOUDFLARE_API_TOKEN=<api token with Workers/Pages edit access>
CLOUDFLARE_ACCOUNT_ID=<your account id>
CLOUDFLARE_PAGES_PROJECT_NAME=operation-steelstorm-game
CLOUDFLARE_SIGNALING_URL=wss://<your-worker-subdomain>.workers.dev/ws
```

The workflow:

- deploys the signaling Worker from `cloudflare/signaling-worker`
- builds the Godot web export
- uploads `game/web` to the configured Pages project

## Worker architecture

The signaling backend now uses:

- `WebSocketPair` to terminate signaling WebSockets at the Worker edge
- `Durable Objects` for strongly consistent room coordination
- `WebSocket Hibernation` via `ctx.acceptWebSocket()` so idle room sockets do not pin the object in memory

The current implementation uses a single named coordinator Durable Object shard (`SIGNALING_SHARD_NAME=global`) because the game currently supports small 2-player lobbies. This is enough for the current multiplayer scope and can be sharded later if room volume grows.

## Deploy order

1. Deploy the signaling Worker first
2. Copy its public Worker URL
3. Set Pages env:
   - `SIGNALING_URL=wss://.../ws`
4. Deploy the Pages project
5. Copy the Pages URL
6. Set Worker env:
   - `ALLOWED_ORIGINS=https://...pages.dev`
7. Redeploy the Worker once

## Health check

Worker health endpoint:

```text
https://<your-worker-subdomain>/health
```

Expected response:

```json
{ "ok": true, "rooms": 0, "peers": 0 }
```

## Notes

- Pages hosts the static Godot build only
- the Worker hosts the signaling WebSocket only
- do not use `npx wrangler deploy` from the repo root for the Pages project
- the game client should point to the Worker `wss://.../ws` endpoint, not the Pages host
