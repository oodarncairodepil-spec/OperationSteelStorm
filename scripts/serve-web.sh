#!/usr/bin/env bash
# Export Web build (requires matching export templates) and serve locally.
# Set HTTPS=1 for LAN/device testing so the Web build gets a secure context.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME="$ROOT/game"
OUT="$GAME/web"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
HTTPS="${HTTPS:-0}"

GODOT_BIN="${GODOT_BIN:-}"
if [[ -z "$GODOT_BIN" ]]; then
  if [[ -x /tmp/godot-extract/Godot.app/Contents/MacOS/Godot ]]; then
    GODOT_BIN=/tmp/godot-extract/Godot.app/Contents/MacOS/Godot
  elif command -v godot >/dev/null 2>&1; then
    GODOT_BIN="$(command -v godot)"
  fi
fi

if [[ -z "${GODOT_BIN:-}" ]]; then
  echo "Set GODOT_BIN to your Godot binary."
  exit 1
fi

mkdir -p "$OUT"
echo "Exporting Web preset…"
"$GODOT_BIN" --path "$GAME" --headless --export-release "Web" "web/operation-steelstorm.html"
cd "$OUT"

if [[ "$HTTPS" == "1" ]]; then
  CERT_DIR="${CERT_DIR:-$ROOT/.local-dev/certs}"
  CERT_FILE="${CERT_FILE:-$CERT_DIR/dev-cert.pem}"
  KEY_FILE="${KEY_FILE:-$CERT_DIR/dev-key.pem}"
  if [[ ! -f "$CERT_FILE" || ! -f "$KEY_FILE" ]]; then
    bash "$ROOT/scripts/generate-local-certs.sh"
  fi
  echo "Serving $OUT at https://127.0.0.1:$PORT"
  echo "For LAN multiplayer, start signaling with TLS and open https://<your-lan-ip>:$PORT/operation-steelstorm.html"
  exec python3 "$ROOT/scripts/serve_web_https.py" \
    --bind "$HOST" \
    --port "$PORT" \
    --directory "$OUT" \
    --cert "$CERT_FILE" \
    --key "$KEY_FILE"
fi

echo "Serving $OUT at http://127.0.0.1:$PORT"
echo "Start signaling separately: cd signaling-server && npm run dev"
exec python3 -m http.server "$PORT" --bind "$HOST"
