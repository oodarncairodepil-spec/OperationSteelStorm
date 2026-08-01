# Hosting Guide — Operation Steelstorm

## Static game client

Export Godot Web into `game/web/`, then host as static files on any of:

- Cloudflare Pages
- GitHub Pages
- Netlify
- nginx / Caddy / any static host

Requirements:

- HTTPS in production
- Correct MIME for `.wasm`
- Do not rely on a single vendor

Point `network_config.json` signaling URL to your `wss://` service.
For Vercel builds, set environment variable `SIGNALING_URL=wss://your-signaling-host.example` so the build injects the correct production signaling endpoint.

## Signaling server

Deploy the Docker image from `signaling-server/` to a VPS, Railway-like, Render-like, Fly.io-like, or mini PC.
Do not rely on the Vercel static deployment to host the signaling websocket service.

Use **WSS** behind a reverse proxy (Caddy/nginx/Traefik) with TLS.

### Suggested env (production)

```text
PORT=8787
HOST=0.0.0.0
ALLOWED_ORIGINS=https://your-game.example
MAX_PLAYERS_PER_ROOM=2
LOG_LEVEL=info
```

### Health

`GET /health` → JSON `{ ok, rooms, peers }`

### Reverse proxy notes

- Upgrade WebSocket connections (`Connection` / `Upgrade`)
- Idle timeouts long enough for lobby wait
- Restrict `ALLOWED_ORIGINS`

## STUN / TURN

- Public STUN is fine for many LAN/home NATs
- Cross-network play often needs TURN
- Inject TURN credentials at deploy time; **never commit production secrets**
- Local override pattern: `network_config.local.json` (gitignored)

## Local development

1. `npm run dev` in `signaling-server/`
2. Run Godot editor client **or** serve Web export on `http://127.0.0.1:8080`
3. Align origins in `ALLOWED_ORIGINS`

Compose helper:

```bash
cd deployment
docker compose up --build signaling
docker compose --profile web up --build
```
