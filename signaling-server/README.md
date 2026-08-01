# Signaling Server — Operation Steelstorm

Lightweight WebSocket service for room matchmaking and WebRTC offer/answer/ICE relay.

**Does not** carry gameplay simulation traffic.

## Features (MVP skeleton)

- Create / join rooms with short codes
- Player name + ready state
- Host designation (room creator; reassign on host leave while in lobby)
- WebRTC signal relay
- Disconnect notifications
- Idle room cleanup
- `/health` endpoint
- JSON validation (Zod) + basic rate limiting
- Origin allow-list

## Quick start

```bash
cp .env.example .env
npm install
npm run dev
```

Default: `ws://127.0.0.1:8787`

Local LAN HTTPS/WSS dev:

```bash
cd ..
HTTPS=1 ./scripts/serve-web.sh

# other terminal
cd signaling-server
npm run dev
```

This uses the local TLS cert/key referenced from `.env` so devices on your LAN can open
`https://<your-lan-ip>:8080/operation-steelstorm.html` without the browser rejecting WebRTC for missing secure context.

```bash
npm run typecheck
npm test
npm run build && npm start
```

## Docker

```bash
docker build -t oss-signaling .
docker run --rm -p 8787:8787 --env-file .env oss-signaling
```

Or use repo `deployment/docker-compose.yml`.

## Environment

See `.env.example`. Important:

- `ALLOWED_ORIGINS` — comma-separated browser origins
- `ALLOW_LAN_ORIGINS` — when `true`, accepts `http(s)` localhost + private-LAN origins for local device testing
- `MAX_PLAYERS_PER_ROOM` — `2` for MVP
- `LOG_LEVEL` — `debug` \| `info` \| `warning` \| `error`
- `TLS_CERT_FILE` / `TLS_KEY_FILE` — enable HTTPS + WSS directly in local/dev deployments

## Protocol

See [`../docs/multiplayer-protocol.md`](../docs/multiplayer-protocol.md).
