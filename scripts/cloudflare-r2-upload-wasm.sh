#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WASM_FILE="${WASM_FILE:-$ROOT/game/web/operation-steelstorm.wasm}"
WASM_R2_BUCKET="${WASM_R2_BUCKET:-}"
WASM_R2_OBJECT_KEY="${WASM_R2_OBJECT_KEY:-operation-steelstorm/operation-steelstorm.wasm}"
WASM_PUBLIC_BASE_URL="${WASM_PUBLIC_BASE_URL:-}"

if [[ -z "$WASM_R2_BUCKET" ]]; then
  echo "WASM_R2_BUCKET is required." >&2
  exit 1
fi

if [[ ! -f "$WASM_FILE" ]]; then
  echo "WebAssembly file not found at $WASM_FILE" >&2
  exit 1
fi

echo "Uploading $(basename "$WASM_FILE") to R2 bucket $WASM_R2_BUCKET..."
npx wrangler r2 object put "${WASM_R2_BUCKET}/${WASM_R2_OBJECT_KEY}" --file "$WASM_FILE" --remote

if [[ -n "$WASM_PUBLIC_BASE_URL" ]]; then
  echo "WASM_PUBLIC_URL=${WASM_PUBLIC_BASE_URL%/}/${WASM_R2_OBJECT_KEY}"
fi
