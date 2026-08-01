#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERT_DIR="${CERT_DIR:-$ROOT/.local-dev/certs}"
CERT_FILE="${CERT_FILE:-$CERT_DIR/dev-cert.pem}"
KEY_FILE="${KEY_FILE:-$CERT_DIR/dev-key.pem}"
LAN_IP="${LAN_IP:-}"

if [[ -z "$LAN_IP" ]]; then
  LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
fi
if [[ -z "$LAN_IP" ]]; then
  LAN_IP="$(ipconfig getifaddr en1 2>/dev/null || true)"
fi

mkdir -p "$CERT_DIR"

SAN="DNS:localhost,IP:127.0.0.1"
if [[ -n "$LAN_IP" ]]; then
  SAN="$SAN,IP:$LAN_IP"
fi

if command -v mkcert >/dev/null 2>&1; then
  mkcert -cert-file "$CERT_FILE" -key-file "$KEY_FILE" localhost 127.0.0.1 ${LAN_IP:+$LAN_IP}
else
  openssl req \
    -x509 \
    -newkey rsa:2048 \
    -sha256 \
    -nodes \
    -days 14 \
    -subj "/CN=localhost" \
    -addext "subjectAltName=$SAN" \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE"
fi

echo "Generated local TLS cert:"
echo "  cert: $CERT_FILE"
echo "  key:  $KEY_FILE"
if [[ -n "$LAN_IP" ]]; then
  echo "  lan:  https://$LAN_IP:8080/operation-steelstorm.html"
fi
if ! command -v mkcert >/dev/null 2>&1; then
  echo
  echo "Trust this cert once on macOS to remove browser warnings:"
  echo "  bash \"$ROOT/scripts/trust-local-cert.sh\""
fi
