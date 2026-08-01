#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERT_DIR="${CERT_DIR:-$ROOT/.local-dev/certs}"
CERT_FILE="${CERT_FILE:-$CERT_DIR/dev-cert.pem}"
KEYCHAIN="${KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"

if [[ ! -f "$CERT_FILE" ]]; then
  echo "Cert not found at $CERT_FILE"
  echo "Run: bash \"$ROOT/scripts/generate-local-certs.sh\""
  exit 1
fi

echo "Trusting local dev certificate in $KEYCHAIN"
security add-trusted-cert -d -r trustRoot -k "$KEYCHAIN" "$CERT_FILE"
echo "Trusted: $CERT_FILE"
