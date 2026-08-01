# Cloudflare Deploy Guide

## Recommended setup

Use **Vercel for the static game client** and **Cloudflare Worker** for signaling:

1. **Vercel** for the exported Godot web client
2. **Cloudflare Worker** for signaling, backed by a **Durable Object** with the **WebSocket Hibernation API**

This is the default recommended production path because the exported
`operation-steelstorm.wasm` currently exceeds the Cloudflare Pages per-file limit.

## Optional Cloudflare-only setup

If you want both frontend and signaling on Cloudflare:

1. Upload `game/web/operation-steelstorm.wasm` to **R2** and expose it through a public bucket or custom domain
2. Build the remaining Pages assets with:

```bash
WASM_PUBLIC_URL=https://<your-public-r2-host>/operation-steelstorm/operation-steelstorm.wasm \
npm run cf:pages:build
```

3. Deploy the rewritten `game/web` directory to **Cloudflare Pages**

If your Cloudflare account does not yet have a zone/custom domain attached,
you can still complete the setup by serving the R2-backed `.wasm` through the
existing signaling Worker asset route:

```text
WASM_PUBLIC_URL=https://operation-steelstorm-signaling.<your-subdomain>.workers.dev/assets/operation-steelstorm.wasm
```

This repository now supports that split directly:

- `scripts/cloudflare-pages-build.sh` builds the Godot web export into `game/web`
- `scripts/offload-web-wasm.sh` rewrites the loader to fetch `.wasm` from a public URL and removes the oversized local file
- `scripts/cloudflare-r2-upload-wasm.sh` uploads the generated `.wasm` to R2
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

## Why Pages still needs R2 here

Cloudflare Pages has a hard **25 MiB** per-file asset limit, while this export's
`operation-steelstorm.wasm` is currently larger. Uploading the `.wasm` to R2 and
rewriting the exported loader solves that without changing gameplay code.

## Vercel settings

Set the frontend project to build from the repository root with:

- Build command: `bash ./scripts/vercel-build.sh`
- Output directory: `game/web`
- Environment variable: `SIGNALING_URL=wss://<your-worker-subdomain>/ws`

Legacy typo compatibility:

```text
SIGNALLING_URL=wss://<your-worker-subdomain>/ws
```

is also accepted by the build script, but prefer `SIGNALING_URL` going forward.

## Cloudflare Pages settings (optional frontend)

Create a **Pages** project for this repository and set:

- Framework preset: `None`
- Build command: `WASM_PUBLIC_URL=https://<your-public-r2-host>/operation-steelstorm/operation-steelstorm.wasm npm run cf:pages:build`
- Build output directory: `game/web`
- Root directory: `/`

Set this environment variable on Pages if you want the built client to use the Worker:

```text
SIGNALING_URL=wss://<your-worker-subdomain>/ws
```

Example:

```text
SIGNALING_URL=wss://operation-steelstorm-signaling.<subdomain>.workers.dev/ws
```

If you use Cloudflare-managed builds, also set:

```text
WASM_PUBLIC_URL=https://<your-public-r2-host>/operation-steelstorm/operation-steelstorm.wasm
```

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
```

The workflow:

- deploys the signaling Worker from `cloudflare/signaling-worker`
- does not attempt a Cloudflare Pages upload for the oversized frontend build

## Worker architecture

The signaling backend now uses:

- `WebSocketPair` to terminate signaling WebSockets at the Worker edge
- `Durable Objects` for strongly consistent room coordination
- `WebSocket Hibernation` via `ctx.acceptWebSocket()` so idle room sockets do not pin the object in memory

The current implementation uses a single named coordinator Durable Object shard (`SIGNALING_SHARD_NAME=global`) because the game currently supports small 2-player lobbies. This is enough for the current multiplayer scope and can be sharded later if room volume grows.

## Deploy order

1. Deploy the signaling Worker first
2. Copy its public Worker URL
3. If using Vercel, set:
   - `SIGNALING_URL=wss://.../ws`
4. If using Cloudflare-only frontend:
   - upload `operation-steelstorm.wasm` to R2
   - set `WASM_PUBLIC_URL=https://.../operation-steelstorm.wasm`
   - set `SIGNALING_URL=wss://.../ws`
   - deploy the rewritten Pages output
5. Copy the frontend URL
6. Set Worker env:
   - `ALLOWED_ORIGINS=https://your-frontend-host.example`

For Pages specifically, that means:

- `ALLOWED_ORIGINS=https://<your-pages-project>.pages.dev`

For Vercel specifically, that means:

- `ALLOWED_ORIGINS=https://<your-vercel-project>.vercel.app`

Legacy deploy order retained for Pages:

1. Deploy the signaling Worker first
2. Copy its public Worker URL
3. Set Pages env:
   - `SIGNALING_URL=wss://.../ws`
   - `WASM_PUBLIC_URL=https://.../operation-steelstorm.wasm`
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

- Vercel is the recommended static host for the current build size
- Pages requires R2/public offload for the `.wasm`
- the Worker hosts the signaling WebSocket only
- do not use `npx wrangler deploy` from the repo root for the Pages project
- the game client should point to the Worker `wss://.../ws` endpoint, not the Pages host
