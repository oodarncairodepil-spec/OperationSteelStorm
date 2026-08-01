# Web Export Guide — Operation Steelstorm

## Target

- Godot **4.5 stable** templates preferred (CI)
- Platform: **Web**
- Renderer: **Compatibility**
- Threads: **disabled** (`variant/thread_support=false`)
- Output: `game/web/operation-steelstorm.html` (+ `.wasm`, `.pck`, etc.)

## Preset

Defined in `game/export_presets.cfg` as preset **Web**.

## Editor steps

1. Install matching export templates (Editor → Manage Export Templates).
2. Project → Export → Web → Export Project.
3. Serve the `game/web/` directory over HTTP(S).  
   `file://` is insufficient for many browser APIs.

Local static server example:

```bash
cd game/web
python3 -m http.server 8080
```

## Browser notes

- First user gesture (**Click to Start**) unlocks audio.
- Prefer HTTPS in production; WebRTC may need secure context depending on browser.
- Configure COOP/COEP only if you later enable threads (MVP does not).
- Keep canvas focus on start (preset enabled).

## Signaling URL

Point `game/multiplayer/network_config.json` `signaling.url` at your deployed `wss://` endpoint for production builds. Prefer build-time injection over committing environment-specific secrets.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Blank canvas | Browser console; WASM MIME; gzip settings |
| Export fails | Templates version mismatch |
| WebRTC fails locally | Secure context / STUN / firewall |
| Blurry pixels | Stretch mode viewport + texture filter nearest |
